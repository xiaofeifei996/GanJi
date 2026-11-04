#!/usr/bin/env python3
"""票根对切风小组件预览。"""
from PIL import Image, ImageDraw, ImageFont

PAPER = (248, 240, 224)
PAPER_DEEP = (235, 224, 201)
PUNCH = (237, 237, 242)
STAMP = (199, 74, 51)
TITLE = (38, 33, 28)
SECONDARY = (115, 105, 89)
TERTIARY = (158, 148, 130)

BOLD = "/usr/share/fonts/noto/NotoSansCJK-Bold.ttc"
REG = "/usr/share/fonts/noto/NotoSansCJK-Regular.ttc"
S = 2


def f(size, bold=False, serif=False):
    return ImageFont.truetype(BOLD if (bold or serif) else REG, int(size * S), index=0)


def paper(w, h, radius=20):
    W, H = w * S, h * S
    img = Image.new("RGB", (W, H), PAPER)
    # 斜向轻渐变
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H * 0.5
        c = tuple(int(PAPER[i] + (PAPER_DEEP[i] - PAPER[i]) * t) for i in range(3))
        d.rectangle([0, y, W, y], fill=c)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius * S, fill=255)
    out = Image.new("RGB", (W, H), (58, 52, 88))
    out.paste(img, (0, 0), m)
    return out


def txt(d, x, y, s, size, color=TITLE, bold=False, serif=False, anchor="la"):
    d.text((x * S, y * S), s, font=f(size, bold, serif), fill=color, anchor=anchor)


def postmark(d, cx, cy, r, text):
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S],
              outline=STAMP, width=int(1.4 * S))
    r2 = r - 2.5
    d.ellipse([(cx - r2) * S, (cy - r2) * S, (cx + r2) * S, (cy + r2) * S],
              outline=(*STAMP,), width=int(0.8 * S))
    txt(d, cx, cy, text, r * 0.62, STAMP, bold=True, anchor="mm")


def punch_v(d, x, y0, y1, n=6):
    step = (y1 - y0) / (n - 1) if n > 1 else 1
    for i in range(n):
        cy = y0 + step * i
        d.ellipse([(x - 1.75) * S, (cy - 1.75) * S, (x + 1.75) * S, (cy + 1.75) * S], fill=PUNCH)


def torn_h(d, x0, x1, y, n=18):
    step = (x1 - x0) / (n - 1) if n > 1 else 1
    for i in range(n):
        cx = x0 + step * i
        d.ellipse([(cx - 1.75) * S, (y - 1.75) * S, (cx + 1.75) * S, (y + 1.75) * S], fill=PUNCH)


def small():
    w, h = 158, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 12
    txt(d, p, p, "赶集历", 9, TERTIARY, bold=True)
    postmark(d, w - p - 12, p + 12, 12, "圩")

    # 左存根
    txt(d, 38, 44, "11月", 8, STAMP, bold=True, anchor="ma")
    txt(d, 38, 56, "3", 30, TITLE, serif=True, anchor="ma")
    txt(d, 38, 88, "周二", 8, SECONDARY, bold=True, anchor="ma")

    # 打孔线
    punch_v(d, 66, 44, 106)

    # 右主票
    txt(d, 76, 56, "大妙村", 17, TITLE, serif=True)
    txt(d, 76, 80, "今日开圩 · 2场", 8.5, SECONDARY, bold=True)

    torn_h(d, p, w - p, h - 8)
    return img


def medium():
    w, h = 338, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 12

    # 主票
    txt(d, p, p, "今日", 9, TERTIARY, bold=True)
    postmark(d, 140, p + 13, 13, "圩")
    txt(d, p, 44, "3", 34, TITLE, serif=True)
    txt(d, p + 24, 62, "周二", 10, SECONDARY, bold=True)
    txt(d, p, 84, "大妙村", 12, STAMP, serif=True, bold=True)
    torn_h(d, p, 150, h - 8)

    # 撕孔
    punch_v(d, 166, 30, 128)

    # 右侧存根联
    rx = 180
    txt(d, rx, p, "存根", 9, TERTIARY, bold=True)
    stubs = [("明", "罗秀镇", True), ("后", "麻垌镇", True), ("周四", "大妙村", True)]
    y = 32
    for lbl, name, open_ in stubs:
        d.ellipse([rx * S, y * S, (rx + 18) * S, (y + 18) * S], fill=PAPER_DEEP)
        txt(d, rx + 9, y + 9, lbl, 9, STAMP if open_ else TERTIARY, bold=True, anchor="mm")
        txt(d, rx + 26, y + 2, name, 11.5, TITLE, serif=True)
        y += 28
    txt(d, rx, y, "周五 · 休", 11, TERTIARY)
    return img


