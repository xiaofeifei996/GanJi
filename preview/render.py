#!/usr/bin/env python3
"""用 PIL 按 SwiftUI 版面的坐标关系渲染三个尺寸的预览图，用于目视检查密度与可读性。"""
from PIL import Image, ImageDraw, ImageFont

CREAM = (251, 246, 236)
SAND = (241, 231, 210)
INK = (41, 38, 36)
INK_SOFT = (112, 106, 93)
VERM = (194, 66, 46)
JADE = (56, 92, 92)
RULE = (154, 139, 110)

BOLD = "/usr/share/fonts/noto/NotoSansCJK-Bold.ttc"
REG = "/usr/share/fonts/noto/NotoSansCJK-Regular.ttc"


def font(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REG, size, index=0)


def paper(w, h, radius=22, scale=2):
    """宣纸底 + 右上角极淡朱砂圆。"""
    W, H = w * scale, h * scale
    img = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(img)
    # 斜向渐变
    for y in range(H):
        t = y / max(1, H - 1)
        for x in range(0, W, 4):
            u = (x / max(1, W - 1) + t) / 2
            c = tuple(int(CREAM[i] + (SAND[i] - CREAM[i]) * u) for i in range(3))
            d.rectangle([x, y, x + 3, y], fill=c)
    # 朱砂圆
    r = W * 0.95
    cx, cy = W * 0.94, H * 0.04
    overlay = Image.new("RGB", (W, H), (0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=1)
    mask = mask.point(lambda v: int(v * 0.055 * 255 / 255 * 1))
    tint = Image.new("RGB", (W, H), VERM)
    img.paste(Image.blend(img, tint, 0.055), (0, 0), mask)
    # 圆角
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius * scale, fill=255)
    out = Image.new("RGB", (W, H), (34, 32, 30))
    out.paste(img, (0, 0), m)
    return out


def text(d, xy, s, size, color=INK, bold=False, anchor="la"):
    d.text((xy[0] * 2, xy[1] * 2), s, font=font(size * 2, bold), fill=color, anchor=anchor)


def dot(d, cx, cy, r, fill=None, outline=None, width=1):
    box = [(cx - r) * 2, (cy - r) * 2, (cx + r) * 2, (cy + r) * 2]
    if fill:
        d.ellipse(box, fill=fill)
    if outline:
        d.ellipse(box, outline=outline, width=width * 2)


def hairline(d, x0, x1, y, alpha=0.38):
    c = tuple(int(CREAM[i] + (RULE[i] - CREAM[i]) * alpha) for i in range(3))
    d.rectangle([x0 * 2, y * 2, x1 * 2, y * 2 + 1], fill=c)


# ---------------- 小号：印章 ----------------
def small():
    img = paper(158, 158)
    d = ImageDraw.Draw(img)
    text(d, (13, 12), "今日", 10, INK_SOFT, bold=True)
    text(d, (45, 12), "周二", 10, INK_SOFT, bold=True)
    text(d, (145, 12), "3 处", 9, VERM, bold=True, anchor="ra")

    # 印章
    x, y, s = 13, 45, 54
    d.rounded_rectangle([x * 2, y * 2, (x + s) * 2, (y + s) * 2], radius=18, fill=VERM)
    text(d, (x + s / 2, y + s / 2 - 2), "3", 34, CREAM, bold=True, anchor="mm")

    text(d, (76, 48), "九月十四", 11, INK, bold=True)
    text(d, (76, 66), "甲辰日", 10, INK_SOFT)

    hairline(d, 13, 145, 110)

    dot(d, 15, 124, 2, fill=VERM)
    text(d, (21, 117), "大妙圩", 13, INK, bold=True)
    dot(d, 15, 139, 2, fill=tuple(int(CREAM[i] + (VERM[i] - CREAM[i]) * .4) for i in range(3)))
    text(d, (21, 132), "登明圩", 11, INK_SOFT)

    return img


