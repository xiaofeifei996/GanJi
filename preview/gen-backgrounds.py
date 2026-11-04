#!/usr/bin/env python3
"""生成江南水墨风小组件背景图（烟雨远山 + 花枝 + 湖面），输出到 Widget 资源目录。"""
import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = "/var/minis/workspace/GanJi/Widget/Assets.xcassets"


def canvas(w, h):
    """天空底：上灰蓝下亮，整体偏烟雨灰。"""
    img = Image.new("RGB", (w, h), (226, 230, 231))
    d = ImageDraw.Draw(img)
    top = (203, 209, 212)
    mid = (233, 236, 236)
    bot = (213, 219, 221)
    for y in range(h):
        t = y / max(1, h - 1)
        if t < 0.55:
            u = t / 0.55
            c = tuple(int(top[i] + (mid[i] - top[i]) * u) for i in range(3))
        else:
            u = (t - 0.55) / 0.45
            c = tuple(int(mid[i] + (bot[i] - mid[i]) * u) for i in range(3))
        d.rectangle([0, y, w, y], fill=c)
    return img


def layer(img, blur):
    l = Image.new("RGBA", img.size, (0, 0, 0, 0))
    return l, ImageDraw.Draw(l), blur


def composite(img, l, blur):
    if blur:
        l = l.filter(ImageFilter.GaussianBlur(blur))
    img.paste(Image.alpha_composite(img.convert("RGBA"), l).convert("RGB"), (0, 0))
    return img


