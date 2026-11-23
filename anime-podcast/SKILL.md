---
name: p2b-anime-podcast
description: Turn long multi-speaker audio recordings or podcasts into low-cost, broadcast-ready 2D anime video clips. Covers silence-aligned transcription, cross-chunk and cross-episode voiceprint diarization, editorial curation with surgical third-party bleeping, event-driven scene/prop/cameo animations, pixel-locked Peak-Y disjoint cel rigs, 12fps on-twos kuchi-paku lip sync, bidirectional (RTL/LTR) karaoke captions, bespoke labeled safe-zone covers, and reliable reverse-order Reels publishing.
---

# p2b-anime-podcast

Produce polished 2D anime video clips from raw multi-speaker audio at **~1/300th the cost of AI talking-avatar video models** — while avoiding uncanny face melting, line-boil, and off-model character drift.

---

## Core Architectural Principle: Static Cel Rigs + Live Event Animation

Per-second audio-to-video lip-sync models charge per output second (often $10–$15 per minute of finished video), struggle with non-English mouth shapes, and introduce line-boil and identity drift over multi-minute clips.

Real 2D TV anime animates dialogue economically using **held cels + mouth flaps (*kuchi-paku*, 口パク)** on twos or threes (`8–12` drawings/sec inside a `24fps` container), punctuated by expressive character beats whenever something actually happens in the room. Reproducing that exact production grammar delivers both authentic anime feel and near-zero marginal cost:

1. **Transcribe & diarize once** with word-level timestamps and non-speech audio-event tags (laughter, sighs, eating/drinking sounds, applause, background arrivals).
2. **Gate expensive work behind user approval:** Before generating expression edits or rendering clips, show the user (a) the episode's base scene portraits and (b) the proposed clip list with durations, flagged third-party names to bleep, and planned event animations.
3. **Generate ~5–8 pixel-locked static cels per speaker once** (base portrait + mouth/blink/laugh states + any episode-specific event/prop cels), then **mask-composite only the changed regions** onto the exact base frame so 100% of the background, clothing, hair, and linework has **zero pixel jitter**.
4. **Synthesize unlimited clips locally on CPU for $0** by driving mouth flaps from diarized audio RMS, layering natural blinks, spotlighting the active speaker, triggering event animations on exact audio cues, and rendering word-by-word karaoke captions directly into compact social-ready MP4s.

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
- Disable provider payload archiving (`store_payload: false` or equivalent) when transcribing private raw recordings that have not yet been scrubbed.

### 3. Deterministic Cross-Chunk & Cross-Episode Speaker Alignment
Independent chunks assign arbitrary local speaker IDs (`speaker_0`, `speaker_1`), which flip whenever a different person speaks first in the next chunk or a third person walks into the room:
- Never guess speaker continuity from turn order alone.
- Extract acoustic voiceprints per `(chunk_index, speaker_id)` from each speaker's longest solo turns — specifically **cepstral-mean-normalized 40-band log-Mel vectors** (timbre, invariant to mic distance) plus **median voiced fundamental frequency (`F0`)** (separating pitch registers, e.g., ~140 Hz vs. ~200 Hz when an unexpected guest enters).
- Match cosine similarity against Chunk 0's reference speakers **and** against saved host voiceprints from prior episodes so canonical speaker labeling stays automatic across an entire series, while immediately flagging any newly arriving guest speaker.

