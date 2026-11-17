---
name: p2b-anime-podcast
description: Turn long multi-speaker audio recordings or podcasts into low-cost, broadcast-ready 2D anime video clips. Covers silence-aligned transcription and cross-chunk voiceprint diarization, sensitive-content filtering, pixel-locked cel-shaded character rigs (disjoint eye/mouth masking with zero background jitter), 12fps on-twos kuchi-paku lip sync, audio-event visual gags, and bidirectional (RTL/LTR) word-highlighted karaoke captions.
---

# p2b-anime-podcast

Produce polished 2D anime video clips from raw multi-speaker audio at **~1/300th the cost of AI talking-avatar video models** — while avoiding uncanny face melting, line-boil, and off-model character drift.

---

## Core Architectural Principle: Static Cel Rigs Beat Video Diffusion for Dialogue

Per-second audio-to-video lip-sync models charge per output second (often $10–$15 per minute of finished video), struggle with non-English mouth shapes, and introduce line-boil and identity drift over multi-minute clips.

Real 2D TV anime animates dialogue economically using **held cels + mouth flaps (*kuchi-paku*, 口パク)** on twos or threes (`8–12` drawings/sec inside a `24fps` container). Reproducing that exact production grammar gives both dramatically better aesthetics and near-zero marginal cost:

1. **Transcribe & diarize once** with word-level timestamps and non-speech audio-event tags (laughter, sighs, eating/drinking sounds, applause).
2. **Generate ~4–6 static cel-shaded frames per speaker once** from reference photos (a base medium close-up plus targeted mouth, blink, laugh, and prop/gag edits), then **mask-composite only the changed facial regions** onto the base frame so 100% of the background, clothing, hair, and linework has **zero pixel jitter**.
3. **Synthesize unlimited video clips locally on CPU for $0** by driving mouth flaps from the real audio RMS envelope gated by speaker diarization, layering natural eye blinks, active-speaker lighting/camera focus, event-triggered visual gags, and word-by-word karaoke captions.

---

## Stage 1 — Long-Form Transcription, Voiceprint Alignment & Curation

### 1. Silence-Aligned Chunking for Long Recordings
Speech-to-text APIs frequently enforce per-request duration limits (e.g., 20 minutes). Never slice long recordings at arbitrary fixed timestamps, which cuts words and speaker turns in half:
- Strip non-audio metadata tracks first (e.g., proprietary phone recorder metadata streams) so upstream decoders do not choke.
- Run silence detection (`ffmpeg -af silencedetect`) and split exclusively at the **midpoint of the longest silence** within each target window.
- Re-encode chunks with sample-accurate `-ss` / `-to` bounds and verify exact durations (`ffprobe`) so cumulative word-timestamp offsets remain accurate to `<10ms` over multi-hour recordings.

### 2. Multilingual Diarization & Audio-Event Tagging
- Choose a speech-to-text model that natively outputs **word-level timestamps**, **speaker diarization**, and **non-speech audio events** (laughter, applause, chewing/drinking, sighs).
- When speakers code-switch (e.g., Hebrew or Arabic mixed with English technical terms), prefer automatic/multilingual language detection over forcing a single-language constraint that garbles embedded English terms.
- Disable provider payload archiving (`store_payload: false` or equivalent) when transcribing private raw recordings that have not yet been scrubbed for personal content.

### 3. Deterministic Cross-Chunk Speaker Alignment
Independent chunks assign arbitrary local speaker IDs (`speaker_0`, `speaker_1`), which flip whenever a different person speaks first in the next chunk or a third person walks into the room:
- Never guess speaker continuity from turn order alone.
- Extract acoustic voiceprints per `(chunk_index, speaker_id)` from each speaker's longest solo turns — specifically **cepstral-mean-normalized log-Mel filterbank vectors** (timbre, invariant to mic distance) plus **median voiced fundamental frequency (`F0`)** (separating pitch registers, e.g. ~140 Hz vs. ~200 Hz when an unexpected guest enters).
- Match cosine similarity against Chunk 0's reference speakers and confirm identity against conversational self-references.

### 4. Editorial Curation & Privacy Filtering
Read the full diarized transcript before cutting clips:
- **Exclude sensitive material strictly:** personal finances, bank/billing details, portfolio gains/losses, private relationship gossip, third-party full names without consent, medical/therapy mentions, substance references, off-the-record remarks, and internal/NDA codenames.
- **Splice cleanly around brief tangents:** If a strong 60-second insight contains a 5-second private aside or codename, splice the surrounding word boundaries cleanly with short audio micro-fades (`40–50ms`) and loudness normalization (`-16 LUFS` podcast standard, resetting audio PTS via `asetpts=N/SR/TB`).
- **Mine non-speech audio events for comedy:** Check tagged audio events (such as someone crunching an apple during a mic check or laughing mid-sentence) — turning unscripted audio quirks into visual anime gags creates memorable cold opens and recurring bumpers.

For complete chunk-splitting, acoustic voiceprint alignment, and multi-segment FFmpeg cutting code, load `references/audio-diarization-and-curation.md`.

---

## Stage 2 — Zero-Jitter Cel Rig Construction

### 1. Reverse-Angle Base Frames from Reference Photos
- Crop reference photos tightly around each speaker's head/shoulders so background bystanders never confuse character conditioning.
- Generate **matching reverse-angle medium close-ups** (`16:9` panels work seamlessly in both stacked `9:16` vertical layouts and cut-to-speaker `16:9` horizontal layouts):
  - Speaker A on the left angled three-quarters right; Speaker B on the right angled three-quarters left, facing each other across the virtual studio.
  - Specify **cel-shaded 2D anime conventions** explicitly: clean dark-brown ink linework, flat fills with crisp hard-edge two-tone cel shadows, geometric hair highlights, contrasted against a painterly warm studio background.
  - Keep broadcast boom microphones in the lower foreground **strictly clear of the chin and mouth** so mouth swaps never intersect the mic.

