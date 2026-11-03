#!/usr/bin/env python3
"""大卡片风（车票）小组件预览。"""
from PIL import Image, ImageDraw, ImageFont

PAGE = (237, 237, 242)
TICKET = (41, 102, 230)
TICKET_DEEP = (26, 77, 184)
GRAY_TICKET = (140, 143, 149)
WHITE = (255, 255, 255)
TITLE = (26, 28, 33)
SECONDARY = (107, 112, 122)
TERTIARY = (153, 158, 168)

BOLD = "/usr/share/fonts/noto/NotoSansCJK-Bold.ttc"
REG = "/usr/share/fonts/noto/NotoSansCJK-Regular.ttc"
S = 2


def f(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REG, int(size * S), index=0)


def txt(d, x, y, s, size, color=TITLE, bold=False, anchor="la"):
    d.text((x * S, y * S), s, font=f(size, bold), fill=color, anchor=anchor)


def paper(w, h, radius=20):
    W, H = w * S, h * S
    img = Image.new("RGB", (W, H), PAGE)
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius * S, fill=255)
    out = Image.new("RGB", (W, H), (52, 48, 78))
    out.paste(img, (0, 0), m)
    return out


def ticket(d, x, y, w, h, title, sub, open_):
    col = TICKET if open_ else GRAY_TICKET
    d.rounded_rectangle([x * S, y * S, (x + w) * S, (y + h) * S], radius=15 * S, fill=col)
    txt(d, x + 13, y + 9, sub, 9, (255, 255, 255), bold=True)
    txt(d, x + 13, y + 22, title, 21, WHITE, bold=True)
    return y + h


def meter(d, x, y, w, boards):
    """七格进度条：走过=淡、今天=白、未来开圩=半透明白、休=更淡。"""
    n = len(boards)
    step = w / n
    for i, opens in enumerate(boards):
        bx = x + step * i + 1.5
        bw = step - 3
        if i == 0:
            col = WHITE
        elif opens:
            col = (255, 255, 255)
        else:
            col = (255, 255, 255)
        alpha = 1.0 if i == 0 else (0.55 if opens else 0.18)
        c = tuple(int(WHITE[j] * alpha + col_page[j] * (1 - alpha)) for j in range(3))
        d.rounded_rectangle([bx * S, y * S, (bx + bw) * S, (y + 5) * S], radius=2.5 * S, fill=c)


col_page = PAGE

# 灰票颜色混合需要页面底色，先定义
def blend_on(col_ticket, alpha):
    return tuple(int(WHITE[i] * alpha + col_ticket[i] * (1 - alpha)) for i in range(3))


def small():
    w, h = 158, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 13
    txt(d, p, p, "3", 34, TITLE, bold=True)
    txt(d, p + 26, p + 2, "周二", 11, TITLE, bold=True)
    txt(d, p + 26, p + 18, "九月十四", 9, TERTIARY)

    ticket(d, p, 52, w - p * 2, 52, "大妙村", "今天开圩 · 另有 1 处", True)

    # DayMeter: 今天开、明休、后开、开、休、开、休
    boards = [True, False, True, True, False, True, False]
    meter(d, p, 128, w - p * 2, boards)
    return img


def medium():
    w, h = 338, 158
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 13

    # 左：主卡
    ticket(d, p, 16, 148, 56, "大妙村", "今天 · 2 场", True)

    # 右：接下来
    rx = p + 148 + 14
    txt(d, rx, 16, "接下来", 10, SECONDARY, bold=True)
    rows = [("明天", "罗秀镇"), ("周四", "麻垌镇")]
    y = 34
    for i, (lbl, name) in enumerate(rows):
        txt(d, rx, y, lbl, 10, SECONDARY, bold=True)
        txt(d, rx + 30, y - 2, name, 12, TITLE, bold=True)
        if i == 0:
            d.rectangle([rx * S, (y + 20) * S, (w - p) * S, (y + 20) * S + 1],
                        fill=(26, 28, 33, 18))
        y += 26
    txt(d, rx, y - 6, "休", 12, TERTIARY)

    boards = [True, False, True, True, False, True, False]
    meter(d, p, 132, w - p * 2, boards)
    return img


def large():
    w, h = 338, 354
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 14
    txt(d, p, p, "11月3日 周二", 15, TITLE, bold=True)
    txt(d, w - p, p + 4, "收藏 4 处", 10, SECONDARY, anchor="ra")

    # 主卡 + 右侧剩余圩名
    ty = 36
    d.rounded_rectangle([p * S, ty * S, (w - p) * S, (ty + 62) * S], radius=15 * S, fill=TICKET)
    txt(d, p + 13, ty + 10, "今天开圩 · 共 2 场", 9, WHITE, bold=True)
    txt(d, p + 13, ty + 24, "大妙村", 21, WHITE, bold=True)
    txt(d, w - p - 13, ty + 16, "罗秀镇", 9, (255, 255, 255), bold=True, anchor="ra")

    # 接下来七天 + meter
    my = 118
    txt(d, p, my, "接下来七天", 10, SECONDARY, bold=True)
    boards = [False, True, True, False, True, False, False]
    meter(d, w - p - 120, my - 1, 120, [not b for b in boards])  # 示意

    rows = [("明", "罗秀镇", 1), ("后", "麻垌镇 · 六陈镇", 2),
            ("周四", "大妙村", 1), ("周五", "休", 0)]
    y = 140
    for lbl, names, cnt in rows:
        col = TICKET if cnt else TERTIARY
        badge = tuple(int(TICKET[i] * 0.12 + PAGE[i] * 0.88) for i in range(3)) if cnt else \
            tuple(int(TERTIARY[i] * 0.12 + PAGE[i] * 0.88) for i in range(3))
        d.ellipse([p * S, y * S, (p + 22) * S, (y + 22) * S], fill=badge)
        txt(d, p + 11, y + 4.5, lbl, 11, col, bold=True, anchor="ma")
        txt(d, p + 31, y + 3, names, 12.5, TITLE if cnt else TERTIARY, bold=bool(cnt))
        if cnt:
            txt(d, w - p, y + 5, str(cnt), 10, SECONDARY, bold=True, anchor="ra")
        y += 30
    return img


def empty(w, h):
    img = paper(w, h)
    d = ImageDraw.Draw(img)
    p = 13
    ticket(d, p, p, w - p * 2, 56, "去收藏圩点", "还没有收藏", False)
    txt(d, p, p + 68, "点心形，这里就会出现它", 10, SECONDARY)
    return img


if __name__ == "__main__":
    s, m, l = small(), medium(), large()
    e1 = empty(158, 158)
    pad = 22
    W = pad + 158 + pad + 338 + pad
    H = pad + 158 + pad + 158 + pad + 354 + pad
    canvas = Image.new("RGB", (W * S, H * S), (52, 48, 78))
    canvas.paste(s, (pad * S, pad * S))
    canvas.paste(m, ((pad + 158 + pad) * S, pad * S))
    canvas.paste(e1, (pad * S, (pad + 158 + pad) * S))
    canvas.paste(l, ((pad + 158 + pad) * S, (pad + 158 + pad) * S))
    out = "/var/minis/attachments/ganji-widget-preview.png"
    canvas.save(out)
    print(out, canvas.size)
