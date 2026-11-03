#!/usr/bin/env python3
"""按 SwiftUI 版面坐标渲染 Apple 系统风小组件预览。"""
from PIL import Image, ImageDraw, ImageFont

PAGE = (242, 242, 247)      # systemGroupedBackground
CARD = (255, 255, 255)      # secondarySystemGroupedBackground
TITLE = (0, 0, 0)
SECONDARY = (60, 60, 67, 150)
TERTIARY = (60, 60, 67, 76)
BLUE = (41, 110, 240)       # ganjiBlue 0.16/0.43/0.94
SEP = (60, 60, 67, 40)

BOLD = "/usr/share/fonts/noto/NotoSansCJK-Bold.ttc"
REG = "/usr/share/fonts/noto/NotoSansCJK-Regular.ttc"

S = 2


def rgba(c, bg=PAGE):
    if len(c) == 4:
        a = c[3] / 255
        return tuple(int(c[i] * a + bg[i] * (1 - a)) for i in range(3))
    return c


def f(size, bold=False, rounded=False):
    # 预览里用 Noto 模拟 SF；rounded 用 Bold 近似
    return ImageFont.truetype(BOLD if (bold or rounded) else REG, int(size * S), index=0)


def paper(w, h, radius=20):
    W, H = w * S, h * S
    img = Image.new("RGB", (W, H), PAGE)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius * S, fill=255)
    out = Image.new("RGB", (W, H), (58, 52, 88))
    out.paste(img, (0, 0), m)
    return out


def txt(d, x, y, s, size, color=TITLE, bold=False, rounded=False, anchor="la"):
    d.text((x * S, y * S), s, font=f(size, bold, rounded), fill=rgba(color), anchor=anchor)


def card(d, x, y, w, h, r=11):
    d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S], radius=r * S, fill=CARD)


def hairline(d, x0, x1, y):
    d.rectangle([x0 * S, y * S, x1 * S, y * S + 1], fill=rgba(SEP))


def dot(d, cx, cy, r, color, alpha=1.0):
    col = rgba(color) if alpha >= 1 else tuple(
        int(rgba(color)[i] * alpha + rgba(PAGE)[i] * (1 - alpha)) for i in range(3))
    d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=col)


def small():
    w, h = 158, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 14
    txt(d, p, p, "赶集历", 11, SECONDARY, bold=True)
    txt(d, w - p, p + 1, "11月 周二", 11, SECONDARY, anchor="ra")

    txt(d, p, 34, "3", 40, TITLE, rounded=True)
    txt(d, p + 27, 52, "九月十四", 10, SECONDARY)

    dot(d, p + 2, 118, 2.5, BLUE)
    txt(d, p + 10, 113, "大妙村", 12.5, TITLE, bold=True)
    dot(d, p + 2, 134, 2, BLUE, 0.45)
    txt(d, p + 10, 129, "罗秀镇", 11, SECONDARY)
    return img


def medium():
    w, h = 338, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 14
    txt(d, p, p, "收藏的圩 · 未来七日", 11, SECONDARY, bold=True)
    txt(d, w - p, p + 1, "收藏 4 处", 10, TERTIARY, anchor="ra")

    days = [("二", 3, True), ("三", 4, False), ("四", 5, False), ("五", 6, False),
            ("六", 7, False), ("日", 8, False), ("一", 9, False)]
    name_w = 76
    gx0 = p + name_w
    gstep = (w - p - gx0) / 7

    # 表头
    for i, (wk, day, today) in enumerate(days):
        cx = gx0 + gstep * (i + 0.5)
        txt(d, cx, 32, wk, 9, BLUE if today else TERTIARY, bold=today, anchor="ma")
        txt(d, cx, 44, str(day), 10, BLUE if today else SECONDARY, rounded=today, anchor="ma")

    rows = [("大妙村", [True, False, True, False, False, True, False]),
            ("罗秀镇", [False, False, False, True, False, False, True]),
            ("麻垌镇", [True, False, False, False, True, False, False])]
    y = 62
    for ri, (name, opens) in enumerate(rows):
        txt(d, p, y + 6, name, 11, TITLE)
        for i, o in enumerate(opens):
            cx = gx0 + gstep * (i + 0.5)
            if o:
                dot(d, cx, y + 11, 3, BLUE, 1.0 if i == 0 else 0.45)
            else:
                dot(d, cx, y + 11, 1.5, SEP)
        if ri < len(rows) - 1:
            hairline(d, p, w - p, y + 22)
        y += 25
    txt(d, p, y + 2, "另有 1 处收藏圩", 9, TERTIARY)
    return img


def large():
    w, h = 338, 354
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 14
    txt(d, p, p, "11月", 16, TITLE, rounded=True)
    txt(d, p + 34, p + 5, "未来七日", 11, SECONDARY, bold=True)
    txt(d, w - p, p + 5, "收藏 4 处", 10, TERTIARY, anchor="ra")

    # 七日历卡片
    card(d, p, 36, w - p * 2, 56)
    days = [("二", 3, True, True), ("三", 4, False, False), ("四", 5, False, True),
            ("五", 6, False, True), ("六", 7, False, False), ("日", 8, False, True),
            ("一", 9, False, False)]
    inner = (w - p * 2 - 16) / 7
    for i, (wk, day, today, opens) in enumerate(days):
        cx = p + 8 + inner * (i + 0.5)
        txt(d, cx, 44, wk, 9, BLUE if today else TERTIARY, bold=today, anchor="ma")
        txt(d, cx, 57, str(day), 15, BLUE if today else TITLE, rounded=today, anchor="ma")
        if opens:
            dot(d, cx, 80, 2.5, BLUE)
        else:
            dot(d, cx, 80, 1.5, SEP)

    hairline(d, p, w - p, 104)

    rows = [("大妙村", "今天", True), ("罗秀镇", "11/6", False),
            ("麻垌镇", "11/5", False), ("六陈镇", "七日外", None)]
    y = 112
    for ri, (name, when, today) in enumerate(rows):
        dot(d, p + 2, y + 9, 2.5, BLUE if today else (TERTIARY if when is None else BLUE),
            1.0 if today else (0.6 if when is None else 0.45))
        txt(d, p + 12, y + 3, name, 12, TITLE if when else SECONDARY)
        txt(d, w - p, y + 4, when, 11, BLUE if when else TERTIARY,
            bold=bool(when), rounded=bool(when), anchor="ra")
        if ri < len(rows) - 1:
            hairline(d, p, w - p, y + 22)
        y += 26
    return img


def empty(w, h):
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 14
    txt(d, p, p, "赶集历", 11, SECONDARY, bold=True)
    txt(d, p, h / 2 - 26, "还没有收藏", 14, TITLE, bold=True)
    txt(d, p, h / 2 - 6, "在 App 里点心形收藏圩点", 10, SECONDARY)
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