# ---------------- 中号：刻度带 ----------------
def medium():
    img = paper(338, 158)
    d = ImageDraw.Draw(img)
    text(d, (13, 12), "桂平市", 12, INK, bold=True)
    text(d, (338 - 13, 14), "未来七日", 10, INK_SOFT, bold=True, anchor="ra")

    labels = [("周二", 3, "today"), ("周三", 4, "ring"), ("周四", 5, "on"),
              ("周五", 6, "on"), ("周六", 7, "ring"), ("周日", 8, "on"), ("周一", 9, "ring")]
    inner = 338 - 26
    step = inner / 7
    for i, (wk, day, kind) in enumerate(labels):
        cx = 13 + step * (i + 0.5)
        text(d, (cx, 38), wk, 9, VERM if kind == "today" else INK_SOFT, bold=True, anchor="ma")
        text(d, (cx, 52), str(day), 15, INK if kind != "ring" else INK_SOFT, bold=(kind == "today"), anchor="ma")
        if kind == "ring":
            dot(d, cx, 78, 2.5, outline=RULE)
        else:
            dot(d, cx, 78, 2.5, fill=VERM if kind == "today" else JADE)

    hairline(d, 13, 325, 108)
    d.rectangle([13 * 2, 122 * 2, 13 * 2 + 6, 122 * 2 + 24], fill=VERM)
    text(d, (19, 122), "大妙圩 · 登明圩 · 石龙圩 等 4 处", 11, INK)
    return img


# ---------------- 大号：历书页 ----------------
def large():
    img = paper(338, 354)
    d = ImageDraw.Draw(img)
    text(d, (15, 14), "11月3日 · 周二", 15, INK, bold=True)
    text(d, (323, 17), "甲辰 · 九月十四", 10, INK_SOFT, anchor="ra")

    hairline(d, 15, 323, 40, 0.38)

    rows = [
        ("3", "周二", "甲辰", "大妙圩 · 登明圩", "兔 / 马", 2, True, False),
        ("4", "周三", "乙巳", "休市", "", 0, False, True),
        ("5", "周四", "丙午", "石龙圩 · 罗秀圩", "农历初一 · 十五", 2, False, False),
        ("6", "周五", "丁未", "木乐圩", "鼠", 1, False, False),
        ("7", "周六", "戊申", "休市", "", 0, False, True),
        ("8", "周日", "己酉", "大妙圩 · 江口圩 · 蒙圩", "兔 / 马 / 牛", 3, False, False),
        ("9", "周一", "庚戌", "休市", "", 0, False, True),
    ]
    y = 52
    for i, (num, wk, gz, names, rules, cnt, today, rest) in enumerate(rows):
        text(d, (15 + 24, y), num, 17, (150, 144, 130) if rest else INK, bold=today, anchor="ra")
        text(d, (47, y - 2), wk, 9, VERM if today else INK_SOFT, bold=True)
        text(d, (47, y + 11), gz, 8, (150, 144, 130))
        if rest:
            text(d, (91, y + 2), "休市", 11, (150, 144, 130))
        else:
            text(d, (91, y - 1), names, 12, INK, bold=today)
            text(d, (91, y + 15), rules, 9, INK_SOFT)
            bw = 20
            bx = 323 - bw
            d.rounded_rectangle([bx * 2, (y + 2) * 2, (bx + 18) * 2, (y + 14) * 2], radius=8,
                                fill=VERM if today else JADE)
            text(d, (bx + 9, y + 3.5), str(cnt), 11, CREAM, bold=True, anchor="ma")
        if i < len(rows) - 1:
            hairline(d, 49, 323, y + 26, 0.22)
        y += 38
    text(d, (15, y + 4), "桂 平 市", 9, INK_SOFT, bold=True)
    text(d, (323, y + 4), "七日 9 场", 9, INK_SOFT, anchor="ra")
    return img


if __name__ == "__main__":
    out = "/var/minis/attachments/ganji-widget-preview.png"
    s, m, l = small(), medium(), large()
    pad = 22
    W = pad + 158 + pad + 338 + pad
    H = pad + 158 + pad + 354 + pad
    canvas = Image.new("RGB", (W * 2, H * 2), (34, 32, 30))
    canvas.paste(s, (pad * 2, pad * 2))
    canvas.paste(m, ((pad + 158 + pad) * 2, pad * 2))
    canvas.paste(l, (pad * 2, (pad + 158 + pad) * 2))
    canvas.save(out)
    print(out, canvas.size)