### 2. Targeted Expression & Gag Edits
Pass each approved base frame into an image-edit model instructing it to keep 100% of the image pixel-identical while changing **only** one isolated feature:
- `mouth_half` — medium open mouth (`中口`, *nakakuchi*) for normal syllables.
- `mouth_open` — wide open mouth (`大口`, *ōkuchi*) with visible upper teeth/tongue for accented vowels.
- `blink` — relaxed closed eyelids.
- `laugh` — happily squinted eyes + wide grin (triggered on laughter audio events).
- Optional **event-driven prop/gag states** — e.g., `apple_bite` + deadpan puffed-cheek `apple_chew` when eating sounds are tagged in the transcript.

### 3. Disjoint Mask Compositing (CRITICAL)
Never swap raw edited images directly — JPEG re-compression and subtle diffusion drift shift hair, collars, or backgrounds by 1–2 pixels, causing visible background shimmer at 12fps:
1. Compute the blurred per-pixel color difference between each edited image and `base`.
2. Derive tight bounding boxes for **upper-face (`blink`)** and **lower-face (`mouth`)** separated by a strict horizontal split plane at the nose tip so the two masks **never overlap**.
3. Feather-composite *only* the masked eye/mouth pixels onto the exact `base` array and pre-save all `(mouth_state × blink_state)` combinations as lossless PNGs. Every non-facial pixel remains **bit-for-bit identical** across the entire video.

---

## Stage 3 — Local `Kuchi-paku` Rendering & BiDi Captions

### 1. Limited-Animation Cadence & Diarization Gating
- Render into a standard **`24fps` H.264 (`yuv420p`)** container for universal social-platform playback, while stepping mouth changes **on twos (`12fps`, every 2 frames)** so dialogue reads as authentic 2D anime rather than floaty puppetry.
- Gate RMS audio amplitude strictly by the diarized word timeline: only the speaker who owns the active word opens their mouth (`amp > 0.50` → `open`, `amp > 0.13` → `half`, else `closed`), preventing coughs or crosstalk from moving the listener's mouth. Insert a brief syllable dip every ~4mouth-steps on sustained medium-amplitude vowels so long words still articulate.
- Schedule deterministic natural eye blinks (`2–3` frames = `85–125ms` every `3–5s`, with occasional double-blinks) independently for both hosts.

### 2. Visual Hierarchy & Bidirectional (RTL + LTR) Karaoke Typography
- **Stacked `9:16` Vertical Layout (`1080×1920`):** Place Host A in the top panel (`1080×870`), Host B in the bottom panel (`1080×870`), and a dark studio divider band (`180px`) across the center seam. Spotlight the active speaker at `100%` brightness with a subtle push-in and glowing seam border while dimming the listener to `~70%`. Placing captions in the center band avoids covering either face and stays clear of TikTok/Reels/Shorts top and bottom UI chrome.
- **Single Multi-Script Font (Avoid Tofu Boxes `▯`):** Many language-specific system fonts (such as Ubuntu's `NotoSansHebrew-Bold.ttf`) lack ASCII Latin glyphs and punctuation, rendering English terms and periods as `▯` boxes. Always verify and use a single font file containing **both** target-script and Latin/punctuation glyphs (e.g., Google `Rubik` or `Heebo` for Hebrew + English).
- **BiDi Word-Level Highlighting:** When rendering RTL captions (Hebrew/Arabic) containing embedded English phrases via `Pillow` + `libraqm`, group consecutive pure-Latin words into single `direction="ltr"` visual chunks while stepping `direction="rtl"` across chunks. This preserves 100% accurate bidirectional word order while highlighting each spoken word in real time.
- **CPU Performance:** Never convert the entire `1080×1920` frame into `PIL.Image` every frame. Composite upper and lower video panels via fast NumPy array slices, wrap **only the ~340px center HUD/caption strip** in `PIL.ImageDraw`, and bound encoder threads (`ffmpeg -threads 2`) when running parallel clip workers.

### 3. Mobile Handoff & Social Platform Limits
- **Instagram Stories vs. Reels:** Instagram desktop web does not support uploading video Stories (only Reels/Feed; Graph API `STORIES` requires a Business/Creator account), and Stories cap single segments at **60 seconds**.
- For instant lossless phone transfer on a local network or VPN/Tailscale, serve a lightweight dark HTML gallery with inline `<video>` previews, `≤60s` Story-ready badges, `<a download>` buttons, and a terminal QR code generated in **uppercase alphanumeric mode with an inverted solid quiet-zone border** (`qrencode -t UTF8 -l L -m 2 -i "HTTP://..."`) so dark-mode terminals neither clip finder rings nor wrap wide lines.

For complete rig mask-compositing code, prompt templates, and the fast `24fps` renderer implementation, load `references/cel-rig-and-renderer.md`.

---

## References Index

- `references/audio-diarization-and-curation.md` — Read when splitting long audio files at silence boundaries, aligning diarized speaker IDs across chunks via acoustic voiceprints (`log-Mel` + `F0`), filtering sensitive personal content, or cutting loudness-normalized multi-segment `.m4a` + `.srt` clips.
- `references/cel-rig-and-renderer.md` — Read when crafting reverse-angle anime character and prop/gag edit prompts, building disjoint pixel-locked eye/mouth rig sprites, or implementing the local `24fps` `kuchi-paku` + bidirectional karaoke video renderer.
