# Audio Chunking, Cross-Chunk Voiceprint Alignment, Bleeping & Clip Curation

Detailed implementation patterns for Stage 1 of `p2b-anime-podcast`: turning multi-hour raw multi-speaker recordings into accurately diarized word-level transcripts, applying editorial keep/bleep/cut rules, and producing loudness-normalized audio cuts with sample-accurate privacy bleeps.

---

## 1. Stripping Non-Audio Streams & Silence-Aligned Splitting

Phone voice recorders (such as Pixel Recorder `.m4a` files) often embed proprietary `mett` metadata streams alongside the AAC audio stream. Strip metadata streams first with `-map 0:a:0 -c copy`, then detect silences so every chunk stays safely below the ASR model's duration cap (e.g., `<= 1160s` for a `1200s` limit) without cutting through speech:

```python
import json, os, re, subprocess

def split_on_silences(clean_audio_path, out_dir, max_chunk_sec=1160.0):
    os.makedirs(out_dir, exist_ok=True)
    total_dur = float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nk=1:nw=1", clean_audio_path
    ]).decode().strip())

    res = subprocess.run(
        ["ffmpeg", "-i", clean_audio_path, "-af", "silencedetect=noise=-35dB:d=0.4", "-f", "null", "-"],
        stderr=subprocess.PIPE, text=True
    )
    starts = [float(x) for x in re.findall(r"silence_start: ([0-9.]+)", res.stderr)]
    ends = [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", res.stderr)]
    silences = [(s, e, e - s, (s + e) / 2.0) for s, e in zip(starts, ends)]

    splits = [0.0]
    cur = 0.0
    while total_dur - cur > max_chunk_sec:
        cands = [x for x in silences if cur + max_chunk_sec * 0.80 <= x[3] <= cur + max_chunk_sec]
        if not cands:
            cands = [x for x in silences if cur + max_chunk_sec * 0.65 <= x[3] <= cur + max_chunk_sec * 1.02]
        best = max(cands, key=lambda x: x[2])  # longest silence in window
        splits.append(round(best[3], 3))
        cur = splits[-1]
    splits.append(total_dur)

    manifest = []
    for i in range(len(splits) - 1):
        s, e = splits[i], splits[i + 1]
        out_path = os.path.join(out_dir, f"chunk_{i:02d}.m4a")
        # Re-encode mono 24kHz AAC for sample-accurate start/duration without packet-priming drift
        subprocess.check_call([
            "ffmpeg", "-y", "-v", "error",
            "-ss", f"{s:.3f}", "-to", f"{e:.3f}", "-i", clean_audio_path,
            "-c:a", "aac", "-b:a", "64k", "-ac", "1", "-ar", "24000", out_path
        ])
        manifest.append({"index": i, "offset": s, "end": e, "path": out_path})
    return manifest
```

---

## 2. Deterministic Cross-Chunk & Cross-Episode Speaker Alignment (`log-Mel` + `F0`)

When chunks are transcribed in parallel, `speaker_0` in Chunk 1 is simply whoever spoke first after that silence split — not necessarily `speaker_0` from Chunk 0. Furthermore, a third person may walk into the room mid-episode.

Align `(chunk_index, local_speaker_id)` to canonical speaker names using two complementary acoustic features computed directly from 16 kHz mono PCM:
1. **40-band log-Mel cepstral-mean-normalized vector:** Captures vocal tract timbre while normalizing away gain/microphone-distance shifts.
2. **Median autocorrelation `F0` (75–300 Hz):** Immediately flags pitch-register differences (e.g., separating two hosts at ~135–150 Hz from a guest entering at ~200 Hz).

```python
import numpy as np

def voiceprint_from_pcm(sig, sr=16000):
    n_fft, hop = 512, 160
    if len(sig) < n_fft * 6:
        return None
    n_frames = (len(sig) - n_fft) // hop
    frames = np.lib.stride_tricks.sliding_window_view(sig, n_fft)[::hop][:n_frames] * np.hanning(n_fft)
    spec = np.abs(np.fft.rfft(frames, axis=1)) ** 2
    energy = spec.sum(axis=1)
    voiced = energy > np.percentile(energy, 40)
    if voiced.sum() < 4:
        return None
    spec = spec[voiced]

    freqs = np.fft.rfftfreq(n_fft, 1.0 / sr)
    edges = np.geomspace(80, 7600, 42)
    fb = np.zeros((40, len(freqs)))
    for b in range(40):
        l, c, r = edges[b], edges[b + 1], edges[b + 2]
        fb[b] = np.maximum(0.0, np.minimum((freqs - l) / (c - l + 1e-9), (r - freqs) / (r - c + 1e-9)))
    lm = np.log(spec @ fb.T + 1e-10)
    lm_cmn = (lm - lm.mean(axis=1, keepdims=True)).mean(axis=0)
    lm_cmn /= (np.linalg.norm(lm_cmn) + 1e-9)

    f0s = []
    for fr in frames[voiced][::3]:
        ac = np.correlate(fr, fr, mode="full")[n_fft - 1 :]
        sub = ac[53:213]  # 75 Hz .. 300 Hz at 16 kHz
        pk = int(np.argmax(sub)) + 53
        if ac[pk] > 0.30 * ac[0]:
            f0s.append(sr / pk)
    return lm_cmn, (float(np.median(f0s)) if f0s else 0.0)
```