def large():
    w, h = 338, 354
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 12
    txt(d, p, p, "赶集历 · 七日券", 9, TERTIARY, bold=True)
    txt(d, w - p, p, "No.3", 9, STAMP, serif=True, anchor="ra")

    # 主票
    d.rounded_rectangle([p * S, 24 * S, (w - p) * S, 76 * S], radius=12 * S, fill=PAPER_DEEP)
    txt(d, p + 10, 34, "11月", 8, STAMP, bold=True, anchor="ma")
    txt(d, p + 10, 44, "3", 26, TITLE, serif=True, anchor="ma")
    txt(d, p + 10, 66, "周二", 8, SECONDARY, bold=True, anchor="ma")
    punch_v(d, p + 56, 32, 70)
    txt(d, p + 68, 34, "大妙村", 16, TITLE, serif=True)
    txt(d, p + 68, 56, "今日开圩 · 2场", 8.5, SECONDARY, bold=True)

    # 撕孔横线
    torn_h(d, p + 6, w - p - 6, 88)

    # 七张日票 4+3
    tickets = [
        ("3", "二", "大妙村", True, True),   # 今天
        ("4", "三", "休", False, False),
        ("5", "四", "麻垌镇", True, False),
        ("6", "五", "罗秀镇", True, False),
        ("7", "六", "大妙村", True, False),
        ("8", "日", "休", False, False),
        ("9", "一", "麻垌镇", True, False),
    ]
    cw = (w - p * 2 - 21) / 4
    y0 = 100
    for i, (day, wk, name, open_, today) in enumerate(tickets):
        row = i // 4
        col = i % 4
        x = p + col * (cw + 7)
        y = y0 + row * (88 + 8)
        ch = 88
        d.rounded_rectangle([x * S, y * S, (x + cw) * S, (y + ch) * S], radius=8 * S,
                            fill=PAPER_DEEP,
                            outline=STAMP if today else None, width=int(1.2 * S) if today else 0)
        txt(d, x + 7, y + 6, day, 14, TITLE if open_ else TERTIARY, serif=True)
        txt(d, x + 7 + (15 if len(day) < 2 else 24), y + 13, wk, 7.5, SECONDARY, bold=True)
        if open_:
            txt(d, x + 7, y + 28, name, 9.5, STAMP if today else TITLE, serif=True)
        else:
            txt(d, x + 7, y + 28, "休", 9, TERTIARY)
        # 底部三个小孔
        for k in range(3):
            cx = x + 8 + k * 5
            d.ellipse([(cx - 1.25) * S, (y + ch - 9) * S, (cx + 1.25) * S, (y + ch - 9 + 2.5) * S],
                      fill=STAMP if open_ else TERTIARY)
    return img


def empty(w, h):
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 12
    txt(d, p, p, "赶集历", 9, TERTIARY, bold=True)
    postmark(d, w - p - 12, p + 12, 12, "空")
    txt(d, p, h / 2 - 20, "空白票", 9, TERTIARY, bold=True)
    txt(d, p, h / 2 - 4, "去收藏圩点", 16, SECONDARY, serif=True)
    torn_h(d, p, w - p, h - 8)
    return img


if __name__ == "__main__":
    s, m, l = small(), medium(), large()
    e1 = empty(158, 158)
    pad = 22
    W = pad + 158 + pad + 338 + pad
    H = pad + 158 + pad + 158 + pad + 354 + pad
    canvas = Image.new("RGB", (W * S, H * S), (58, 52, 88))
    canvas.paste(s, (pad * S, pad * S))
    canvas.paste(m, ((pad + 158 + pad) * S, pad * S))
    canvas.paste(e1, (pad * S, (pad + 158 + pad) * S))
    canvas.paste(l, ((pad + 158 + pad) * S, (pad + 158 + pad) * S))
    out = "/var/minis/attachments/ganji-widget-preview.png"
    canvas.save(out)
    print(out, canvas.size)
