# Disjoint-Mask Cel Rigs & Local Kuchi-paku Renderer

Detailed prompt structures, mask-compositing math, and local `24fps` video rendering patterns for Stages 2 and 3 of `p2b-anime-podcast`.

---

## 1. Prompt Templates for Reverse-Angle Base Frames & Rig Edits

### Base Studio Portrait (Speaker A — Left Side Facing Right)
> Wide 16:9 cel-shaded seinen slice-of-life anime medium close-up shot (chest-up) of the person from the reference photo recording a late-night podcast in a cozy warm studio. Translate their exact likeness faithfully into crisp 2D anime: [hair texture/parting/color, eye color, facial hair, glasses, clothing]. Positioned on the left side of the frame angled slightly right (three-quarter view facing right toward an off-screen co-host), relaxed closed-mouth neutral-pleasant expression, eyes open looking right. A sleek black broadcast podcast boom microphone on an arm sits in the lower-right foreground strictly below and clear of the chin and mouth. Style: authentic 2D cel-shaded anime, clean dark-brown ink linework, flat colors with crisp hard-edge two-tone cel shadows, chunky geometric hair highlights, contrasted against a painterly warm-lit background (desk lamp glow, night window bokeh). No text, no watermarks, NOT photorealistic, NOT 3D render, NOT soft airbrush.

*(Mirror left/right directions and swap background props — e.g., bookshelf vs. monitor — for Speaker B so the two shots cut or stack like two cameras in the same room.)*

### Targeted Rig State Edits (Conditioned on the Approved Base Image)
- **`mouth_half`:** *"Edit this exact 2D anime frame for traditional kuchi-paku mouth-flap animation: keep 100% of the image (background, lamp, microphone, clothing, hair, head position, eyes, lighting, linework) completely unchanged and pixel-identical. Change ONLY the mouth so it is half-open mid-sentence speaking naturally (medium anime mouth-open shape with subtle upper teeth edge)."*
- **`mouth_open`:** *"...Change ONLY the mouth so it is clearly open speaking an accented vowel ('ah'/'oh' wide anime kuchi-paku mouth shape, visible inner mouth, tongue and upper teeth row, matching cel-shaded linework)."*
- **`blink`:** *"...Change ONLY both eyes so the eyelids are gently closed in a natural anime blink (clean curved dark-brown closed-eyelid ink lines). Do not change the mouth, head, glasses, or background."*
- **`laugh`:** *"...Change ONLY the eyes and mouth into a warm amused anime laugh/grin (happily curved squinted eyes, wide smiling open mouth)."*
- **Event-Driven Gag / Prop Cels (e.g., Apple Eating):** Generate a pair of states (`prop_bite` + deadpan puffed-cheek `prop_chew`) conditioned on the base frame, keeping background and microphone untouched.

---

## 2. Disjoint Eye/Mouth Mask Compositing (Zero Pixel Jitter)

To prevent subtle JPEG/diffusion noise outside the edited feature from shimmering during playback — and to allow **independent combinations of eye blinks with any mouth shape** — isolate tight disjoint masks for eyes vs. mouth and composite them onto `base`:

```python
import os, numpy as np
from PIL import Image, ImageDraw, ImageFilter

def build_pixel_locked_rig(base_path, half_path, open_path, blink_path, out_dir, prefix):
    os.makedirs(out_dir, exist_ok=True)
    base_im = Image.open(base_path).convert("RGB")
    w, h = base_im.size
    base = np.asarray(base_im, dtype=np.float32)

    def load_rgb(p):
        return np.asarray(Image.open(p).convert("RGB").resize((w, h), Image.Resampling.LANCZOS), dtype=np.float32)

    arr_half, arr_open, arr_blink = load_rgb(half_path), load_rgb(open_path), load_rgb(blink_path)

    def detect_tight_box(edit_arr, thresh=28):
        diff = np.mean(np.abs(edit_arr - base), axis=2)
        sdiff = np.asarray(Image.fromarray(np.clip(diff, 0, 255).astype(np.uint8)).filter(ImageFilter.BoxBlur(6)))
        ys, xs = np.where(sdiff > thresh)
        return (
            max(0, int(xs.min()) - 22),
            max(0, int(ys.min()) - 18),
            min(w, int(xs.max()) + 22),
            min(h, int(ys.max()) + 22),
        )

    b_raw = detect_tight_box(arr_blink)
    m_raw = detect_tight_box(arr_open)

    # Enforce strict horizontal split plane so eye blink and open mouth never collide
    split_y = (b_raw[3] + m_raw[1]) // 2
    b_box = (b_raw[0], b_raw[1], b_raw[2], min(b_raw[3], split_y))
    m_box = (m_raw[0], max(m_raw[1], split_y), m_raw[2], m_raw[3])

    def soft_rect_mask(box):
        m = Image.new("L", (w, h), 0)
        ImageDraw.Draw(m).rounded_rectangle(box, radius=18, fill=255)
        return np.asarray(m.filter(ImageFilter.GaussianBlur(8)), dtype=np.float32)[..., None] / 255.0

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
```

