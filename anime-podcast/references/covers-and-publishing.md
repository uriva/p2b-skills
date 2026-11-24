# Labeled Social Covers, Reverse-Order Publishing & Mobile Handoff

Detailed patterns for Stage 4 of `p2b-anime-podcast`: generating completely distinct bespoke anime covers inside the profile-grid safe zone, publishing Reels reliably without API timeouts, and serving local mobile handoff galleries.

---

## 1. Bespoke `9:16` Editorial & Character Covers for the `3:4` Profile Grid (`y = 240..1680`)

When publishing multiple clips from an episode or series, auto-extracted video frames look repetitive, and **reusing the episode's talking-head rig PNGs (`top_rig_png` / `bot_rig_png`)** makes every grid tile share identical outfits, framing, and backgrounds.

Instagram profile grids center-crop `9:16` (`1080×1920`) Reels vertically to **`3:4` (`1080×1440`, i.e., `y = 240..1680`)** (and occasionally `4:5` or `1:1`). Design every cover as a **`1080×1920` JPEG** tailored for the **`3:4` crop (`y = 240..1680`)** using **title-only floating typography** directly over bespoke artwork — **no eyebrow, no subtitle, and no opaque dark horizontal bands or divider bars**.

### Step A — Mix ~28% Character Covers & ~72% Editorial Object Covers with Diverse Palettes
Across a multi-clip batch, establish strong visual rhythm rather than repeating portraits on every tile:
- **~72% character-free editorial object covers:** Symbolic 2D anime still-life / atmospheric scenes split between **upper artwork** (sky, lanterns, glowing data clouds, rafters, signage, foliage) and **lower foreground props** (tabletop objects, devices, cups, books, microphones) framing a wide, calm horizontal middle band (`y ≈ 36%–62%`).
- **~28% anime character/face covers:** Conditioned on the hosts' reference portraits (and any cameo guest), varying **camera angles** (three-quarter, side-profile, over-the-shoulder, subtle peek), **single host vs. duo**, and **placement** (upper-left, upper-right, bottom-left, bottom-right, diagonal opposite corners, or upper split duo).
- **Diverse background palettes:** Assign a distinct, saturated or atmospheric color palette to every clip (cobalt/ice-cyan, emerald/gold, sunset terracotta, petrol teal, sage olive, golden ochre, royal plum, crimson/amber) and explicitly forbid repetitive plain dark-navy or black voids across adjacent tiles.
- **`3:4` grid safe-zone rule for faces:** Prompt upper-corner faces to leave the top `18%–20%` as empty sky/mist/ceiling and sit inside **`y = 18%–42%`** so `y = 240` never clips foreheads or eyes. Prompt bottom-corner faces to clear the bottom `15%–17%` (`y <= 1680`) and keep the middle `38%–61%` calm and uncluttered for floating text.

> **Editorial Object Cover Prompt Pattern (`9:16`, zero characters):**
> *Vertical 9:16 2D cel-shaded seinen anime background illustration with ZERO characters and ZERO people, vivid [clip palette — e.g. petrol teal twilight and warm amber glow]. Upper third (top 34%): [upper motif]. Middle band (36%–62%): wide, calm uncluttered atmospheric gradient/mist/sky with no high-contrast foreground objects so large centered white text stays legible. Lower third (bottom 36%): [foreground tabletop/environmental props]. Crisp anime ink linework, rich cel shading, NO humans, NO faces, NO text, NO logos, NO watermarks.*

> **Character/Face Cover Prompt Pattern (`9:16`, varied corner framing):**
> *Vertical 9:16 2D cel-shaded seinen anime editorial cover featuring [Host A / Host B / both hosts] from the attached reference photos (preserving exact likenesses) in a vivid [clip palette] atmosphere. [Corner/angle placement — e.g. Upper-left three-quarter portrait positioned LOWER at y=18%–42% with the top 20% left completely empty sky/background so a 3:4 grid crop never clips the head, OR bottom-right over-the-shoulder framing staying above the bottom 17%]. Keep the middle horizontal band (38%–61%) calm and uncluttered. Crisp ink linework, two-tone cel shadows, NO text, NO logos, NO watermarks.*

