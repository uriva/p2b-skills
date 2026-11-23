# Labeled Social Covers, Reverse-Order Publishing & Mobile Handoff

Detailed patterns for Stage 4 of `p2b-anime-podcast`: generating completely distinct bespoke anime covers inside the profile-grid safe zone, publishing Reels reliably without API timeouts, and serving local mobile handoff galleries.

---

## 1. Bespoke `9:16` Anime Covers Inside the `3:4` / `4:5` Profile Grid Safe Zone

When you publish multiple clips from the same episode (or across episodes), auto-extracted video thumbnails look nearly identical on a profile grid. **Do NOT reuse the episode's talking-head rig PNGs (`top_rig_png` / `bot_rig_png`) for covers either** — even with swapped expressions or different headline text, covers built from the same episode panels still share identical outfits, camera framing, and backgrounds, making the grid look repetitive.

Meanwhile, Instagram/TikTok/Shorts grids center-crop `9:16` (`1080×1920`) Reels vertically to **`3:4` (`1080×1440`)** or **`4:5` (`1080×1350`)** (and occasionally `1:1`).

Instead of rendering separate cropped Feed videos or recycling episode rigs, generate **one completely different, bespoke `1080×1920` JPEG cover (`cover_url`) per clip** in two steps:

### Step A — Generate a Unique `9:16` Anime Illustration for Every Clip
For each clip, call `generate_image` (with `aspectRatio: "9:16"`) or a reference-conditioned image-generation model using **the hosts' reference portraits** (plus any cameo guest reference featured in that clip) together with a fresh scene concept tailored to **that specific clip's topic, setting, physical action, props, or comedic hook**:
- **Make every tile unmistakably different:** Vary the setting, poses, props, lighting, color palette, and camera angle across every clip in the batch (e.g., Clip `#00` has the hosts wide-eyed in a chaotic late-night convenience store; Clip `#01` shows one host dramatic-sweating at a glowing server rack while the other laughs over coffee; Clip `#02` stages a noir detective standoff or courtroom desk slam matching the punchline).
- **Protect the `y = 785..1135` center title band:** Frame the characters and faces in the upper and/or lower thirds (or compose a wider two-shot with clear breathing room across the vertical center) so the centered title band never slices across anyone's eyes.
- **Keep art style consistent & text-free:** Preserve the series' 2D cel-shaded anime ink linework and two-tone cel shadows while explicitly forbidding baked-in text or watermarks (`no text, no captions, no watermarks`).

> **Per-Clip Bespoke Cover Prompt Template (`9:16`):**
> *Vertical 9:16 2D cel-shaded seinen anime key illustration featuring the hosts from the attached reference portraits (preserving exact likenesses: hair, glasses, facial hair, proportions) in an original scene depicting [clip's specific topic, setting, action, or comedic hook — e.g. furiously debating beside a glowing holographic chart / shocked mid-bite with a crunchy apple in a neon-lit convenience store]. Distinct camera angle, poses, props, and [warm/neon/moody/sunset] lighting unique to this clip. Frame faces and key details in the upper and lower thirds (keeping the horizontal middle band uncluttered) so a centered title banner will not cover any faces. Crisp dark-brown ink linework, two-tone cel shadows, expressive anime storytelling, NO text, NO logos, NO watermarks, NOT photorealistic, NOT 3D.*

### Step B — Composite the `3:4` / `4:5` Safe-Zone Title Band
Fit the clip's bespoke `9:16` illustration (`cover_art_path`) to `1080×1920`, then overlay:
- A high-contrast dark title band across **`y = 785..1135`** (dead center, safely inside `1:1`, `4:5`, `3:4`, and `9:16` crops simultaneously) framed by feathered gradients and the two hosts' signature accent borders.
- A compact episode/clip pill (`SHOW NAME · EP2 #00`) and auto-shrinking bold RTL/LTR headline text (`66–74px`, stepping down to `44px` until all lines fit `W - 110px`).

```python
import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

def make_labeled_cover(
    cover_art_path,
    font_path,
    tag_text,
    title_text,
    accent_rgb,
    out_jpg,
    rtl=True,
    border_top_rgb=(245, 184, 65),
    border_bot_rgb=(115, 210, 252),
):
    W, H = 1080, 1920
    art = Image.open(cover_art_path).convert("RGB")
    canvas = ImageOps.fit(art, (W, H), method=Image.Resampling.LANCZOS, centering=(0.5, 0.5))

    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(overlay)

    # Center band strictly inside 1:1 / 4:5 / 3:4 profile grid safe zones
    band_y0, band_y1, grad_h = 785, 1135, 75
    for i in range(grad_h):
        a = int(242 * (i / grad_h) ** 1.4)
        dr.line([(0, band_y0 - grad_h + i), (W, band_y0 - grad_h + i)], fill=(15, 14, 21, a))
        dr.line([(0, band_y1 + grad_h - 1 - i), (W, band_y1 + grad_h - 1 - i)], fill=(15, 14, 21, a))

    dr.rectangle((0, band_y0, W, band_y1), fill=(15, 14, 21, 246))
    dr.rectangle((0, band_y0, W, band_y0 + 6), fill=(*border_top_rgb, 255))
    dr.rectangle((0, band_y1 - 6, W, band_y1), fill=(*border_bot_rgb, 255))

    def load_font(sz, wgt):
        f = ImageFont.truetype(font_path, size=sz)
        try:
            f.set_variation_by_axes([wgt])
        except Exception:
            pass
        return f

    # Episode / clip badge pill
    font_tag = load_font(27, 740)
    tb = font_tag.getbbox(tag_text)
    pill_w, pill_h = (tb[2] - tb[0]) + 48, 46
    pill_x0, pill_y0 = (W - pill_w) // 2, band_y0 + 28
    ar, ag, ab = accent_rgb
    dr.rounded_rectangle(
        (pill_x0, pill_y0, pill_x0 + pill_w, pill_y0 + pill_h),
        radius=23, fill=(ar, ag, ab, 40), outline=(ar, ag, ab, 230), width=2,
    )
    dr.text((W // 2, pill_y0 + pill_h // 2 - 1), tag_text, font=font_tag, fill=(255, 245, 225, 255), anchor="mm")

    # Auto-fit 1–2 line title
    direction = "rtl" if rtl else "ltr"
    lines = title_text.split("\n")
    font_size = 74 if len(lines) == 1 else 66
    font_title = load_font(font_size, 840)
    while font_size > 44:
        max_lw = max(font_title.getbbox(ln, direction=direction)[2] - font_title.getbbox(ln, direction=direction)[0] for ln in lines)
        if max_lw <= W - 110:
            break
        font_size -= 4
        font_title = load_font(font_size, 840)

    title_cy = (pill_y0 + pill_h + 18 + band_y1 - 24) // 2
    step = int(font_size * 1.24)
    start_y = title_cy - (len(lines) - 1) * step // 2
    for idx, ln in enumerate(lines):
        ly = start_y + idx * step
        dr.text((W // 2, ly + 4), ln, font=font_title, fill=(0, 0, 0, 190), anchor="mm", direction=direction)
        dr.text((W // 2, ly), ln, font=font_title, fill=(255, 255, 255, 255), anchor="mm", direction=direction, stroke_width=2, stroke_fill=(15, 14, 21, 220))

    out_dir = os.path.dirname(out_jpg)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    Image.alpha_composite(canvas.convert("RGBA"), overlay).convert("RGB").save(out_jpg, "JPEG", quality=94, optimize=True)
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
