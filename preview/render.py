#!/usr/bin/env python3
"""按 SwiftUI 版面的实际坐标渲染预览，用于目视检查密度与留白。

用途是自检，不是真机截图：字体用 Noto CJK，衬线感由 Georgia 替代。
"""
from PIL import Image, ImageDraw, ImageFont

CREAM = (252, 250, 244)
SAND = (242, 233, 216)
INK = (30, 26, 21)
INK_SOFT = (103, 93, 79)
VERM = (190, 58, 38)
JADE = (45, 90, 77)
RULE = (215, 204, 182)

BOLD = "/usr/share/fonts/noto/NotoSansCJK-Bold.ttc"
REG = "/usr/share/fonts/noto/NotoSansCJK-Regular.ttc"
SERIF = "/usr/share/fonts/noto/NotoSerifCJK-Bold.ttc"

S = 2  # 超采样倍数


def f(size, kind="reg"):
    path = {"bold": BOLD, "reg": REG, "serif": SERIF}.get(kind, REG)
    try:
        return ImageFont.truetype(path, int(size * S), index=0)
    except OSError:
        return ImageFont.truetype(BOLD, int(size * S), index=0)


def paper(w, h, radius=20):
    W, H = w * S, h * S
    img = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(img)
    # 上暖下沉的竖向渐变
    for y in range(H):
        t = y / max(1, H - 1)
        c = tuple(int(CREAM[i] + (SAND[i] - CREAM[i]) * t) for i in range(3))
        d.rectangle([0, y, W, y], fill=c)
    # 右上角柔光：多层同心椭圆模拟径向渐变
    cx, cy = W * 0.92, 0
    rmax = W * 0.85
    steps = 26
    for i in range(steps, 0, -1):
        r = rmax * i / steps
        a = 0.06 * (1 - i / steps) ** 1.6
        col = tuple(int(CREAM[j] + (VERM[j] - SAND[j]) * 0.0) for j in range(3))
        base = tuple(int(CREAM[j] + (SAND[j] - CREAM[j]) * (cy / H)) for j in range(3))
        mix = tuple(int(base[j] + (VERM[j] - base[j]) * a) for j in range(3))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=mix)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius * S, fill=255)
    out = Image.new("RGB", (W, H), (60, 54, 92))
    out.paste(img, (0, 0), m)
    return out


def txt(d, x, y, s, size, color=INK, kind="reg", anchor="la"):
    d.text((x * S, y * S), s, font=f(size, kind), fill=color, anchor=anchor)


def rule(d, x0, x1, y):
    d.rectangle([x0 * S, y * S, x1 * S, y * S + 1 * S], fill=RULE)


def tick(d, x, y, h, alpha=1.0):
    col = tuple(int(SAND[i] + (VERM[i] - SAND[i]) * alpha) for i in range(3))
    d.rounded_rectangle([x * S, y * S, (x + 3) * S, (y + h) * S], radius=3 * S, fill=col)


def small():
    w, h = 158, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 13
    txt(d, p, p, "今日", 10, INK_SOFT, "bold")
    txt(d, w - p, p, "周二", 10, INK_SOFT, anchor="ra")

    txt(d, p, 34, "3", 46, INK, "serif")
    txt(d, p + 29, 60, "11月", 10, INK_SOFT, "bold")
    txt(d, p, 90, "九月十四 · 甲辰", 10, INK_SOFT)

    rule(d, p, w - p, 112)

    tick(d, p, 124, 9)
    txt(d, p + 8, 122, "大妙村", 12.5, INK, "bold")
    tick(d, p, 138, 9, 0.35)
    txt(d, p + 8, 136, "罗秀镇", 11, INK_SOFT)
    return img


def medium():
    w, h = 338, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 13
    # 左栏
    txt(d, p, p, "今日", 10, INK_SOFT, "bold")
    txt(d, p + 26, p, "周二", 9, INK_SOFT)
    txt(d, p, 30, "3", 30, INK, "serif")
    txt(d, p + 22, 40, "九月十四", 9, INK_SOFT)
    tick(d, p, 76, 8)
    txt(d, p + 7, 74, "大妙村", 11, INK, "bold")
    tick(d, p, 89, 8, 0.35)
    txt(d, p + 7, 87, "罗秀镇", 10, INK_SOFT)
    txt(d, p + 7, 100, "另有 2 处", 8.5, INK_SOFT)

    # 分隔竖线
    d.rectangle([(p + 96) * S, p * S, (p + 96) * S + S, (h - p) * S], fill=RULE)

    # 右栏
    rx = p + 96 + 13
    txt(d, rx, p, "未来七日", 10, INK_SOFT, "bold")
    txt(d, w - p, p, "收藏 4 处", 9, INK_SOFT, anchor="ra")

    labels = [("二", 3, "today"), ("三", 4, "ring"), ("四", 5, "on"),
              ("五", 6, "on"), ("六", 7, "ring"), ("日", 8, "on"), ("一", 9, "ring")]
    avail = (w - p) - rx
    step = avail / 7
    for i, (wk, day, kind) in enumerate(labels):
        cx = rx + step * (i + 0.5)
        txt(d, cx, 34, wk, 9, VERM if kind == "today" else INK_SOFT, anchor="ma")
        txt(d, cx, 47, str(day), 14, INK if kind != "ring" else INK_SOFT,
            "serif" if kind == "today" else "reg", anchor="ma")
        cy = 70
        if kind == "ring":
            d.ellipse([(cx - 2) * S, (cy - 2) * S, (cx + 2) * S, (cy + 2) * S], fill=RULE)
        else:
            col = VERM if kind == "today" else JADE
            r = 2.5 if kind == "today" else 2.5
            d.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=col)
    return img