### Step B — Content-Aware Reframing & Title-Only `Rubik 900` + Gold `X.Y` Stamp
1. **Face-safe downward shift (`shift_top` ~`215–230px`):** If an upper-corner character generation places the head too close to `y = 240`, smoothly shift the upper portrait slab down by `~215–230px` (extending a feathered top-edge fill and blending into the calm middle band) so the eyes and hair sit cleanly inside the `3:4` crop.
2. **Content-aware object reframing (`shift_top` / `shift_bot`):** For character-free object covers, measure per-row edge energy (`detect_art_bounds`) to find the calmest middle band (`calm_y`), where upper art ends (`top_end`), and where lower art begins (`bot_start`). Shift the upper and lower slabs inward or outward over a blurred calm-band backdrop so top artwork clears the gold `X.Y` label above the title and bottom artwork hugs cleanly beneath the title.
3. **Title-only typography + larger gold `X.Y` numbering (`Rubik 900`):**
   - **Title:** White `#FFFFFF` **Rubik 900** (`14px` `#0F0E15` stroke + Gaussian-blurred drop shadow) starting around **`152px`** (`~146–152px`), vertically centered at `y = 960` and auto-shrinking until every line fits **`<= 980px`** width (and `<= 635px` block height). Use a single multi-script font (`Rubik`) with `Pillow` + `libraqm` (`direction="rtl"`) so RTL Hebrew + mixed LTR English phrases render in natural reading order without `▯` tofu boxes.
   - **Numbering (`X.Y`):** Stamp compact `episode.clip` numbering (`1.1`, `2.3`, `3.9`) directly above the title in gold **`#F5C563`** Rubik 900 at **`~70–76px`** (larger than `50px` so it remains crisp and readable on mobile grid thumbnails) with `~10px` `#0F0E15` stroke and soft drop shadow.
4. **`3:4` Contact-Sheet QA:** Before publishing, assemble a contact sheet of `y = 240..1680` crops across all clips in reverse publishing order (`#N → #00`) and inspect visually to catch any clipped heads, overlapping props, or clashing adjacent palettes.

