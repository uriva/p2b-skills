# Event-Driven Animations, Peak-Y Cel Rigs & Local Kuchi-paku Renderer

Detailed prompt structures, event-driven animation patterns, Peak-Y mask-compositing math, and local `24fps` video rendering patterns for Stages 2 and 3 of `p2b-anime-podcast`.

---

## 1. Prompt Templates for Episode Settings & Base Frames

Give each episode its own authentic environment matching where the recording took place (e.g., cozy studio, nighttime park on white plastic lounge chairs under streetlamps, cafe patio, car) while keeping the hosts' likenesses and 2D cel-shaded anime art style consistent across episodes.

### Base Portrait Template (Speaker A — Left Side Facing Right)
> Wide 16:9 cel-shaded seinen slice-of-life anime medium close-up shot (chest-up) of the person from the reference photo recording a casual podcast in [episode environment — e.g., a cozy late-night studio / a quiet neighborhood park at night sitting back in a white plastic lounge chair under warm streetlamp glow]. Translate their exact likeness faithfully into crisp 2D anime: [hair texture/parting/color, eye color, facial hair, glasses, clothing]. Positioned on the left side of the frame angled slightly right (three-quarter view facing right toward an off-screen co-host), relaxed closed-mouth neutral-pleasant expression, eyes open looking right. Keep any foreground objects (microphone, chair armrest, cup) strictly below and clear of the chin and mouth. Style: authentic 2D cel-shaded anime, clean dark-brown ink linework, flat colors with crisp hard-edge two-tone cel shadows, chunky geometric hair highlights, contrasted against a painterly atmospheric background. No text, no watermarks, NOT photorealistic, NOT 3D render, NOT soft airbrush.

*(Mirror left/right directions and adjust background landmarks for Speaker B so the two panels read like two reverse-angle cameras in the exact same location. Show both base frames to the user for approval before generating any expression or event edits.)*

### Standard Dialogue Rig State Edits (Conditioned on Approved Base Frame)
- **`mouth_half`:** *"Edit this exact 2D anime frame for traditional kuchi-paku mouth-flap animation: keep 100% of the image (background, props, clothing, hair, head position, eyes, glasses, lighting, linework) completely unchanged and pixel-identical. Change ONLY the mouth so it is half-open mid-sentence speaking naturally (medium anime mouth-open shape with subtle upper teeth edge, matching dark-brown cel-shaded ink linework)."*
- **`mouth_open`:** *"...Change ONLY the mouth so it is clearly open speaking an accented vowel ('ah'/'oh' wide anime kuchi-paku mouth shape, visible inner mouth, tongue and upper teeth row, matching dark-brown cel-shaded ink linework)."*
- **`blink`:** *"...Change ONLY both eyes so the eyelids are gently closed in a natural relaxed anime blink (clean curved dark-brown closed-eyelid ink lines). Do not change the mouth, glasses frames, head, or background."*
- **`laugh`:** *"...Change ONLY the eyes and mouth into a warm amused anime laugh/grin (happily curved squinted eyes, wide smiling open mouth with upper teeth visible, matching dark-brown ink linework)."*

---

## 2. Event-Driven Scene & Action Animations (What Makes Clips Feel Alive)

Talking-head lip-sync alone gets repetitive fast. Real podcasts are full of unscripted physical moments audible in the recording — **turning those live events into visual anime beats is the single highest-leverage way to make clips memorable, funny, and shareable** at almost zero extra cost.

During transcript review, actively look for these moments and plan targeted cels or layout animations:

| Live Audio / Transcript Event | Visual Anime Animation | How to Build & Trigger Cheaply |
|---|---|---|
| **Someone joins / interrupts / walks in** | A third character slides into frame or appears as a cameo in the background / temporary 3rd panel; hosts glance over. | Generate a `guest_cameo` cel (or a standalone guest portrait panel) and animate a `0.35s` eased slide-in / fade-in during the guest's diarized timestamps, then slide out when they leave. |
| **Someone steps away / leaves** | Host panel dims to an `empty_chair` cel (or low-opacity darkened frame) while the other host keeps talking. | One image edit removing only the host from the base frame (`empty_chair`), triggered during long solo absences. |
| **Someone eating or drinking** (apple crunch, snack, sipping coffee/water) | `prop_bite` (raising snack/cup to mouth) → deadpan puffed-cheek `prop_chew` cycling on twos while chewing sounds play, even while the other host talks seriously. | Condition `prop_bite` + `prop_chew` (or `drink_sip`) on the base frame, composite with an organic feathered diff mask, and trigger directly from the transcript's chewing/eating audio-event timestamps. |
| **Checking a phone / live news reaction** (e.g., looking up a model launch or price mid-episode) | Host holds up a glowing phone (`phone_check`) with subtle screen rim-light on face, or switches to a surprised/wide-eyed reaction cel (`shock`). | 1–2 targeted edits conditioned on the base frame; trigger on the exact seconds where they read from their phone. |
| **Big laughs, sighs, awkward pauses, mic bumps** | Automatic `laugh` cel on every laughter audio event; brief `deadpan` / `eyebrow_raise` hold on punchlines; 3-frame micro camera shake (`±6px`) on mic bumps or loud slams. | `laugh` is part of the core rig; camera shake and timing holds are pure NumPy slice offsets (`$0` extra generation). |

