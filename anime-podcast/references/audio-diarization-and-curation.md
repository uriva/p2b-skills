# Audio Chunking, Cross-Chunk Voiceprint Alignment & Clip Curation

Detailed implementation patterns for Stage 1 of `p2b-anime-podcast`: turning multi-hour raw multi-speaker recordings into accurately diarized word-level transcripts and loudness-normalized audio cuts.

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

## 2. Deterministic Cross-Chunk Speaker Alignment (`log-Mel` + `F0`)

When chunks are transcribed in parallel, `speaker_0` in Chunk 1 is simply whoever spoke first after that silence split — not necessarily `speaker_0` from Chunk 0. Furthermore, a third person may enter later in the recording.

Align `(chunk_index, local_speaker_id)` to canonical speaker names using two complementary acoustic features computed directly from 16 kHz mono PCM:
1. **40-band log-Mel cepstral-mean-normalized vector:** Captures vocal tract timbre while normalizing away gain/microphone-distance shifts.
2. **Median autocorrelation `F0` (75–300 Hz):** Immediately flags pitch-register differences (e.g., separating two male hosts at ~135–150 Hz from a female speaker entering at ~200 Hz).

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

Aggregate `voiceprint_from_pcm` over up to 40 longest solo turns (`>= 1.5s`) per `(chunk_index, speaker_id)`. Any speaker cluster whose cosine similarity to both Chunk 0 hosts drops significantly (e.g., `< 0.96` vs. `> 0.99` for matched hosts) or exhibits a sharp `F0` jump is a distinct additional participant. Always sanity-check the mapping against 2–3 sample turns per chunk (names addressed, first-person project references).

---

## 3. Sensitive Content Audit Checklist

When cutting publishable clips from casual recordings, review the full transcript end-to-end and exclude:
- **Financial & banking disclosures:** Bank/card names, rejected billing stories, personal stock trades/losses/debts, exact daily burn or customer counts the hosts have not cleared for public release.
- **Third-party privacy & gossip:** Full names of friends/colleagues in personal contexts, relationship/dating gossip, disputes with community admins, or remarks about coworkers.
- **Personal life & health:** Medical/therapy appointments, illnesses, recreational substances, or segments where any participant asks *"Wait, is this being recorded?"*.
- **Credentials & stealth codenames:** Login/password workflows, unofficial scraping credentials, and unreleased model/product codenames.

---

## 4. Multi-Segment Loudness-Normalized Audio Cutting

When splicing out brief sensitive tangents or long dead pauses inside a single clip, apply micro-fades (`40–50ms`) on every segment, reset audio timestamps after `concat` (`asetpts=N/SR/TB` — preventing non-monotonic DTS warnings downstream), and normalize integrated loudness to `-16 LUFS`:

```python
def cut_spliced_clip(src_audio, segments, out_m4a):
    """segments: list of (start_sec, end_sec) tuples in source audio."""
    if len(segments) == 1:
        s, e = segments[0]
        d = e - s
        af = f"afade=t=in:st=0:d=0.05,afade=t=out:st={d-0.08:.3f}:d=0.08,loudnorm=I=-16:TP=-1.5:LRA=11"
        subprocess.check_call([
            "ffmpeg", "-y", "-v", "error", "-ss", f"{s:.3f}", "-to", f"{e:.3f}",
            "-i", src_audio, "-map", "0:a:0", "-af", af, "-c:a", "aac", "-b:a", "128k", out_m4a
        ])
    else:
        inputs, fparts = [], []
        for idx, (s, e) in enumerate(segments):
            inputs += ["-ss", f"{s:.3f}", "-to", f"{e:.3f}", "-i", src_audio]
            d = e - s
            fparts.append(f"[{idx}:a:0]afade=t=in:st=0:d=0.04,afade=t=out:st={d-0.05:.3f}:d=0.05[a{idx}]")
        cat_in = "".join(f"[a{i}]" for i in range(len(segments)))
        fc = ";".join(fparts) + f";{cat_in}concat=n={len(segments)}:v=0:a=1,asetpts=N/SR/TB,loudnorm=I=-16:TP=-1.5:LRA=11[outa]"
        subprocess.check_call([
            "ffmpeg", "-y", "-v", "error", *inputs,
            "-filter_complex", fc, "-map", "[outa]", "-c:a", "aac", "-b:a", "128k", out_m4a
        ])
```