def large():
    w, h = 338, 354
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 14
    txt(d, p, p, "11月3日", 15, INK, "serif")
    txt(d, w - p, p + 4, "甲辰 · 九月十四", 9.5, INK_SOFT, anchor="ra")
    rule(d, p, w - p, p + 21)

    rows = [
        ("3", "二", "大妙村 · 罗秀镇", "鼠 / 牛", 2, True),
        ("4", "三", "休", "", 0, False),
        ("5", "四", "麻垌镇 · 六陈镇", "虎 / 蛇", 2, False),
        ("6", "五", "大妙村", "鼠", 1, False),
        ("7", "六", "休", "", 0, False),
        ("8", "日", "罗秀镇 · 麻垌镇 · 六陈镇", "牛 / 虎 / 蛇", 3, False),
        ("9", "一", "休", "", 0, False),
    ]
    y = p + 29
    for num, wk, names, rules, cnt, today in rows:
        rest = cnt == 0
        txt(d, p + 17, y, num, 16, INK_SOFT if rest else INK, "serif" if not today else "serif", anchor="ra")
        txt(d, p + 22, y + 4, wk, 8.5, VERM if today else INK_SOFT, "bold")
        if rest:
            txt(d, p + 40, y + 4, "休", 10, INK_SOFT)
        else:
            txt(d, p + 40, y, names, 11.5, INK, "bold" if today else "reg")
            if rules:
                txt(d, p + 40, y + 14, rules, 8.5, INK_SOFT)
            bx = w - p - 15
            col = VERM if today else tuple(int(CREAM[i] + (JADE[i] - CREAM[i]) * 0.14) for i in range(3))
            d.rounded_rectangle([bx * S, (y + 2) * S, (bx + 15) * S, (y + 17) * S], radius=3 * S, fill=col)
            txt(d, bx + 7.5, y + 9, str(cnt), 10, CREAM if today else JADE, "bold", anchor="mm")
        y += 40

    txt(d, p, h - p - 8, "收藏 4 处", 9, INK_SOFT, "bold")
    txt(d, w - p, h - p - 8, "七日开 8 场", 9, INK_SOFT, anchor="ra")
    return img


def empty(w, h, small_mode=False):
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 13
    txt(d, p, p, "赶集历", 10, INK_SOFT, "bold")
    cy = p + 6
    d.ellipse([(w - p - 6) * S, cy * S, (w - p) * S, (cy + 6) * S], outline=VERM, width=int(1.2 * S))

    ty = p + 40
    tick(d, p, ty + 3, 12 if small_mode else 15)
    txt(d, p + 10, ty, "还没有收藏", 14 if small_mode else 16, INK, "serif")
    body = "在 App 里点心形收藏" if small_mode else "打开「赶集日记」，在心仪的圩点上点一下心形"
    txt(d, p + 10, ty + 24, body, 9.5 if small_mode else 10.5, INK_SOFT)
    rule(d, p, w - p, h - p - 20)
    txt(d, p, h - p - 13, "心形 = 收藏", 8.5, INK_SOFT, "bold")
    return img


if __name__ == "__main__":
    s, m, l = small(), medium(), large()
    e1, e2 = empty(158, 158, True), empty(338, 158)
    pad = 22
    W = pad + 158 + pad + 338 + pad
    H = pad + 158 + pad + 158 + pad + 354 + pad
    canvas = Image.new("RGB", (W * S, H * S), (60, 54, 92))
    canvas.paste(s, (pad * S, pad * S))
    canvas.paste(m, ((pad + 158 + pad) * S, pad * S))
    canvas.paste(e1, (pad * S, (pad + 158 + pad) * S))
    canvas.paste(e2, ((pad + 158 + pad) * S, (pad + 158 + pad) * S))
    canvas.paste(l, (pad * S, (pad + 158 + pad + 158 + pad) * S))
    out = "/var/minis/attachments/ganji-widget-preview.png"
    canvas.save(out)
    print(out, canvas.size)