For full-hand prop states (e.g., holding an apple or coffee mug) or full-face `laugh` states where eyes and cheeks move together, build an organic feathered mask directly from the smoothed difference (`sdiff > 20` → `MaxFilter(25)` → `GaussianBlur(8)`) so the hand/prop blends cleanly with zero background shimmer.

Always visually inspect the combined `open_blink` and prop frames before batch rendering.

---

## 3. Fast Local `24fps` Renderer & BiDi Karaoke Architecture

### Key Engineering Rules
1. **Pre-crop & overscan panels once at startup:** Crop and Lanczos-scale all rig PNGs to `1.04×` panel dimensions (`over_w × over_h`) once in memory as `uint8` NumPy arrays. Per-frame camera push-in (`u_foc`) and gentle idle drift (`math.sin(t * 0.55) * 4px`) then reduce to `O(1)` NumPy slice offsets, and listener dimming (`0.70 + 0.30 * foc`) uses integer fixed-point math (`(patch.astype(np.uint16) * gain256 >> 8)`).
2. **Wrap ONLY the center HUD strip in `PIL.Image`:** Converting a full `1080×1920` array to `PIL.Image` and back 24 times/sec wastes ~83% of CPU work on pixels `ImageDraw` never touches. Slice only the ~340px center caption/badge strip (`frame_rgb[HUD_Y0:HUD_Y1]`), draw waveform bars, speaker badges, and captions onto that strip, and assign it back.
3. **Quantize `kuchi-paku` on twos (`12fps`):** Step `for f in range(0, n_frames, 2)` and assign the chosen mouth state to both frame `f` and `f + 1`:
   - Normalize 24fps audio RMS by the 95th percentile of voiced frames (`rms > 0.01`).
   - Only open a character's mouth during frames covered by that speaker's diarized word intervals: `open` if `norm_rms > 0.50`, `half` if `norm_rms > 0.13`, with a brief rhythmic closure every 4th two-frame step when `norm_rms < 0.72` so long held words visibly flap.
4. **Bidirectional (RTL + LTR) Word-by-Word Karaoke (`Pillow` + `libraqm`):**
   - Verify `PIL.features.check("raqm") == True` and load a multi-script variable/bold TTF (such as `Rubik[wght].ttf`) that contains **both** RTL glyphs and ASCII Latin/punctuation (avoiding `▯` missing-glyph boxes).
   - Group consecutive pure-Latin words on each line into a single `direction="ltr"` visual chunk while laying chunks out right-to-left (`cur_right -= chunk_width + space_w`). Inside an LTR chunk, step `lx += word_width + space_w` left-to-right so multi-word English terms (`realization point?`, `Copy Paste`) read in natural English order inside an RTL Hebrew/Arabic sentence while still highlighting the exact spoken word!
5. **Parallel Batch Encoding:** Bound encoder threads (`ffmpeg ... -c:v libx264 -preset ultrafast -threads 2 -crf 20 -pix_fmt yuv420p -movflags +faststart -shortest`), catch `BrokenPipeError` when `-shortest` closes stdin on the final rounded frame, and verify every output `.mp4` duration against the expected segment sum with `ffprobe`.