```python
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

W, H = 1080, 1920

def load_rubik(font_path, size, weight=900):
    f = ImageFont.truetype(font_path, size=size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f

def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)

def detect_art_bounds(img_rgb):
    """Locate calm middle band, upper-art bottom (top_end), and lower-art top (bot_start)."""
    arr = np.asarray(img_rgb, dtype=np.float32)
    gx = np.abs(arr[:, 1:] - arr[:, :-1]).mean(axis=(1, 2))
    gy = np.abs(arr[1:, :] - arr[:-1, :]).mean(axis=(1, 2))
    row_e = np.zeros(H, dtype=np.float32)
    row_e[:-1] += gy
    row_e += gx
    smooth_e = np.convolve(row_e, np.ones(45) / 45.0, mode="same")
    calm_y = 700 + int(np.argmin(smooth_e[700:1220]))
    calm_e = smooth_e[calm_y]
    thresh = max(calm_e * 2.1, calm_e + 1.8)
    top_end = calm_y
    for y in range(calm_y, 260, -1):
        if smooth_e[y] > thresh:
            top_end = y
            break
    bot_start = calm_y
    for y in range(calm_y, 1660):
        if smooth_e[y] > thresh:
            bot_start = y
            break
    return calm_y, top_end, bot_start

def shift_upper_face_safe(img_rgb, shift_top=220, fade_start=640, fade_end=1020):
    """Lower an upper-corner portrait so its head/eyes sit safely below y=240 (3:4 crop)."""
    arr = np.asarray(img_rgb, dtype=np.float32)
    top_strip = arr[0:24].mean(axis=0, keepdims=True)
    bg = np.repeat(top_strip, H, axis=0)
    ys = np.arange(H, dtype=np.float32)[:, None]
    src_y = np.clip(np.round(ys - shift_top).astype(int), 0, H - 1)
    shifted = arr[src_y[:, 0]]
    a_top = smoothstep((ys - (shift_top - 40)) / 90.0)
    a_bot = 1.0 - smoothstep((ys - fade_start) / max(1, fade_end - fade_start))
    alpha = np.clip(a_top * a_bot, 0.0, 1.0)[..., None]
    out = arr * (1.0 - alpha) + shifted * alpha
    if shift_top > 120:
        fill_a = (1.0 - smoothstep((ys - (shift_top - 40)) / 80.0))[..., None]
        out = out * (1.0 - fill_a) + bg * fill_a
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

def reframe_object_for_title(img_rgb, text_y0, text_y1, label_h=72, max_inward=210, max_outward=150):
    """Shift upper and lower object artwork to cleanly frame the centered title + X.Y label."""
    calm_y, top_end, bot_start = detect_art_bounds(img_rgb)
    desired_top_end = text_y0 - (label_h + 44)
    desired_bot_start = text_y1 + 42
    shift_top = max(-max_outward, min(max_inward, desired_top_end - top_end))
    shift_bot = max(-max_inward, min(max_outward, desired_bot_start - bot_start))

    arr = np.asarray(img_rgb, dtype=np.float32)
    band = img_rgb.crop((0, max(0, calm_y - 110), W, min(H, calm_y + 110)))
    bg = np.asarray(band.resize((W, H), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(40)), dtype=np.float32)
    ys = np.arange(H, dtype=np.float32)[:, None]

    top_src = np.clip(np.round(ys - shift_top).astype(int), 0, H - 1)
    top_shifted = arr[top_src[:, 0]]
    top_edge = min(H - 120, max(280, top_end + shift_top))
    a_top = (1.0 - smoothstep((ys - (top_edge - 90)) / 180.0))[..., None]

    bot_src = np.clip(np.round(ys - shift_bot).astype(int), 0, H - 1)
    bot_shifted = arr[bot_src[:, 0]]
    bot_edge = max(120, min(H - 280, bot_start + shift_bot))
    a_bot = smoothstep((ys - (bot_edge - 90)) / 180.0)[..., None]

    out = bg.copy()
    out = out * (1.0 - a_top) + top_shifted * a_top
    out = out * (1.0 - a_bot) + bot_shifted * a_bot
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))

def stamp_title_only_cover(canvas_rgb, font_path, ep_clip_label, title_lines, out_jpg, rtl=True, mid_dark=0.22):
    """Title-only floating Rubik 900 typography + gold X.Y numbering (no eyebrow/subtitle/bars)."""
    direction = "rtl" if rtl else "ltr"
    font_size = 152
    while font_size >= 88:
        ft = load_rubik(font_path, font_size, 900)
        d0 = ImageDraw.Draw(canvas_rgb)
        max_w = max(
            d0.textbbox((0, 0), ln, font=ft, stroke_width=14, direction=direction)[2]
            - d0.textbbox((0, 0), ln, font=ft, stroke_width=14, direction=direction)[0]
            for ln in title_lines
        )
        lh = int(font_size * 1.15)
        if max_w <= 980 and lh * len(title_lines) <= 635:
            break
        font_size -= 6

    ft = load_rubik(font_path, font_size, 900)
    fl = load_rubik(font_path, 72, 900)  # >50px gold X.Y numbering for crisp mobile grid legibility
    lh = int(font_size * 1.15)
    total_h = lh * len(title_lines)
    top_y = (H // 2) - (total_h // 2)

    # Subtle middle darkening (no hard band edges) to guarantee white-text contrast
    ys = np.arange(H, dtype=np.float32)[:, None]
    vig = mid_dark * np.exp(-0.5 * ((ys - (top_y + total_h / 2.0)) / 270.0) ** 2)[..., None]
    base = np.asarray(canvas_rgb, dtype=np.float32) * (1.0 - vig)
    base_rgba = Image.fromarray(np.clip(base, 0, 255).astype(np.uint8)).convert("RGBA")

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shadow)
    lbl_cy = top_y - 68
    ds.text((W // 2, lbl_cy + 8), ep_clip_label, font=fl, fill=(5, 5, 10, 230), anchor="mm", stroke_width=10, stroke_fill=(5, 5, 10, 230))
    for i, ln in enumerate(title_lines):
        cy = top_y + i * lh + lh // 2
        ds.text((W // 2, cy + 9), ln, font=ft, fill=(5, 5, 10, 230), anchor="mm", stroke_width=14, stroke_fill=(5, 5, 10, 230), direction=direction)
    shadow = shadow.filter(ImageFilter.GaussianBlur(10))

    fg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    df = ImageDraw.Draw(fg)
    df.text((W // 2, lbl_cy), ep_clip_label, font=fl, fill=(245, 197, 99, 255), anchor="mm", stroke_width=10, stroke_fill=(15, 14, 21, 255))
    for i, ln in enumerate(title_lines):
        cy = top_y + i * lh + lh // 2
        df.text((W // 2, cy), ln, font=ft, fill=(255, 255, 255, 255), anchor="mm", stroke_width=14, stroke_fill=(15, 14, 21, 255), direction=direction)

    out_dir = os.path.dirname(out_jpg)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    Image.alpha_composite(Image.alpha_composite(base_rgba, shadow), fg).convert("RGB").save(out_jpg, "JPEG", quality=93, optimize=True)
```