**Rule of thumb:** Even **one** custom event animation in a cold open or highlight clip (e.g., crunching an apple mid-mic-check, a friend walking into frame, or pulling out a phone to check live news) dramatically increases watch time because viewers immediately realize the animation is responding to what is *actually happening* in the room.

---

## 3. Peak-Y Disjoint Eye/Mouth Mask Compositing (Zero Pixel Jitter)

Never swap raw edited images directly — JPEG re-compression and diffusion noise outside the edited region cause visible background shimmer at 12fps.

**Critical pitfall to avoid:** Do **not** derive the eye/mouth split line from raw diff bounding boxes (`(b_raw[3] + m_raw[1]) // 2`). Image-edit models sometimes shift an eyebrow or cheekbone by a few pixels in `mouth_open`, which drags `m_raw[1]` up into the eyes and slices off the bottom half of closed eyelids when `blink` and `mouth_open` combine!

Instead, locate the **peak-diff Y coordinate** of the eyes and mouth first, then place a strict horizontal split plane halfway between those peaks:

```python
import os, numpy as np
from PIL import Image, ImageDraw, ImageFilter

def build_pixel_locked_rig(base_path, half_path, open_path, blink_path, laugh_path, out_dir, prefix, extra_event_cels=None):
    """
    extra_event_cels: optional dict like {"prop_bite": path, "prop_chew": path, "phone_check": path}
    """
    os.makedirs(out_dir, exist_ok=True)
    base_im = Image.open(base_path).convert("RGB")
    w, h = base_im.size
    base = np.asarray(base_im, dtype=np.float32)

    def load_rgb(p):
        return np.asarray(Image.open(p).convert("RGB").resize((w, h), Image.Resampling.LANCZOS), dtype=np.float32)

    arr_half = load_rgb(half_path)
    arr_open = load_rgb(open_path)
    arr_blink = load_rgb(blink_path)
    arr_laugh = load_rgb(laugh_path)

    def detect_tight_box(edit_arr, thresh=22, y_min=0, y_max=None):
        diff = np.mean(np.abs(edit_arr - base), axis=2)
        sdiff = np.asarray(Image.fromarray(np.clip(diff, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(6)))
        if y_max is None:
            y_max = h
        sub = sdiff.copy()
        sub[:y_min, :] = 0
        sub[y_max:, :] = 0
        ys, xs = np.where(sub > thresh)
        if len(xs) == 0:
            raise RuntimeError(f"No diff found for {prefix}")
        return (
            max(0, int(xs.min()) - 22),
            max(y_min, int(ys.min()) - 18),
            min(w, int(xs.max()) + 22),
            min(y_max, int(ys.max()) + 22),
        )

    # Peak-Y separation: immune to stray eyebrow/cheek drift in mouth_open
    b_diff = np.asarray(Image.fromarray(np.clip(np.mean(np.abs(arr_blink - base), axis=2), 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(8)))
    m_diff = np.asarray(Image.fromarray(np.clip(np.mean(np.abs(arr_open - base), axis=2), 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(8)))
    eye_cy = int(np.unravel_index(np.argmax(b_diff), b_diff.shape)[0])
    m_diff_low = m_diff.copy()
    m_diff_low[: eye_cy + 40, :] = 0
    mouth_cy = int(np.unravel_index(np.argmax(m_diff_low), m_diff_low.shape)[0])
    split_y = (eye_cy + mouth_cy) // 2

    b_box = detect_tight_box(arr_blink, thresh=22, y_min=0, y_max=split_y)
    m_box = detect_tight_box(arr_open, thresh=22, y_min=split_y, y_max=h)

    def soft_rect_mask(box):
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).rounded_rectangle(box, radius=18, fill=255)
        return np.asarray(m.filter(ImageFilter.GaussianBlur(8)), dtype=np.float32)[..., None] / 255.0

    def organic_diff_mask(edit_arr, thresh=18):
        diff = np.mean(np.abs(edit_arr - base), axis=2)
        sdiff = Image.fromarray(np.clip(diff, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(6))
        binary = Image.fromarray(((np.asarray(sdiff) > thresh).astype(np.uint8)) * 255)
        return np.asarray(binary.filter(ImageFilter.MaxFilter(25)).filter(ImageFilter.GaussianBlur(8)), dtype=np.float32)[..., None] / 255.0

    mouth_mask = soft_rect_mask(m_box)
    blink_mask = soft_rect_mask(b_box)

    for m_name, m_arr in [("closed", None), ("half", arr_half), ("open", arr_open)]:
        for b_name, b_on in [("open", False), ("blink", True)]:
            canvas = base.copy()
            if m_arr is not None:
                canvas = canvas * (1.0 - mouth_mask) + m_arr * mouth_mask
            if b_on:
                canvas = canvas * (1.0 - blink_mask) + arr_blink * blink_mask
            Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8)).save(
                os.path.join(out_dir, f"{prefix}_{m_name}_{b_name}.png")
            )

    # Full-face laugh & optional hand/prop/cameo event cels use organic feathered masks
    for state_name, arr in [("laugh", arr_laugh), *((k, load_rgb(v)) for k, v in (extra_event_cels or {}).items())]:
        mask = organic_diff_mask(arr, thresh=18)
        comp = base * (1.0 - mask) + arr * mask
        for b_name in ("open", "blink"):
            c = comp if (state_name == "laugh" or b_name == "open") else (comp * (1.0 - blink_mask) + arr_blink * blink_mask)
            Image.fromarray(np.clip(c, 0, 255).astype(np.uint8)).save(
                os.path.join(out_dir, f"{prefix}_{state_name}_{b_name}.png")
            )
```