**Cross-chunk & cross-episode tips:**
- Aggregate `voiceprint_from_pcm` over up to 40 longest solo turns (`>= 1.5s`) per `(chunk_index, speaker_id)`.
- Save canonical host voiceprints (`{host_name: {"lm": ..., "f0": ...}}`) after Episode 1 and reuse them to label Episode 2+ automatically — even when recording environments change (studio vs. outdoor park), cepstral-mean-normalized `log-Mel` + `F0` remain strongly separable.
- Any speaker cluster whose cosine similarity to known hosts drops sharply (e.g., `< 0.96` vs. `> 0.99` for matched hosts) or exhibits a large `F0` shift is a **distinct additional participant** — flag their timestamps both for editorial review and for potential guest-cameo animation!
- Always sanity-check the final mapping against 2–3 sample turns per chunk (names addressed, first-person project references).

---

## 3. Editorial Policy: Keep vs. Bleep vs. Cut

Review the full diarized transcript end-to-end and propose the clip slate to the user **before** generating rig edits or rendering. Apply a balanced three-tier policy rather than blanket censorship:

| Category | Action | Rationale & Examples |
|---|---|---|
| **Candid host personal stories** | **KEEP** (confirm in clip slate) | Authentic stories, funny mistakes, opinions, debates, and real-life experiences *about the hosts themselves* often perform best. Never automatically discard a great clip just because it is personal or edgy. |
| **Third-party names inside a great clip** | **KEEP + BLEEP** | If a strong story mentions non-consenting third parties (partners, friends, coworkers, acquaintances, private clients), keep the clip and apply a sample-accurate `1000Hz` censor bleep + red `[BEEP]` caption over every mention of their name (and any uniquely identifying personal details). |
| **Dead air, dry logistics & hard privacy** | **CUT** | Skip uninteresting logistics (flight/calendar planning, mundane catch-up), raw credentials/passwords, banking/card/billing specifics, unreleased NDA codenames, or any moment where someone says *"Wait, is this being recorded?"* / *"Cut that out."* |
| **Long silences (`> ~5s`)** | **TRIM / SPLICE** | Natural pauses (`0.5–2s`) support comedic timing, but **never leave more than `~5 seconds` of silence** inside a clip. Split segments around extended dead air (leaving `~0.8–1.2s` of natural breath/pause via micro-fades) or trim excessive leading/trailing silence. |

- **Context-Preserving Segmentation:** Do not over-fragment a discussion into context-less micro-clips. Keep a sub-point attached to its parent segment whenever its argument or punchline relies on the preceding setup. Only split a topic into separate Reels when each piece stands completely on its own; if a long topic must be split into multiple parts, explicitly link them (e.g., Part 1 / Part 2 in the title/cover) so viewers have the full context. Employ judgment rather than rigid rules.

**Pre-render name sweep & max-silence check:** After selecting candidate clip ranges, run an automated keyword/proper-noun scan across all words inside the proposed clips so no stray mention of a third-party name slips through unbleeped. Also scan for ASR mishearings (e.g., an English acronym misheard as a Hebrew/local word) and add them to `TEXT_FIXES`, and split any word-to-word gap exceeding `5.0s` into consecutive sub-segments keeping `~1.0s` of natural pause:

```python
def cap_long_silences(segments, words, max_silence=5.0, keep_pause=1.0):
    """Split any segment containing >max_silence dead air into tighter sub-segments."""
    tight = []
    for seg_s, seg_e in segments:
        seg_words = sorted([w for w in words if w["end"] > seg_s and w["start"] < seg_e], key=lambda w: w["start"])
        if not seg_words:
            if seg_e - seg_s <= max_silence:
                tight.append((seg_s, seg_e))
            continue
        cur_s = max(seg_s, seg_words[0]["start"] - min(0.8, keep_pause))
        for prev_w, next_w in zip(seg_words, seg_words[1:]):
            gap = next_w["start"] - prev_w["end"]
            if gap > max_silence:
                tight.append((round(cur_s, 3), round(prev_w["end"] + keep_pause * 0.5, 3)))
                cur_s = next_w["start"] - keep_pause * 0.5
        cur_e = min(seg_e, seg_words[-1]["end"] + min(0.8, keep_pause))
        tight.append((round(cur_s, 3), round(cur_e, 3)))
    return tight
```

---

## 4. Multi-Segment Loudness-Normalized Audio Cutting + Sample-Accurate Privacy Bleeps

When splicing around brief tangents or bleeping third-party names inside a clip:
- Apply micro-fades (`40–50ms`) on every segment, reset audio PTS after `concat` (`asetpts=N/SR/TB` — preventing non-monotonic DTS errors downstream), and normalize integrated loudness to `-16 LUFS`.
- Map source-audio `BLEEP_INTERVALS` into clip-relative time, mute the exact word span (`volume=enable='between(t,s,e)':volume=0`), and overlay a clean `1000Hz` broadcast censor tone (`volume=0.18`, enabled only inside the bleep windows) via `amix=inputs=2:duration=first:normalize=0`.
- Replace any word overlapping `BLEEP_INTERVALS` with `"[BEEP]"` (or localized `"[ביפ]"`) in both the burned-in karaoke captions (highlighted red) and `.srt` subtitles.

```python
import subprocess

# Exact source-audio intervals (seconds) to bleep with a 1000Hz TV censor tone
BLEEP_INTERVALS = [
    (133.08, 133.54),   # 3rd-party name in clip 00
    (1070.12, 1070.46), # 3rd-party name in clip 05
]

# Optional ASR caption overrides keyed by exact word start timestamp
TEXT_FIXES = {
    3242.999: "AI",
}

def map_bleeps_to_clip(segs):
    rel_bleeps, running_off = [], 0.0
    for s, e in segs:
        for bs, be in BLEEP_INTERVALS:
            if be > s and bs < e:
                rel_bleeps.append((
                    round(running_off + max(bs, s) - s, 3),
                    round(running_off + min(be, e) - s, 3),
                ))
        running_off += (e - s)
    return rel_bleeps, running_off

def cut_spliced_clip_with_bleeps(src_audio, segments, out_m4a):
    """segments: list of (start_sec, end_sec) tuples in source audio."""
    rel_bleeps, total_dur = map_bleeps_to_clip(segments)
    inputs, fparts = [], []

    if len(segments) == 1:
        s, e = segments[0]
        d = e - s
        inputs += ["-ss", f"{s:.3f}", "-to", f"{e:.3f}", "-i", src_audio]
        fparts.append(
            f"[0:a:0]afade=t=in:st=0:d=0.05,afade=t=out:st={d-0.08:.3f}:d=0.08,"
            f"asetpts=N/SR/TB,loudnorm=I=-16:TP=-1.5:LRA=11[norm]"
        )
    else:
        for idx, (s, e) in enumerate(segments):
            inputs += ["-ss", f"{s:.3f}", "-to", f"{e:.3f}", "-i", src_audio]
            d = e - s
            fparts.append(f"[{idx}:a:0]afade=t=in:st=0:d=0.04,afade=t=out:st={d-0.05:.3f}:d=0.05[a{idx}]")
        cat_in = "".join(f"[a{i}]" for i in range(len(segments)))
        fparts.append(f"{cat_in}concat=n={len(segments)}:v=0:a=1,asetpts=N/SR/TB,loudnorm=I=-16:TP=-1.5:LRA=11[norm]")

    if rel_bleeps:
        cond = "+".join(f"between(t,{rs:.3f},{re:.3f})" for rs, re in rel_bleeps)
        fparts.append(f"[norm]volume=enable='{cond}':volume=0[muted]")
        fparts.append(
            f"sine=frequency=1000:sample_rate=48000:duration={total_dur + 0.5:.3f},"
            f"volume=0.18,volume=enable='not({cond})':volume=0[beep]"
        )
        fparts.append("[muted][beep]amix=inputs=2:duration=first:normalize=0[outa]")
    else:
        fparts.append("[norm]anull[outa]")

    subprocess.check_call([
        "ffmpeg", "-y", "-v", "error", *inputs,
        "-filter_complex", ";".join(fparts), "-map", "[outa]",
        "-c:a", "aac", "-b:a", "128k", out_m4a
    ])
```