---

## 2. Reverse-Order Publishing & Timeout-Safe 3-Step Reels Loop

### Grid Ordering Rule
Social profiles sort posts newest-first (top-left → right → down). Always publish an episode's batch in **reverse order (`#N, #N-1, ..., #01, #00`)** with a short `~3s` pause between publishes so Clip `#00` (the intro/hook) lands cleanly at top-left.

### Staging Clean HTTPS Media URLs
Social publishing APIs (such as Instagram Graph API) require publicly reachable, direct HTTPS URLs for `video_url` and `cover_url` that return proper `Content-Type` headers (`video/mp4`, `image/jpeg`) without interactive interstitials:
- If a direct public tunnel/CDN is unavailable, upload each MP4 and JPEG cover via signed object-storage / media-CDN `PUT` URLs in parallel (`curl -sfS -X PUT -H "Content-Type: ..." --upload-file ...`), verifying every file is under the upload service's size ceiling (e.g., `<= 90 MB` — which `-preset fast -crf 21` satisfies automatically).

### Avoiding CLI / RPC Timeouts with Local Status Polling
Publishing a `10–60 MB` Reel takes `20–90+` seconds for the platform to download and transcode. Calling a single blocking "publish & wait" wrapper frequently hits `45s` CLI/gateway timeouts even while the container succeeds server-side (risking duplicate publishes if retried blindly).

Always separate container creation, polling, and publication:
1. **Create container:** Call the media-creation endpoint (`media_type: "REELS"`, `video_url`, `cover_url`, `caption`, `share_to_feed: true`) → receive `creation_id`.
2. **Poll locally until `FINISHED`:** Loop every `~5s` calling the container status endpoint (allowing 3–4 retries on transient network blips) until `status_code == "FINISHED"` (or fail fast on `ERROR`/`EXPIRED`).
3. **Publish with short wait & persist immediately:** Once `FINISHED`, call the publish endpoint with a short timeout (`max_wait_seconds: 15`), fetch the live `permalink`, and immediately write `{id, creation_id, permalink, title}` to `published.json`.
4. **Idempotent resume & quota verification:** Skip any clip ID already present in `published.json` so an interrupted batch resumes cleanly with zero duplicates. Check daily publishing limits (e.g., Instagram allows 50 API-published Reels per rolling 24h window) before starting a batch, and verify the account's total `media_count` once complete.

---

## 3. Local Mobile Handoff Gallery (For Manual Story Posting / Review)

Instagram desktop web does not support uploading video Stories (only Reels/Feed; Graph API `STORIES` requires a Business/Creator account), and Stories cap single segments at **60 seconds**.

When handing clips directly to a user's phone on a local network or VPN/Tailscale:
- Serve a lightweight dark HTML gallery listing every clip with inline `<video controls playsinline>` previews, `≤60s` Story-ready badges, and `<a download>` links.
- Print a terminal QR code in **uppercase alphanumeric mode with an inverted solid quiet-zone border**:
  ```bash
  qrencode -t UTF8 -l L -m 2 -i "HTTP://100.X.Y.Z:8765/"
  ```
  Using uppercase URLs cuts QR matrix density nearly in half (preventing terminal line-wrap), and `-i` guarantees bright finder-pattern contrast on dark-mode terminals.