Always visually inspect `open_blink`, `laugh_open`, and every event cel before launching batch rendering.

---

## 4. Fast Local `24fps` Renderer, BiDi Karaoke & Compact Social Encoding

### Key Engineering Rules
1. **Pre-crop & overscan panels once at startup:** Crop and Lanczos-scale all rig PNGs to `1.04×` panel dimensions (`over_w × over_h`) once in memory as `uint8` NumPy arrays. Per-frame camera push-in (`u_foc`), idle drift (`math.sin(t * 0.55) * 4px`), and optional mic-bump camera shakes reduce to `O(1)` NumPy slice offsets, and listener dimming (`0.70 + 0.30 * foc`) uses integer fixed-point math (`(patch.astype(np.uint16) * gain256 >> 8)`).
2. **Wrap ONLY the center HUD strip in `PIL.Image`:** Converting a full `1080×1920` array to `PIL.Image` and back 24 times/sec wastes ~83% of CPU work on pixels `ImageDraw` never touches. Slice only the ~340px center caption/badge strip (`frame_rgb[HUD_Y0:HUD_Y1]`), draw waveform bars, speaker pills, and captions onto that strip, and assign it back.
3. **Quantize `kuchi-paku` on twos (`12fps`) with event priority:** Step `for f in range(0, n_frames, 2)` and assign each state to frames `f` and `f + 1`:
   - Priority order per speaker: **custom event override** (e.g., `prop_bite` / `prop_chew` / `phone_check` on exact event windows) → **laughter audio event** (`laugh`) → **diarized speech** (`open` if `norm_rms > 0.50`, `half` if `norm_rms > 0.13`, with a rhythmic closure every 4th two-frame step when `norm_rms < 0.72` so long held vowels flap visibly) → `closed`.
   - Normalize 24fps audio RMS by the 95th percentile of voiced frames (`rms > 0.01`).
4. **Bidirectional (RTL + LTR) Word-by-Word Karaoke (`Pillow` + `libraqm`):**
   - Verify `PIL.features.check("raqm") == True` and load a multi-script variable/bold TTF (such as `Rubik` or `Heebo`) containing **both** RTL glyphs and ASCII Latin/punctuation (avoiding `▯` missing-glyph boxes).
   - Group consecutive pure-Latin words on each line into a single `direction="ltr"` visual chunk while laying chunks out right-to-left (`cur_right -= chunk_width + space_w`). Inside an LTR chunk, step `lx += word_width + space_w` left-to-right so multi-word English phrases read naturally inside RTL sentences while highlighting the exact spoken word.
   - Color redacted `[BEEP]` / `[ביפ]` tokens bold red (`(255, 95, 100, 255)`) so viewers immediately recognize censored third-party names even when watching muted.
5. **Compact Social-Ready Parallel Encoding (`-preset fast -crf 21`):**
   - Avoid `-preset ultrafast` for publishing — it inflates 3–5 minute `1080×1920` clips to `120–240 MB`, blowing past typical `90–100 MB` CDN/API upload limits and forcing a second encode pass.
   - Encode directly with:
     ```bash
     ffmpeg -y -v error \
       -f rawvideo -vcodec rawvideo -s 1080x1920 -pix_fmt rgb24 -r 24 -i - \
       -i clip.m4a -map 0:v:0 -map 1:a:0 \
       -c:v libx264 -preset fast -threads 2 -crf 21 -pix_fmt yuv420p \
       -af asetpts=N/SR/TB -c:a aac -b:a 128k \
       -movflags +faststart -shortest out.mp4
     ```
   - This keeps even 5-minute anime clips under `~60 MB` with crisp cel linework. Catch `BrokenPipeError` when `-shortest` closes stdin on the final rounded frame, run `4` workers in parallel (`xargs -P 4`), and verify every output `.mp4` with `ffprobe`.