### 4. Editorial Curation: Keep Personal Stories, Bleep Third Parties, Cut Dead Air
Read the full diarized transcript before proposing clips, applying a clear three-way editorial rule:
- **Keep interesting personal topics:** Candid, funny, or vulnerable stories about the hosts themselves (personal experiences, mistakes, debates, lifestyle, real-life reactions) often make the highest-retention clips. Do **not** over-censor authentic host stories just because they are personal.
- **Surgically bleep third parties (don't kill good clips):** When a great story mentions third parties who did not consent to being named publicly (friends, partners, coworkers, acquaintances), **keep the clip and bleep their names** using a sample-accurate `1000Hz` censor tone (`ffmpeg` mute + `sine` mix) paired with a bold red `[BEEP]` / `[ביפ]` caption. This preserves pacing and comedic timing far better than harsh jump cuts.
- **Cut genuinely unpublishable or uninteresting material:** Exclude dry logistics (flight schedules, routine catch-up, mic setup unless funny), raw credentials/secrets, sensitive banking/billing details, unreleased NDA codenames, or any segment where a participant explicitly asks not to be recorded.
- **Splice cleanly & patch minor ASR typos:** Splice around brief tangents at word boundaries using `40–50ms` micro-fades, `asetpts=N/SR/TB`, and `-16 LUFS` loudness normalization. Keep a small timestamp-keyed `TEXT_FIXES` override map for occasional ASR mishearings (e.g., an English acronym heard as a native word) instead of re-transcribing.

For complete chunk-splitting, acoustic voiceprint alignment, bleeping, and multi-segment FFmpeg cutting code, load `references/audio-diarization-and-curation.md`.

---

## Stage 2 — Episode Scenes, Event-Driven Animations & Zero-Jitter Cel Rigs

### 1. Episode-Specific Settings with Persistent Character Likeness
- Crop reference photos tightly around each speaker's head/shoulders so background bystanders never confuse character conditioning.
- Give each episode its own authentic visual setting matching where the hosts actually recorded or the episode's vibe (e.g., late-night studio with boom mics, nighttime park on white plastic lounge chairs under streetlamps, coffee shop) while keeping each host's exact likeness, proportions, and cel-shaded 2D anime ink style consistent across episodes.
- Frame **matching reverse-angle medium close-ups** (`16:9` panels work in both stacked `9:16` vertical layouts and cut-to-speaker `16:9` horizontal layouts): Host A on the left angled three-quarters right; Host B on the right angled three-quarters left. Keep foreground props (mics, cups, armrests) strictly clear of the chin and mouth.

### 2. Animate Real Events Happening in the Audio (CRITICAL)
Pure talking-head lip-sync carries dialogue, but **animating real-world events happening during the recording is what elevates an anime podcast from a static audio visualizer into memorable storytelling**. Listeners hear clues in the audio — seeing the characters actually react and act them out creates huge comedic payoff and viewer retention.

Actively scan the transcript and audio-event tags during curation for live moments worth 1–2 custom cels or layout beats:
- **A person joining, interrupting, or leaving the room:** When a third speaker walks in, don't leave their voice disembodied on a two-host screen — either animate a **brief cameo entrance** (a dedicated `guest_enter` cel composited into the background, or a smooth slide-in 3rd panel / guest card for their turns) and dim or empty a host's panel if they step away from the mic.
- **Eating, drinking, crunching, or sipping:** When audio events or banter reveal someone biting an apple, chewing during a mic check, or sipping coffee, generate a pair of prop cels (`prop_bite` + deadpan puffed-cheek `prop_chew` or `mug_sip`) and sync them precisely to the crunch/sip timestamps.
- **Live real-world reactions & physical beats:** Checking a phone when breaking news or a live model launch drops mid-episode (`phone_check` cel), double-takes/deadpan stares during awkward silences, loud coughing/sneezing, mic bumps, or bursting into laughter (`laugh` cel triggered automatically on every laughter audio event).
- **Keep event animation cheap:** Condition every event cel on the approved base portrait, isolate the changed region with an organic feathered diff mask (`MaxFilter` + `GaussianBlur`), and trigger it on exact frame ranges in the local renderer — zero video-diffusion cost, zero background shimmer.

### 3. Targeted Rig Edits & Peak-Y Disjoint Mask Compositing (CRITICAL)
Pass each approved base frame into an image-edit model instructing it to keep 100% of the image pixel-identical while changing **only** one isolated feature: `mouth_half`, `mouth_open`, `blink`, `laugh`, plus any episode event cels.

Never swap raw edited images directly — subtle diffusion drift shifts hair, collars, or backgrounds by 1–2 pixels and causes shimmer at 12fps. And **never** compute the eye/mouth mask split naively from raw diff bounding boxes: if `mouth_open` subtly nudges an eyebrow, a naive split line jumps into the eyes and clips off closed eyelids!
1. Compute blurred per-pixel color differences for `blink` and `mouth_open` against `base`.
2. **Peak-Y separation:** Find the peak-diff Y coordinate of the eyes (`eye_cy`), zero out everything above `eye_cy + 40px` before finding the peak-diff Y of the mouth (`mouth_cy`), set `split_y = (eye_cy + mouth_cy) // 2`, and restrict eye/mouth tight bounding boxes strictly above and below `split_y`.
3. Feather-composite only the masked regions onto `base` and pre-save all `(mouth_state × blink_state)` combinations (plus organic-masked `laugh` and event states) as lossless PNGs. Visually inspect `open_blink` and every event cel before batch rendering.

---

## Stage 3 — Local `Kuchi-paku` Rendering, BiDi Captions & Compact Output

- **Limited-Animation Cadence & Diarization Gating:** Render a `24fps` H.264 (`yuv420p`) MP4 while stepping mouth flaps **on twos (`12fps`, every 2 frames)**. Gate RMS amplitude strictly by each speaker's diarized word timeline (`amp > 0.50` → `open`, `amp > 0.13` → `half`, else `closed`, with a rhythmic syllable dip every 4th step on sustained medium vowels), overlay deterministic natural blinks (`2–3` frames every `3–5s` + occasional double-blinks), and override with event/laugh states on their exact frame windows.
- **Visual Hierarchy (`1080×1920` Vertical Stack):** Stack Host A (top `1080×870`), a dark center divider band (`180px`) holding the captions + subtle audio bars + speaker pills, and Host B (bottom `1080×870`). Spotlight the active speaker at `100%` brightness with a gentle push-in and glowing seam line while dimming the listener to `~70%`. Center-band captions never cover faces and stay clear of Reels/TikTok/Shorts top and bottom UI overlays.
- **Single Multi-Script Font & BiDi Karaoke:** Always use one font containing **both** target-script and ASCII Latin/punctuation glyphs (e.g., `Rubik` or `Heebo` for Hebrew + English; avoid single-script fonts that render Latin/punctuation as `▯` tofu boxes). In `Pillow` + `libraqm`, group consecutive pure-Latin words into `direction="ltr"` visual chunks laid out right-to-left so multi-word English phrases read naturally inside RTL sentences while highlighting each spoken word (and coloring `[BEEP]` tokens bright red).
- **CPU Speed & Compact Reels-Ready Output:** Pre-crop and overscan (`1.04×`) rig PNGs once as `uint8` NumPy arrays, wrap **only the ~340px center HUD strip** in `PIL.ImageDraw` per frame, and encode directly with `-c:v libx264 -preset fast -threads 2 -crf 21 -pix_fmt yuv420p -movflags +faststart`. Using `-preset fast -crf 21` (instead of `ultrafast`) keeps even 5-minute `1080×1920` clips under `~60 MB` so they upload directly to social APIs and CDNs without a second compression pass.

For complete prompt templates, Peak-Y mask-compositing code, event-animation triggers, and the fast `24fps` renderer implementation, load `references/cel-rig-and-renderer.md`.

---

## Stage 4 — Labeled Covers, Grid Ordering & Automated Publishing

- **Bespoke `9:16` Anime Cover Illustration per Clip (Never Reuse Episode Rigs):** Auto-selected video frames and covers composed from the episode's talking-head rig PNGs (`top_rig_png` / `bot_rig_png`) make every profile tile look visually identical even with swapped expressions or text. For **every clip**, generate a completely different, custom `9:16` cel-shaded anime cover illustration (using `generate_image` or an image-generation model conditioned on the hosts' reference portraits plus that specific clip's topic, setting, physical action, or comedic hook) — varying framing, environment, lighting, poses, and props so every tile on the grid is unmistakably distinct. Instruct the generator to include zero text/watermarks and to leave visual breathing room across the vertical center band (`y = 785..1135`) so faces are never obscured.
- **Safe-Zone Title Band Overlay (`1080×1920`):** Profile grids center-crop `9:16` Reels to `3:4` or `4:5` (or `1:1`). Fit each bespoke illustration to `1080×1920` and composite a centered high-contrast title band (`y = 785..1135`, fully inside the `1:1`/`4:5`/`3:4` grid safe zone) with an episode/clip pill (`EP2 #00`) and auto-sized bold RTL/LTR typography, exporting a JPEG `cover_url`. No separate Feed video re-render is needed.
- **Reverse-Order Publishing (`#N → #00`):** Always publish an episode's clips in reverse order so Clip `#00` (the intro/hook) lands at top-left of the profile grid and viewers browse forward sequentially.
- **Reliable Automated Reels Publishing Loop:**
  - Stage videos and covers on clean, direct HTTPS URLs with explicit `Content-Type` headers (use signed CDN/object-storage PUT uploads when direct local reverse proxies are unavailable, respecting per-file upload limits).
  - Never rely on a single long blocking API call to both upload and publish a Reel — video transcoding frequently exceeds `45s` CLI/RPC timeouts. Use an explicit **3-step local polling loop**: (1) create container (`share_to_feed: true`), (2) poll container status locally every `~5s` until `FINISHED` (retrying transient errors), (3) call publish with a short wait, and immediately save `media_id` + `permalink` to `published.json` for idempotent resume.
  - Check daily API publishing quotas (e.g., Instagram's 50 Reels per rolling 24 hours) before launching large batches, and verify final `media_count` afterwards.
- **Local Mobile Handoff:** When delivering clips for manual posting (such as `≤60s` Stories on personal accounts), serve a lightweight dark HTML gallery with inline video previews, `≤60s` badges, download links, and an inverted-border alphanumeric terminal QR code (`qrencode -t UTF8 -l L -m 2 -i "HTTP://..."`).

For cover-generation code, the idempotent 3-step Reels publisher, and the local mobile handoff gallery, load `references/covers-and-publishing.md`.

---

## References Index

- `references/audio-diarization-and-curation.md` — Read when splitting long audio files at silence boundaries, aligning diarized speaker IDs across chunks and episodes via acoustic voiceprints (`log-Mel` + `F0`), applying the keep/bleep/cut editorial policy, or cutting loudness-normalized multi-segment `.m4a` + `.srt` clips with sample-accurate `1000Hz` censor bleeps.
- `references/cel-rig-and-renderer.md` — Read when designing episode scenes and event-driven animations (guest arrivals, eating/drinking, phone reactions), building Peak-Y disjoint pixel-locked eye/mouth rig sprites, or implementing the local `24fps` `kuchi-paku` + bidirectional karaoke renderer.
- `references/covers-and-publishing.md` — Read when generating bespoke `9:16` anime cover illustrations per clip with `1080×1920` safe-zone title bands, staging media over HTTPS, running the timeout-safe 3-step reverse-order Reels publishing loop, or serving a local mobile handoff gallery with a terminal QR code.