def ridge(img, y_base, amp, color, alpha, blur, seed):
    w, h = img.size
    l, d, _ = layer(img, 0)
    rnd = random.Random(seed)
    step = max(20, w // 16)
    pts = [(0, h)]
    ys = []
    for x in range(0, w + step, step):
        y = y_base * h + rnd.uniform(-amp, amp) * h
        ys.append((x, y))
    # 平滑一点：相邻点取中值过渡
    smooth = []
    for i, (x, y) in enumerate(ys):
        if 0 < i < len(ys) - 1:
            y = (ys[i - 1][1] + y * 2 + ys[i + 1][1]) / 4
        smooth.append((x, y))
    pts += [(int(x), int(y)) for x, y in smooth]
    pts += [(w, h)]
    d.polygon(pts, fill=(*color, alpha))
    return composite(img, l, blur)


def mist(img, y, thickness, alpha, blur):
    w, h = img.size
    l, d, _ = layer(img, 0)
    d.ellipse([-w * 0.2, y * h - thickness * h / 2, w * 1.2, y * h + thickness * h / 2],
              fill=(242, 244, 244, alpha))
    return composite(img, l, blur)


def water(img, y0):
    w, h = img.size
    l, d, _ = layer(img, 0)
    for y in range(int(y0 * h), h):
        t = (y - y0 * h) / max(1, h * (1 - y0))
        c = (int(208 - 16 * t), int(215 - 16 * t), int(217 - 14 * t), 255)
        d.rectangle([0, y, w, y], fill=c)
    rnd = random.Random(7)
    for _ in range(10):
        x0 = rnd.uniform(0, w * 0.8)
        ln = rnd.uniform(w * 0.06, w * 0.22)
        y = rnd.uniform(y0 * h + 8, h - 6)
        d.rectangle([x0, y, x0 + ln, y + 1.2], fill=(255, 255, 255, 70))
    return composite(img, l, 2.2)


def blossom(img, ox, oy, scale, seed):
    """白梅花枝：从 (ox,oy) 向右下伸展。"""
    w, h = img.size
    l, d, _ = layer(img, 0)
    rnd = random.Random(seed)
    # 主枝与分枝
    branches = [
        (ox, oy, ox + 0.34 * w * scale, oy + 0.10 * h * scale, 5),
        (ox + 0.10 * w * scale, oy + 0.03 * h * scale, ox + 0.30 * w * scale, oy - 0.06 * h * scale, 3.4),
        (ox + 0.05 * w * scale, oy + 0.04 * h * scale, ox + 0.16 * w * scale, oy + 0.22 * h * scale, 3),
    ]
    for x0, y0, x1, y1, wd in branches:
        steps = 14
        for i in range(steps):
            t0, t1 = i / steps, (i + 1) / steps
            xa = x0 + (x1 - x0) * t0 + math.sin(t0 * 6) * 6 * scale
            ya = y0 + (y1 - y0) * (t0 ** 0.9)
            xb = x0 + (x1 - x0) * t1 + math.sin(t1 * 6) * 6 * scale
            yb = y0 + (y1 - y0) * (t1 ** 0.9)
            d.line([xa, ya, xb, yb], fill=(96, 76, 66, 200), width=max(1, int(wd * scale)))
    # 花
    for _ in range(int(26 * scale)):
        bx = rnd.uniform(ox, ox + 0.36 * w * scale)
        by = oy + rnd.uniform(-0.09, 0.26) * h * scale
        r = rnd.uniform(3.2, 6.2) * scale
        cx, cy = bx, by
        for k in range(5):
            a = k / 5 * math.tau
            px, py = cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.8
            d.ellipse([px - r * 0.55, py - r * 0.55, px + r * 0.55, py + r * 0.55],
                      fill=(251, 249, 245, 235))
        d.ellipse([cx - r * 0.28, cy - r * 0.28, cx + r * 0.28, cy + r * 0.28],
                  fill=(236, 214, 150, 235))
    return composite(img, l, 0.6)


def pagoda(img, cx, base_y, scale):
    w, h = img.size
    l, d, _ = layer(img, 0)
    col = (96, 116, 121, 130)
    tiers = [(54, 20), (42, 18), (30, 16)]
    y = base_y * h
    x = cx * w
    for i, (tw, th) in enumerate(tiers):
        bw = tw * scale
        bh = th * scale
        # 檐（梯形，微翘角）
        d.polygon([(x - bw / 2 - 5 * scale, y), (x + bw / 2 + 5 * scale, y),
                   (x + bw / 2 - 6 * scale, y - bh), (x - bw / 2 + 6 * scale, y - bh)], fill=col)
        y -= bh + 3 * scale
    # 塔身
    d.rectangle([x - 8 * scale, y, x + 8 * scale, base_y * h], fill=col)
    # 塔尖
    d.line([x, y, x, y - 14 * scale], fill=col, width=max(1, int(2 * scale)))
    return composite(img, l, 1.4)


def birds(img, pts):
    l, d, _ = layer(img, 0)
    for x, y, s in pts:
        d.arc([x - s, y - s * 0.6, x, y + s * 0.6], 200, 340, fill=(70, 82, 88, 150), width=2)
        d.arc([x, y - s * 0.6, x + s, y + s * 0.6], 200, 340, fill=(70, 82, 88, 150), width=2)
    return composite(img, l, 0.8)


def boat(img, cx, y, scale):
    l, d, _ = layer(img, 0)
    x, yy = cx * img.size[0], y * img.size[1]
    col = (52, 66, 70, 185)
    d.polygon([(x - 26 * scale, yy), (x + 26 * scale, yy),
               (x + 18 * scale, yy + 7 * scale), (x - 18 * scale, yy + 7 * scale)], fill=col)
    d.line([x, yy, x, yy - 22 * scale], fill=col, width=max(1, int(1.6 * scale)))
    d.rectangle([x + 2 * scale, yy - 10 * scale, x + 12 * scale, yy], fill=col)
    # 倒影
    l2 = l.filter(ImageFilter.GaussianBlur(1.2))
    refl = l2.crop((0, int(yy), img.size[0], int(yy + 10 * scale))).transpose(Image.FLIP_TOP_BOTTOM)
    base = l2.crop((0, 0, img.size[0], int(10 * scale)))
    l2.paste(refl, (0, int(yy + 8 * scale)))
    return composite(img, l2, 0)


def houses(img, x0, y0, scale):
    l, d, _ = layer(img, 0)
    rnd = random.Random(11)
    x = x0 * img.size[0]
    y = y0 * img.size[1]
    for i in range(3):
        bw = rnd.uniform(46, 74) * scale
        bh = rnd.uniform(20, 30) * scale
        d.rectangle([x, y - bh, x + bw, y], fill=(243, 243, 240, 225))
        d.polygon([(x - 3, y - bh), (x + bw + 3, y - bh),
                   (x + bw * 0.7, y - bh - 8 * scale), (x + bw * 0.3, y - bh - 8 * scale)],
                  fill=(88, 102, 108, 200))
        x += bw + 8 * scale
        y -= rnd.uniform(0, 6) * scale
    return composite(img, l, 1.0)


def save(img, name):
    folder = os.path.join(OUT, f"{name}.imageset")
    os.makedirs(folder, exist_ok=True)
    path = os.path.join(folder, "bg.png")
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(path, optimize=True)
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        f.write('{"images":[{"filename":"bg.png","idiom":"universal"}],'
                '"info":{"author":"xcode","version":1}}')
    print(path, img.size, os.path.getsize(path) // 1024, "KB")


# 小号：花枝占左上，山水中景，湖面收底
img = canvas(600, 600)
img = ridge(img, 0.46, 0.055, (168, 179, 181), 120, 5, 1)
img = mist(img, 0.50, 0.10, 150, 10)
img = ridge(img, 0.58, 0.05, (134, 152, 154), 100, 6, 2)
img = mist(img, 0.62, 0.09, 140, 12)
img = ridge(img, 0.66, 0.045, (108, 128, 132), 80, 7, 3)
img = water(img, 0.76)
img = blossom(img, 0.02, 0.08, 1.0, 5)
save(img, "InkSmall")

# 中号：横幅远山，右塔右鸟
img = canvas(1240, 580)
img = ridge(img, 0.30, 0.09, (172, 182, 184), 120, 5, 21)
img = mist(img, 0.36, 0.10, 150, 10)
img = ridge(img, 0.44, 0.07, (136, 154, 156), 95, 7, 22)
img = mist(img, 0.50, 0.08, 135, 12)
img = ridge(img, 0.55, 0.05, (110, 130, 134), 75, 8, 23)
img = water(img, 0.70)
img = pagoda(img, 0.855, 0.52, 1.15)
img = birds(img, [(0.76, 0.10, 9), (0.82, 0.14, 7), (0.90, 0.09, 10), (0.95, 0.16, 6)])
save(img, "InkMedium")

# 大号：左侧花枝大，湖面宽，右下屋舍与小船
img = canvas(1040, 1090)
img = ridge(img, 0.28, 0.08, (170, 181, 183), 120, 5, 41)
img = mist(img, 0.35, 0.10, 150, 11)
img = ridge(img, 0.42, 0.07, (136, 154, 156), 95, 7, 42)
img = mist(img, 0.48, 0.08, 140, 12)
img = ridge(img, 0.52, 0.06, (110, 130, 134), 80, 8, 43)
img = water(img, 0.66)
img = blossom(img, 0.015, 0.05, 1.35, 45)
img = houses(img, 0.74, 0.90, 1.15)
img = boat(img, 0.56, 0.93, 1.2)
save(img, "InkLarge")

# 资源目录根 manifest
with open(os.path.join(OUT, "Contents.json"), "w") as f:
    f.write('{"info":{"author":"xcode","version":1}}')
print("assets done")
