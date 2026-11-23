# Labeled Social Covers, Reverse-Order Publishing & Mobile Handoff

Detailed patterns for Stage 4 of `p2b-anime-podcast`: generating grid-safe labeled covers, publishing Reels reliably without API timeouts, and serving local mobile handoff galleries.

---

## 1. Labeled `1080×1920` Covers Inside the `3:4` / `4:5` Profile Grid Safe Zone

When you publish multiple clips from the same episode, auto-extracted video thumbnails look nearly identical on a profile grid. Meanwhile, Instagram/TikTok/Shorts grids center-crop `9:16` (`1080×1920`) Reels vertically to **`3:4` (`1080×1440`)** or **`4:5` (`1080×1350`)** (and occasionally `1:1`).

Instead of rendering separate cropped Feed videos, generate one **`1080×1920` JPEG cover (`cover_url`)** per clip directly from your expressive rig PNGs:
- Pick host facial states matching each clip's emotional hook (`laugh` + `laugh`, `open` + `closed`, `prop_chew` + `laugh`, etc.) so every tile looks distinct.
- Place a high-contrast dark title band across **`y = 785..1135`** (dead center, safely inside `1:1`, `4:5`, `3:4`, and `9:16` crops simultaneously) framed by the two hosts' signature accent borders.
- Include a compact episode/clip pill (`SHOW NAME · EP2 #00`) and auto-shrinking bold RTL/LTR headline text (`66–74px`, stepping down to `44px` until all lines fit `W - 110px`).

```python
import os
from PIL import Image, ImageDraw, ImageFont

def make_labeled_cover(top_rig_png, bot_rig_png, font_path, tag_text, title_text, accent_rgb, out_jpg, rtl=True):
    W, H, PANEL_H = 1080, 1920, 870
    canvas = Image.new("RGB", (W, H), (15, 14, 21))

    def crop_panel(path, align_left):
        im = Image.open(path).convert("RGB")
        iw, ih = im.size
        cw = int(round(ih * (W / PANEL_H)))
        x0 = 40 if align_left else max(0, iw - cw - 40)
        return im.crop((x0, 0, x0 + cw, ih)).resize((W, PANEL_H), Image.Resampling.LANCZOS)

    canvas.paste(crop_panel(top_rig_png, True), (0, 0))
    canvas.paste(crop_panel(bot_rig_png, False), (0, H - PANEL_H))

    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(overlay)

    # Center band strictly inside 1:1 / 4:5 / 3:4 profile grid safe zones
    band_y0, band_y1, grad_h = 785, 1135, 75
    for i in range(grad_h):
        a = int(242 * (i / grad_h) ** 1.4)
        dr.line([(0, band_y0 - grad_h + i), (W, band_y0 - grad_h + i)], fill=(15, 14, 21, a))
        dr.line([(0, band_y1 + grad_h - 1 - i), (W, band_y1 + grad_h - 1 - i)], fill=(15, 14, 21, a))

    dr.rectangle((0, band_y0, W, band_y1), fill=(15, 14, 21, 246))
    dr.rectangle((0, band_y0, W, band_y0 + 6), fill=(245, 184, 65, 255))
    dr.rectangle((0, band_y1 - 6, W, band_y1), fill=(115, 210, 252, 255))

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

    os.makedirs(os.path.dirname(out_jpg), exist_ok=True)
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
