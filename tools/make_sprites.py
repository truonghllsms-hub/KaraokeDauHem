#!/usr/bin/env python3
"""Sinh bộ hình SVG nguyên bản cho game (nhân vật chibi và đồ vật).
Chạy: python3 tools/make_sprites.py   -> ghi vào assets/sprites/
Muốn thay bằng tranh vẽ tay: chỉ cần ghi đè tệp cùng tên trong assets/sprites/."""
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
LINE = "#4a2f27"
EYE = "#2e1c1a"
LW = 2.2


def svg(w, h, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*2}" height="{h*2}" viewBox="0 0 {w} {h}">{body}</svg>\n'


def write(name, content):
    with open(os.path.join(OUT, name + ".svg"), "w", encoding="utf-8") as f:
        f.write(content)


def shade(color, factor):
    """factor < 1 làm tối, > 1 làm sáng."""
    c = color.lstrip("#")
    rgb = [int(c[i:i + 2], 16) for i in (0, 2, 4)]
    if factor <= 1:
        rgb = [int(v * factor) for v in rgb]
    else:
        rgb = [int(v + (255 - v) * (factor - 1)) for v in rgb]
    return "#%02x%02x%02x" % tuple(rgb)


def face(cx, cy, skin, k=1.0, eyes="dot", mouth="smile", lashes=False, lips=None, mustache=False, glasses=False, brows=True, shadow=None):
    """Mặt chibi: mắt hạt đậu đặt thấp, má hồng to, miệng nhỏ. k là tỉ lệ so với đầu chibi chuẩn."""
    rx, ry = 19 * k, 17.5 * k
    lw = max(1.5, LW * (0.85 if k < 1 else 1))
    s = ""
    for sx in (-1, 1):
        s += f'<ellipse cx="{cx + sx*rx*0.97}" cy="{cy + 3.5*k}" rx="{3.4*k}" ry="{4*k}" fill="{skin}" stroke="{LINE}" stroke-width="{lw}"/>'
    s += f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{skin}" stroke="{LINE}" stroke-width="{lw}"/>'
    s += f'<path d="M{cx - rx*0.8} {cy + ry*0.55} Q{cx} {cy + ry*1.12} {cx + rx*0.8} {cy + ry*0.55} Q{cx} {cy + ry*0.92} {cx - rx*0.8} {cy + ry*0.55}z" fill="{shade(skin, 0.86)}" opacity="0.55"/>'
    ex, ey = 7.6 * k, cy + 4.6 * k
    for sx in (-1, 1):
        x = cx + sx * ex
        s += f'<ellipse cx="{cx + sx*12.4*k}" cy="{cy + 9.6*k}" rx="{4*k}" ry="{2.5*k}" fill="#ff8c9c" opacity="0.6"/>'
        if shadow:
            s += f'<ellipse cx="{x}" cy="{ey - 1.6*k}" rx="{3.6*k}" ry="{2.6*k}" fill="{shadow}" opacity="0.5"/>'
        if eyes == "happy":
            s += f'<path d="M{x - 2.8*k} {ey + 0.8*k} q{2.8*k} {-3.6*k} {5.6*k} 0" fill="none" stroke="{EYE}" stroke-width="{1.9*k + 0.3}" stroke-linecap="round"/>'
        else:
            big = 1.25 if lashes else 1.0
            s += f'<ellipse cx="{x}" cy="{ey}" rx="{2.1*k*big}" ry="{2.9*k*big}" fill="{EYE}"/>'
            s += f'<circle cx="{x - 0.7*k}" cy="{ey - 1.1*k}" r="{0.85*k*big}" fill="#fff"/>'
        if lashes:
            s += f'<path d="M{x + sx*1.8*k} {ey - 1.6*k} q{sx*2.2*k} {-0.6*k} {sx*3.2*k} {-2.4*k}" fill="none" stroke="{EYE}" stroke-width="{1.2*k + 0.3}" stroke-linecap="round"/>'
        if brows:
            s += f'<path d="M{x - 2.6*k} {ey - 6.4*k} q{2.6*k} {-1.5*k} {5.2*k} 0" fill="none" stroke="{LINE}" stroke-width="{1.3*k + 0.2}" stroke-linecap="round" opacity="0.75"/>'
        if glasses:
            s += f'<circle cx="{x}" cy="{ey}" r="{4.8*k}" fill="#fff" fill-opacity="0.25" stroke="{LINE}" stroke-width="1.5"/>'
    if glasses:
        s += f'<path d="M{cx - ex + 4.8*k} {ey} H{cx + ex - 4.8*k}" stroke="{LINE}" stroke-width="1.5"/>'
    my = cy + 10.2 * k
    if mustache:
        s += f'<path d="M{cx} {my - 1.2*k} q{-3*k} {-2.6*k} {-6.5*k} {0.6*k} q{4*k} {1.8*k} {6.5*k} {0.2*k} q{2.5*k} {1.6*k} {6.5*k} {-0.2*k} q{-3.5*k} {-3.2*k} {-6.5*k} {-0.6*k}z" fill="{shade(LINE, 0.8)}"/>'
        my += 2.2 * k
    if lips:
        s += f'<path d="M{cx - 2.8*k} {my} q{1.4*k} {-1.3*k} {2.8*k} {-0.3*k} q{1.4*k} {-1*k} {2.8*k} {0.3*k} q{-2.8*k} {3.4*k} {-5.6*k} 0z" fill="{lips}" stroke="{shade(lips, 0.7)}" stroke-width="0.5"/>'
    elif mouth == "open":
        s += f'<path d="M{cx - 3*k} {my - 0.6*k} q{3*k} {-1*k} {6*k} 0 q{-0.4*k} {4.6*k} {-3*k} {4.6*k} q{-2.6*k} 0 {-3*k} {-4.6*k}z" fill="#a8424e" stroke="{LINE}" stroke-width="1.3" stroke-linejoin="round"/>'
        s += f'<ellipse cx="{cx}" cy="{my + 2.8*k}" rx="{1.7*k}" ry="{1*k}" fill="#ff8c9c"/>'
    elif mouth == "smile":
        s += f'<path d="M{cx - 2.8*k} {my} q{2.8*k} {2.9*k} {5.6*k} 0" fill="none" stroke="{LINE}" stroke-width="{1.5*k + 0.2}" stroke-linecap="round"/>'
    return s


def hair(style, cx, cy, color, k=1.0):
    """Trả về (phần tóc sau đầu, phần tóc trước mặt). Tóc phồng hơn đầu một chút và có vệt sáng."""
    lw = max(1.5, LW * (0.85 if k < 1 else 1))
    st = f'fill="{color}" stroke="{LINE}" stroke-width="{lw}" stroke-linejoin="round"'
    hi = shade(color, 1.45)

    def P(x, y):
        return f'{cx + x*k:.1f} {cy + y*k:.1f}'

    cap = f'M{P(-20, -1)} C{P(-22, -24)} {P(22, -24)} {P(20, -1)}'
    shine = f'<path d="M{P(-11, -15.5)} Q{P(-3, -20.5)} {P(7, -18)}" fill="none" stroke="{hi}" stroke-width="{2.4*k}" stroke-linecap="round" opacity="0.75"/>'
    back = front = ""
    if style == "short":
        front = f'<path d="{cap} L{P(16.5, -3)} C{P(15, -9)} {P(8, -12.5)} {P(0, -11.5)} C{P(-7, -10.5)} {P(-13, -7)} {P(-16.5, -1.5)}z" {st}/>' + shine
    elif style == "spiky":
        front = (f'<path d="M{P(-20, -1)} C{P(-22, -14)} {P(-17, -21)} {P(-12, -22)} L{P(-10, -27)} L{P(-5, -22.5)} L{P(-1, -28.5)} L{P(3, -22.5)} L{P(8, -27)} L{P(11, -21.5)} '
                 f'C{P(18, -19)} {P(22, -12)} {P(20, -1)} L{P(16.5, -3)} L{P(13, -9.5)} L{P(9.5, -4.5)} L{P(5, -11)} L{P(1, -5.5)} L{P(-4, -11.5)} L{P(-8, -5.5)} L{P(-12.5, -10)} L{P(-16.5, -2)}z" {st}/>') + shine
    elif style == "bald":
        front = f'<path d="M{P(-20, 1)} C{P(-21, -6)} {P(-19, -11)} {P(-15, -13)} C{P(-16, -8)} {P(-16, -3)} {P(-16.5, 3)}z M{P(20, 1)} C{P(21, -6)} {P(19, -11)} {P(15, -13)} C{P(16, -8)} {P(16, -3)} {P(16.5, 3)}z" {st}/>'
        front += f'<path d="M{P(-4, -16.5)} q{2*k} {-3*k} {4*k} 0 M{P(1, -17)} q{2*k} {-3*k} {4.5*k} {0.5*k}" fill="none" stroke="{color}" stroke-width="1.6" stroke-linecap="round"/>'
        front += f'<path d="M{P(-9, -12)} Q{P(-3, -15)} {P(4, -14)}" fill="none" stroke="#fff" stroke-width="{2.2*k}" stroke-linecap="round" opacity="0.5"/>'
    elif style == "curly":  # tóc uốn của các cô
        bumps = [(-19, -3, 5.5), (-18.5, -11, 6), (-13, -18, 6.5), (-5, -21.5, 6.5), (4, -21.5, 6.5), (12, -18.5, 6.5), (18.5, -11, 6), (19, -3, 5.5)]
        back = "".join(f'<circle cx="{cx + x*k}" cy="{cy + y*k}" r="{r*k}" {st}/>' for x, y, r in bumps)
        back += f'<ellipse cx="{cx}" cy="{cy - 6*k}" rx="{19*k}" ry="{15*k}" fill="{color}"/>'
        front = f'<path d="M{P(-17.5, -2)} C{P(-17, -9)} {P(-11, -13)} {P(-6, -10)} C{P(-3, -14)} {P(3, -14)} {P(6, -10)} C{P(11, -13)} {P(17, -9)} {P(17.5, -2)} C{P(19, -14)} {P(10, -19)} {P(0, -19)} C{P(-10, -19)} {P(-19, -14)} {P(-17.5, -2)}z" fill="{color}"/>'
        front += f'<path d="M{P(-17.5, -2)} C{P(-17, -9)} {P(-11, -13)} {P(-6, -10)} C{P(-3, -14)} {P(3, -14)} {P(6, -10)} C{P(11, -13)} {P(17, -9)} {P(17.5, -2)}" fill="none" stroke="{LINE}" stroke-width="{lw*0.8}" stroke-linecap="round"/>' + shine
    else:
        fringe_flat = f'<path d="{cap} L{P(17.5, 2)} C{P(16.5, -5)} {P(11, -8.5)} {P(4, -8)} L{P(2.5, -11)} L{P(1, -8)} C{P(-7, -8.5)} {P(-15, -6)} {P(-17.5, 2)}z" {st}/>' + shine
        fringe_side = f'<path d="{cap} L{P(17.5, 3)} C{P(17, -4)} {P(13, -10)} {P(6, -12)} C{P(1, -5)} {P(-9, -2)} {P(-17.5, 2)}z" {st}/>' + shine
        if style == "bob":
            back = f'<path d="M{P(-21.5, -2)} C{P(-24, -26)} {P(24, -26)} {P(21.5, -2)} L{P(22, 11)} Q{P(21, 18)} {P(14, 17)} L{P(-14, 17)} Q{P(-21, 18)} {P(-22, 11)}z" {st}/>'
            front = fringe_flat
        elif style == "ponytail":
            back = f'<path d="M{P(15, -12)} C{P(30, -14)} {P(32, 4)} {P(26, 20)} C{P(22, 14)} {P(21, 6)} {P(17, 0)}z" {st}/>'
            back += f'<path d="M{P(23, -6)} Q{P(27, 2)} {P(25, 12)}" fill="none" stroke="{hi}" stroke-width="{2*k}" stroke-linecap="round" opacity="0.7"/>'
            front = fringe_flat + f'<circle cx="{cx + 17.5*k}" cy="{cy - 9*k}" r="{2.6*k}" fill="#ff5cb8" stroke="{LINE}" stroke-width="1.2"/>'
        elif style == "bun":
            back = f'<circle cx="{cx}" cy="{cy - 21*k}" r="{7.5*k}" {st}/><path d="M{P(-4, -24)} Q{P(0, -27)} {P(4, -25)}" fill="none" stroke="{hi}" stroke-width="{1.8*k}" stroke-linecap="round" opacity="0.7"/>'
            front = f'<path d="{cap} L{P(17.5, 2)} C{P(15, -7)} {P(7, -12)} {P(0, -13)} C{P(-7, -12)} {P(-15, -7)} {P(-17.5, 2)}z" {st}/>' + shine
        elif style == "long":
            back = (f'<path d="M{P(-21.5, -2)} C{P(-24, -27)} {P(24, -27)} {P(21.5, -2)} C{P(24, 12)} {P(25, 28)} {P(21, 44)} C{P(17, 47)} {P(13, 44)} {P(13, 38)} L{P(-13, 38)} '
                    f'C{P(-13, 44)} {P(-17, 47)} {P(-21, 44)} C{P(-25, 28)} {P(-24, 12)} {P(-21.5, -2)}z" {st}/>')
            back += f'<path d="M{P(-19.5, 8)} C{P(-21.5, 20)} {P(-21, 30)} {P(-19, 39)} M{P(19.5, 8)} C{P(21.5, 20)} {P(21, 30)} {P(19, 39)}" fill="none" stroke="{hi}" stroke-width="{2*k}" stroke-linecap="round" opacity="0.6"/>'
            front = fringe_side
        elif style == "wavy":
            back = (f'<path d="M{P(-21.5, -2)} C{P(-24, -27)} {P(24, -27)} {P(21.5, -2)} C{P(27, 8)} {P(20, 16)} {P(25, 26)} C{P(27, 36)} {P(19, 42)} {P(14, 37)} L{P(-14, 37)} '
                    f'C{P(-19, 42)} {P(-27, 36)} {P(-25, 26)} C{P(-20, 16)} {P(-27, 8)} {P(-21.5, -2)}z" {st}/>')
            back += f'<path d="M{P(-21, 10)} C{P(-18, 18)} {P(-24, 24)} {P(-21, 32)} M{P(21, 10)} C{P(18, 18)} {P(24, 24)} {P(21, 32)}" fill="none" stroke="{hi}" stroke-width="{2*k}" stroke-linecap="round" opacity="0.6"/>'
            front = fringe_side
    return back, front


def chibi(skin="#ffdcc0", hair_style="short", hair_color="#3b2a2a", top="#5aa9e6", bottom="#3d4a6b", outfit="tshirt",
          accent="#ffffff", shoes="#f4f0e6", mustache=False, glasses=False, hat=None, apron=None, mouth="smile", eyes="dot", lashes=False,
          flush=False, extra=None):
    """Nhân vật chibi 64x88: đầu to tròn, thân quả lê nhỏ, viền nâu ấm."""
    cx, cy = 32, 26
    dress = outfit == "dress"
    s = '<ellipse cx="32" cy="75.5" rx="16" ry="3.8" fill="#2a1a2a" opacity="0.25"/>'
    back, front = hair(hair_style, cx, cy, hair_color)
    s += back
    leg = skin if dress else bottom
    for x in (25.2, 32.8):
        s += f'<rect x="{x}" y="60" width="6" height="12.5" rx="2.8" fill="{leg}" stroke="{LINE}" stroke-width="{LW}"/>'
        s += f'<path d="M{x - 1.2} 74.6 q0 -4.4 4.2 -4.4 q4.2 0 4.2 4.4 q0 1.4 -1.4 1.4 h-5.6 q-1.4 0 -1.4 -1.4z" fill="{shoes}" stroke="{LINE}" stroke-width="{LW*0.85}"/>'
    arm_fill = skin if outfit == "tank" else (accent if outfit == "jacket" else top)
    for sx in (-1, 1):
        x = 32 + sx * 13.4
        s += f'<path d="M{x - sx*1.5} 46.5 q{sx*6} 1 {sx*5} 11 q{-sx*0.5} 3 {-sx*3.4} 3 q{-sx*3} 0 {-sx*3.2} -3z" fill="{arm_fill}" stroke="{LINE}" stroke-width="{LW}" stroke-linejoin="round"/>'
        s += f'<circle cx="{x + sx*2.6}" cy="60" r="3" fill="{skin}" stroke="{LINE}" stroke-width="{LW*0.8}"/>'
    if dress:
        body = "M22.5 45.5 Q32 42 41.5 45.5 L47.5 63.5 Q32 69 16.5 63.5z"
        low = "M18.2 58.5 Q32 63.5 45.8 58.5 L47.5 63.5 Q32 69 16.5 63.5z"
    else:
        body = "M21.5 45.5 Q32 42 42.5 45.5 L44.6 61 Q32 66 19.4 61z"
        low = "M20 56.5 Q32 61 44 56.5 L44.6 61 Q32 66 19.4 61z"
    s += f'<path d="{body}" fill="{top}" stroke="{LINE}" stroke-width="{LW}" stroke-linejoin="round"/>'
    s += f'<path d="{low}" fill="{shade(top, 0.78)}" opacity="0.7"/>'
    if outfit == "office":
        s += f'<path d="M27 44.2 L32 50.5 L37 44.2 L34.6 43.4 L32 46 L29.4 43.4z" fill="#fff" stroke="{LINE}" stroke-width="1.1" stroke-linejoin="round"/>'
        s += f'<path d="M32 49 l-2 3 l2 8 l2 -8z" fill="{accent}" stroke="{LINE}" stroke-width="0.9" stroke-linejoin="round"/>'
    elif outfit == "floral":
        for (x, y) in ((25, 49.5), (38.5, 50.5), (31, 53.5), (36.5, 58), (25.5, 58), (41, 56.5), (22.5, 54)):
            s += f'<circle cx="{x}" cy="{y}" r="1.7" fill="{accent}"/><circle cx="{x}" cy="{y}" r="0.6" fill="#fff"/>'
        s += f'<path d="M28 44 L32 48.5 L36 44" fill="none" stroke="{shade(top, 0.7)}" stroke-width="1.5"/>'
    elif outfit == "stripe":
        for y, x0, x1 in ((48.8, 21.6, 42.4), (53, 21.1, 42.9), (57.2, 20.6, 43.4)):
            s += f'<path d="M{x0} {y} Q32 {y + 1.6} {x1} {y}" fill="none" stroke="{accent}" stroke-width="2.3"/>'
    elif outfit == "polo":
        s += f'<path d="M27 44 L32 49.5 L37 44 L35 43 L32 46.3 L29 43z" fill="{accent}" stroke="{LINE}" stroke-width="1.1" stroke-linejoin="round"/>'
        s += f'<path d="M32 50 v6" stroke="{LINE}" stroke-width="1"/><circle cx="32" cy="52" r="0.8" fill="{LINE}"/><circle cx="32" cy="55" r="0.8" fill="{LINE}"/>'
    elif outfit == "tshirt":
        s += f'<path d="M28 44 Q32 47.5 36 44" fill="none" stroke="{shade(top, 0.7)}" stroke-width="1.6"/>'
        s += f'<path d="M32 51 l1.3 2.6 l2.9 0.4 l-2.1 2 l0.5 2.9 l-2.6 -1.4 l-2.6 1.4 l0.5 -2.9 l-2.1 -2 l2.9 -0.4z" fill="{accent}" opacity="0.9"/>'
    elif outfit == "jacket":
        s += f'<path d="M28 44 Q32 47.5 36 44" fill="none" stroke="{shade(top, 0.7)}" stroke-width="1.6"/>'
        for sx in (-1, 1):
            s += f'<path d="M{32 - sx*10.5} 45.5 Q{32 - sx*7} 43.6 {32 - sx*4.4} 43.3 L{32 - sx*5.6} 63.2 Q{32 - sx*9.6} 62.4 {32 - sx*12.6} 61z" fill="{accent}" stroke="{LINE}" stroke-width="{LW*0.8}" stroke-linejoin="round"/>'
    elif outfit == "tank":
        s += f'<path d="M26.4 43.6 Q32 51.5 37.6 43.6z" fill="{skin}" stroke="{LINE}" stroke-width="1.2" stroke-linejoin="round"/>'
    elif dress:
        s += f'<path d="M27.5 44 Q32 47.5 36.5 44" fill="none" stroke="{accent}" stroke-width="1.8"/>'
        s += f'<path d="M17.5 61.5 Q32 67 46.5 61.5" fill="none" stroke="{accent}" stroke-width="1.6" opacity="0.9"/>'
        s += f'<path d="M30 49.5 q-3.4 -2.4 -3 1.3 q-0.4 3.4 3 1z M34 49.5 q3.4 -2.4 3 1.3 q0.4 3.4 -3 1z" fill="{accent}" stroke="{LINE}" stroke-width="0.8"/><circle cx="32" cy="50.8" r="1.5" fill="{accent}" stroke="{LINE}" stroke-width="0.8"/>'
    if apron:
        s += f'<path d="M27 44.5 L24.5 50 M37 44.5 L39.5 50" stroke="{shade(apron, 0.8)}" stroke-width="2"/>'
        s += f'<path d="M24 49.5 h16 l1.6 12 q-9.6 3.6 -19.2 0z" fill="{apron}" stroke="{LINE}" stroke-width="{LW*0.8}" stroke-linejoin="round"/>'
        s += f'<rect x="27.5" y="54" width="9" height="5.6" rx="1.4" fill="{shade(apron, 1.3)}" stroke="{LINE}" stroke-width="1"/>'
        s += f'<path d="M30.2 56.2 v2 M30.2 56.2 l3 -0.6 v1.9" stroke="#e6398b" stroke-width="0.9" fill="none"/>'
    s += f'<ellipse cx="32" cy="45.4" rx="8.5" ry="2.2" fill="{LINE}" opacity="0.22"/>'
    s += face(cx, cy, skin, mustache=mustache, glasses=glasses, mouth=mouth, eyes=eyes, lashes=lashes)
    if flush:
        s += f'<ellipse cx="32" cy="34" rx="15" ry="5" fill="#ff5a5a" opacity="0.35"/>'
    s += front
    if extra == "headphones":
        s += f'<path d="M12 27 C10 -2 54 -2 52 27" fill="none" stroke="#3a3550" stroke-width="3.4" stroke-linecap="round"/>'
        for sx in (-1, 1):
            s += f'<rect x="{32 + sx*19.5 - 3.5}" y="22" width="7" height="12" rx="3.2" fill="{accent}" stroke="{LINE}" stroke-width="1.4"/>'
    if hat == "party":
        s += f'<path d="M22.5 9.5 L30.5 -7 L40 8z" fill="#ff5cb8" stroke="{LINE}" stroke-width="{LW*0.85}" stroke-linejoin="round"/>'
        s += f'<path d="M26.3 1.8 L36 3 M24.2 6 L38.2 6.5" stroke="#ffd166" stroke-width="2"/><circle cx="30.5" cy="-7" r="2.8" fill="#ffd166" stroke="{LINE}" stroke-width="1.1"/>'
    elif hat == "cap":
        s += f'<path d="M12.5 17 C12 -3 52 -3 51.5 17 Q32 12 12.5 17z" fill="{accent}" stroke="{LINE}" stroke-width="{LW}" stroke-linejoin="round"/>'
        s += f'<path d="M12 16.5 Q32 11.5 52 16.5 Q54 20.5 50 21 Q32 16.5 14 21 Q10 20.5 12 16.5z" fill="{shade(accent, 0.8)}" stroke="{LINE}" stroke-width="{LW*0.85}" stroke-linejoin="round"/>'
        s += f'<path d="M22 4 Q30 0 40 3" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" opacity="0.55"/>'
        s += f'<path d="M30 6.5 v4.4 M30 6.5 l5 -1 v4.4" stroke="#fff" stroke-width="1.4" fill="none"/><circle cx="29" cy="11" r="1.5" fill="#fff"/><circle cx="34" cy="10" r="1.5" fill="#fff"/>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="176" viewBox="0 -8 64 88">{s}</svg>\n'


def hostess(skin="#ffdcc0", hair_color="#2b1d2e", dress="#e6398b", shoes="#2b1d2e", style="strapless", hair_style="long", lips="#e0405a", accent="#ffd166", shadow="#c98bd6", sleeve=None):
    """Nhân viên Lan can: dáng người lớn (cao 100), trang phục dạ tiệc."""
    cx, cy, k = 32, 19, 0.7
    L = LINE
    arm = sleeve or skin
    s = '<ellipse cx="32" cy="96" rx="14" ry="3.2" fill="#2a1a2a" opacity="0.25"/>'
    back, front = hair(hair_style, cx, cy, hair_color, k)
    s += back
    for x, d in ((27.6, -1), (36.4, 1)):
        s += f'<path d="M{x - 2.9} 62 h5.8 q0.4 14 -0.9 28 h-3.6 q-1.5 -14 -1.3 -28z" fill="{skin}" stroke="{L}" stroke-width="1.6" stroke-linejoin="round"/>'
        s += f'<path d="M{x - 2.2} 66 q-0.3 10 0.6 20" fill="none" stroke="#fff" stroke-width="1.1" stroke-linecap="round" opacity="0.5"/>'
        s += f'<path d="M{x - 2.6} 89.5 h5 q{2.6*d + 1.2} 2.6 {3.4*d + 1.6} 5.6 h{-7.4 if d > 0 else -5.6} q-0.8 -3 -1 -5.6z" fill="{shoes}" stroke="{L}" stroke-width="1.2" stroke-linejoin="round"/>'
    s += f'<rect x="29.4" y="29" width="5.2" height="7" fill="{skin}" stroke="{L}" stroke-width="1.4"/>'
    s += f'<path d="M20.6 38.6 q11.4 -5.2 22.8 0 l0.8 8 h-24.4z" fill="{skin}" stroke="{L}" stroke-width="1.6" stroke-linejoin="round"/>'
    s += f'<path d="M21 39.4 q-4 10 -2.6 21.6 q1.9 2.2 3.8 0 q-0.2 -9.6 1.9 -17.6z" fill="{arm}" stroke="{L}" stroke-width="1.5" stroke-linejoin="round"/>'
    s += f'<path d="M43 39.4 q5.2 5.8 6.2 13 q-3.2 6 -8.4 6.2 q-1.6 -2.1 0 -3.2 q3.2 -1 4.2 -3.2 q-2 -4 -4.2 -7z" fill="{arm}" stroke="{L}" stroke-width="1.5" stroke-linejoin="round"/>'
    dark = shade(dress, 0.72)
    light = shade(dress, 1.35)
    if style == "strapless":
        path = "M23.4 43 q8.6 4.2 17.2 0 q1 8 -1.6 12.2 q3.2 6 3.7 13.2 q-10.7 3.7 -21.4 0 q0.5 -7.2 3.7 -13.2 q-2.6 -4.2 -1.6 -12.2z"
    elif style == "halter":
        path = "M30 32.6 l-6.6 11.4 q-1 7 1.6 11.2 q-3.2 6 -3.7 13.2 q10.7 3.7 21.4 0 q-0.5 -7.2 -3.7 -13.2 q2.6 -4.2 1.6 -11.2 l-6.6 -11.4 l-2 6.2z"
    elif style == "aodai":
        # Áo dài cách tân: cổ cao, tà dài xẻ hai bên, quần lụa trắng.
        s += f'<path d="M24.2 60 h15.6 l1.8 31 h-7.2 l-2.4 -22 l-2.4 22 h-7.2z" fill="#fff8f0" stroke="{L}" stroke-width="1.5" stroke-linejoin="round"/>'
        path = "M27.8 31.4 h8.4 l1.4 4.2 q5.8 1.6 5.8 4.6 l-2.8 5.2 q0.6 6 -1.4 9.8 q4.6 12 5 26 l-7 1.6 q-2.4 -13 -5.2 -20 q-2.8 7 -5.2 20 l-7 -1.6 q0.4 -14 5 -26 q-2 -3.8 -1.4 -9.8 l-2.8 -5.2 q0 -3 5.8 -4.6z"
    elif style == "croptop":
        s += f'<path d="M23.6 44 q-1.2 7 1.4 11 q-2 4 -2.8 8 h19.6 q-0.8 -4 -2.8 -8 q2.6 -4 1.4 -11z" fill="{skin}" stroke="{L}" stroke-width="1.5" stroke-linejoin="round"/>'
        s += f'<path d="M23.3 42.6 q8.7 4.2 17.4 0 q0.9 4.6 0.2 8.4 q-8.9 2.6 -17.8 0 q-0.7 -3.8 0.2 -8.4z" fill="{dress}" stroke="{L}" stroke-width="1.6" stroke-linejoin="round"/>'
        path = "M24.2 57.5 q7.8 2 15.6 0 q2.6 5 3 11 q-10.8 3.7 -21.6 0 q0.4 -6 3 -11z"
    elif style == "gown":
        path = "M23.4 43 q8.6 4.2 17.2 0 q1 8 -1.6 12.2 q4.4 14 5.4 33 q-4 2 -8 1.6 l-3 -24 q-2 12 -1.4 24.6 q-6 0.4 -11.4 -1.8 q0.6 -18 5 -33.4 q-2.6 -4.2 -1.6 -12.2z"
    elif style == "jacket":
        path = "M23.4 43 q8.6 4.2 17.2 0 q1 8 -1.6 12.2 q3.2 6 3.7 13.2 q-10.7 3.7 -21.4 0 q0.5 -7.2 3.7 -13.2 q-2.6 -4.2 -1.6 -12.2z"
    else:
        s += f'<path d="M25 37.8 v6.4 M39 37.8 v6.4" stroke="{dress}" stroke-width="2"/>'
        path = "M23.4 43 q8.6 4.2 17.2 0 q1 8 -1.6 12.2 q3.2 8.2 4.2 18.4 l-7.2 1 l-2.1 -12.4 l-1 13.4 q-7.2 0 -11.8 -2.1 q1 -10.2 4.2 -18.4 q-2.6 -4.2 -1.6 -12.2z"
    s += f'<path d="{path}" fill="{dress}" stroke="{L}" stroke-width="1.7" stroke-linejoin="round"/>'
    s += f'<path d="M24.6 56.4 q-2.2 5.4 -2.6 11.4 q4.6 1.7 8 1.9 q-4.4 -5.6 -5.4 -13.3z" fill="{dark}" opacity="0.6"/>'
    s += f'<path d="M36.4 47.6 q1.6 3.4 0.4 6.6 M37.6 58.4 q2 4 2.6 8" fill="none" stroke="{light}" stroke-width="1.5" stroke-linecap="round" opacity="0.85"/>'
    if style != "croptop":
        s += f'<path d="M24.8 55 q7.2 2.6 14.4 0" fill="none" stroke="{dark}" stroke-width="1.1"/>'
    if style == "aodai":
        s += f'<path d="M30.4 33.4 q5 3.6 10.6 9.6" fill="none" stroke="{light}" stroke-width="1.2"/>'
        for (x, y) in ((33, 35.4), (36.2, 38.2), (39, 41)):
            s += f'<circle cx="{x}" cy="{y}" r="0.9" fill="{accent}"/>'
    if style == "jacket":
        for sx in (-1, 1):
            s += f'<path d="M{32 - sx*11.4} 38.6 q{sx*3} -1.6 {sx*6.4} -1.8 l{-sx*1.2} 10 l{sx*1.4} 9.6 h{-sx*5.4} q{sx*0.4} -5 {-sx*1.6} -9z" fill="{sleeve}" stroke="{L}" stroke-width="1.4" stroke-linejoin="round"/>'
    for (x, y) in ((27.5, 49), (33, 62), (29, 65), (37.5, 51.5)):
        s += f'<path d="M{x} {y - 1.5} l0.5 1 l1 0.5 l-1 0.5 l-0.5 1 l-0.5 -1 l-1 -0.5 l1 -0.5z" fill="#fff" opacity="0.9"/>'
    if style != "aodai":
        s += f'<path d="M27.6 35.2 q4.4 3.9 8.8 0" fill="none" stroke="{accent}" stroke-width="1.1"/><circle cx="32" cy="37.6" r="1.5" fill="{accent}" stroke="{L}" stroke-width="0.6"/>'
    s += f'<rect x="38.8" y="50" width="2.8" height="8.4" rx="1.2" fill="#55505f" stroke="{L}" stroke-width="0.8" transform="rotate(-25 40 54)"/><circle cx="37.3" cy="49.1" r="2.9" fill="#d5d5e2" stroke="{L}" stroke-width="1"/>'
    s += face(cx, cy, skin, k, lashes=True, lips=lips, shadow=shadow, brows=True)
    s += front
    for sx in (-1, 1):
        s += f'<circle cx="{cx + sx*13.2}" cy="26.5" r="1.7" fill="{accent}" stroke="{L}" stroke-width="0.6"/>'
    return svg(64, 100, s)


def host_male(skin="#ffdcc0", hair_color="#2e2226", suit="#3a3560", shirt="#ffffff", accent="#f0559c", hair_style="short"):
    """Nam ca sĩ phòng trà của Lan can: vest, nơ, micro."""
    cx, cy, k = 32, 19, 0.72
    L = LINE
    s = '<ellipse cx="32" cy="96" rx="14" ry="3.2" fill="#2a1a2a" opacity="0.25"/>'
    back, front = hair(hair_style, cx, cy, hair_color, k)
    s += back
    for x in (25.6, 32.6):
        s += f'<rect x="{x}" y="60" width="5.8" height="31" rx="2.2" fill="{shade(suit, 0.82)}" stroke="{L}" stroke-width="1.6"/>'
        s += f'<path d="M{x - 1} 94.6 q0 -4.2 3.9 -4.2 q4.6 0 4.6 4.2 q0 1 -1 1 h-6.5 q-1 0 -1 -1z" fill="#2e2226" stroke="{L}" stroke-width="1.2"/>'
    s += f'<rect x="29.2" y="29" width="5.6" height="7" fill="{skin}" stroke="{L}" stroke-width="1.4"/>'
    s += f'<path d="M20.4 39.6 q-4 10 -2.8 21 q2.2 2.2 4.4 0 q0 -9 1.8 -16z" fill="{suit}" stroke="{L}" stroke-width="1.5" stroke-linejoin="round"/>'
    s += f'<circle cx="19.8" cy="61.6" r="2.6" fill="{skin}" stroke="{L}" stroke-width="1.2"/>'
    s += f'<path d="M43.4 39.6 q5.6 5.8 6.4 13 q-3.2 5.4 -8.6 5.6 q-1.8 -2.2 0 -3.6 q3 -0.6 4 -2.6 q-2 -3.8 -4.2 -6.6z" fill="{suit}" stroke="{L}" stroke-width="1.5" stroke-linejoin="round"/>'
    s += f'<path d="M20.4 38.6 q11.6 -5.4 23.2 0 l1.2 24.4 q-12.8 3.6 -25.6 0z" fill="{suit}" stroke="{L}" stroke-width="1.7" stroke-linejoin="round"/>'
    s += f'<path d="M20 57 q12 3.4 24 0 l0.8 6 q-12.8 3.6 -25.6 0z" fill="{shade(suit, 0.75)}" opacity="0.7"/>'
    s += f'<path d="M27.2 36.4 L32 52 L36.8 36.4z" fill="{shirt}" stroke="{L}" stroke-width="1.2" stroke-linejoin="round"/>'
    s += f'<path d="M27.2 36.4 L32 52 M36.8 36.4 L32 52" stroke="{shade(suit, 1.4)}" stroke-width="2.4" stroke-linecap="round"/>'
    s += f'<path d="M32 38.6 l-3.6 -1.8 v3.8z M32 38.6 l3.6 -1.8 v3.8z" fill="{accent}" stroke="{L}" stroke-width="0.8" stroke-linejoin="round"/>'
    s += f'<circle cx="32" cy="55.5" r="0.9" fill="{accent}"/><circle cx="32" cy="59" r="0.9" fill="{accent}"/>'
    s += f'<path d="M23.2 45 l3.6 0.6" stroke="{accent}" stroke-width="1.6" stroke-linecap="round"/>'
    s += f'<rect x="39" y="49.6" width="2.8" height="8.4" rx="1.2" fill="#55505f" stroke="{L}" stroke-width="0.8" transform="rotate(-25 40 54)"/><circle cx="37.5" cy="48.7" r="2.9" fill="#d5d5e2" stroke="{L}" stroke-width="1"/>'
    s += f'<circle cx="41.4" cy="56.6" r="2.6" fill="{skin}" stroke="{L}" stroke-width="1.2"/>'
    s += face(cx, cy, skin, k, eyes="happy")
    s += front
    return svg(64, 100, s)


def props():
    L = LINE
    write("sofa", svg(120, 44,
        f'<rect x="2" y="4" width="116" height="24" rx="9" fill="#8a3f9e" stroke="{L}" stroke-width="2"/>'
        f'<rect x="8" y="18" width="104" height="20" rx="7" fill="#b061c9" stroke="{L}" stroke-width="2"/>'
        f'<path d="M42 19 v18 M78 19 v18" stroke="{L}" stroke-width="1.4" opacity="0.5"/>'
        f'<rect x="1" y="14" width="13" height="26" rx="6" fill="#8a3f9e" stroke="{L}" stroke-width="2"/><rect x="106" y="14" width="13" height="26" rx="6" fill="#8a3f9e" stroke="{L}" stroke-width="2"/>'))
    write("tv", svg(96, 50,
        f'<rect x="2" y="2" width="92" height="40" rx="4" fill="#1b1b2a" stroke="{L}" stroke-width="2"/>'
        f'<rect x="6" y="6" width="84" height="32" rx="2" fill="#2d2470"/>'
        f'<path d="M6 30 q20 -14 42 -4 t42 -6 v18 h-84z" fill="#5a2d91"/>'
        f'<rect x="14" y="28" width="46" height="4" rx="2" fill="#ffd166"/><rect x="60" y="28" width="22" height="4" rx="2" fill="#fff" opacity="0.7"/>'
        f'<path d="M20 12 v9 M20 12 l7 -2 v9" stroke="#ff7ac8" stroke-width="2" fill="none"/><circle cx="18" cy="21" r="2.5" fill="#ff7ac8"/><circle cx="25" cy="19" r="2.5" fill="#ff7ac8"/>'
        f'<rect x="38" y="42" width="20" height="6" fill="#444" stroke="{L}" stroke-width="1.5"/>'))
    write("table", svg(80, 44,
        f'<ellipse cx="40" cy="38" rx="34" ry="5" fill="#000" opacity="0.2"/>'
        f'<rect x="4" y="12" width="72" height="22" rx="8" fill="#6b4a3a" stroke="{L}" stroke-width="2"/><rect x="8" y="14" width="64" height="10" rx="5" fill="#8a6350"/>'
        f'<ellipse cx="40" cy="15" rx="15" ry="6" fill="#f4f0e6" stroke="{L}" stroke-width="1.4"/>'
        f'<path d="M30 14 q4 -9 9 0z" fill="#ff5c6c" stroke="{L}" stroke-width="1"/><path d="M31.5 13.5 q2.5 -5 6 0z" fill="#ffb3b9"/>'
        f'<circle cx="44" cy="12" r="3.6" fill="#ffb347" stroke="{L}" stroke-width="1"/><circle cx="49" cy="14" r="2.8" fill="#9ad65a" stroke="{L}" stroke-width="1"/><circle cx="40" cy="16" r="2.4" fill="#8e5bd1" stroke="{L}" stroke-width="1"/>'
        f'<rect x="12" y="15" width="3.4" height="9" rx="1.5" fill="#555" transform="rotate(-50 14 20)"/><circle cx="18.5" cy="16.5" r="3" fill="#c9c9d6" stroke="{L}" stroke-width="1"/>'
        f'<rect x="62" y="9" width="6" height="11" rx="2" fill="#7fd0ff" stroke="{L}" stroke-width="1"/><rect x="63" y="7" width="4" height="3" fill="#fff" stroke="{L}" stroke-width="0.8"/>'))
    write("desk", svg(150, 70,
        f'<ellipse cx="75" cy="64" rx="70" ry="5" fill="#000" opacity="0.2"/>'
        f'<rect x="4" y="20" width="142" height="42" rx="6" fill="#7a3fa0" stroke="{L}" stroke-width="2"/>'
        f'<rect x="2" y="14" width="146" height="12" rx="5" fill="#ffd166" stroke="{L}" stroke-width="2"/>'
        f'<rect x="12" y="32" width="126" height="22" rx="4" fill="#5d2c7d"/>'
        f'<rect x="100" y="0" width="24" height="16" rx="2" fill="#1b1b2a" stroke="{L}" stroke-width="1.6"/><rect x="103" y="3" width="18" height="10" fill="#7fd0ff"/>'
        f'<rect x="22" y="4" width="14" height="11" rx="2" fill="#ff5c6c" stroke="{L}" stroke-width="1.4"/><circle cx="29" cy="3" r="3" fill="#ffd166" stroke="{L}" stroke-width="1"/>'
        f'<rect x="48" y="7" width="22" height="8" rx="1" fill="#fff" stroke="{L}" stroke-width="1"/><path d="M51 10 h16 M51 12.5 h10" stroke="{L}" stroke-width="0.8"/>'))
    write("motorbike", svg(84, 52,
        f'<ellipse cx="42" cy="47" rx="34" ry="4" fill="#000" opacity="0.2"/>'
        f'<circle cx="16" cy="38" r="9.5" fill="#2a2a33" stroke="{L}" stroke-width="2"/><circle cx="16" cy="38" r="4" fill="#bbb"/>'
        f'<circle cx="68" cy="38" r="9.5" fill="#2a2a33" stroke="{L}" stroke-width="2"/><circle cx="68" cy="38" r="4" fill="#bbb"/>'
        f'<path d="M12 30 q4 -10 18 -8 l6 6 h16 l4 -12 l6 -1 l6 20 q-4 4 -10 3 l-6 2 h-24 q-10 0 -22 -10z" fill="BODY" stroke="{L}" stroke-width="2" stroke-linejoin="round"/>'
        f'<rect x="20" y="16" width="26" height="7" rx="3.5" fill="#33303d" stroke="{L}" stroke-width="1.6"/>'
        f'<path d="M57 14 l-5 -6 M57 14 l7 -3" stroke="{L}" stroke-width="2.4" stroke-linecap="round"/><circle cx="66" cy="19" r="3" fill="#fff7c2" stroke="{L}" stroke-width="1.2"/>'))
    write("plant", svg(40, 60,
        f'<ellipse cx="20" cy="56" rx="13" ry="3" fill="#000" opacity="0.2"/>'
        f'<path d="M20 38 q-18 -8 -14 -26 q12 6 14 26z M20 38 q18 -8 14 -26 q-12 6 -14 26z M20 38 q-6 -22 0 -36 q6 14 0 36z" fill="#4fae6a" stroke="{L}" stroke-width="1.6" stroke-linejoin="round"/>'
        f'<path d="M9 38 h22 l-3 17 h-16z" fill="#c9764a" stroke="{L}" stroke-width="1.8" stroke-linejoin="round"/><rect x="7" y="36" width="26" height="6" rx="2" fill="#de8a5c" stroke="{L}" stroke-width="1.6"/>'))
    write("broom", svg(28, 40,
        f'<path d="M20 3 L9 26" stroke="#b9834f" stroke-width="3" stroke-linecap="round"/><path d="M3 27 l12 5 l-3 7 q-8 0 -11 -6z" fill="#ffd166" stroke="{L}" stroke-width="1.5" stroke-linejoin="round"/>'))
    write("note", svg(20, 24,
        f'<path d="M8 4 v13 M8 4 l9 -2 v12" stroke="#ff7ac8" stroke-width="2.4" fill="none" stroke-linejoin="round"/><ellipse cx="5.5" cy="18" rx="3.8" ry="3" fill="#ff7ac8"/><ellipse cx="14.5" cy="15" rx="3.8" ry="3" fill="#ff7ac8"/>'))


def main():
    os.makedirs(OUT, exist_ok=True)
    chars = {
        "owner": dict(hair_style="short", hair_color="#3a2622", top="#fff6e6", bottom="#4a4460", apron="#ffb347", hat="cap", accent="#f0559c", shoes="#e6554d", eyes="happy"),
        "friend_m": dict(hair_style="spiky", hair_color="#3a2622", top="#5aa9e6", bottom="#4a5578", outfit="stripe", accent="#ffffff", mouth="open", shoes="#ffffff"),
        "friend_f": dict(hair_style="bob", hair_color="#8a4a2a", top="#ffd166", bottom="#7a5aa6", outfit="tshirt", accent="#ff7ac8", lashes=True, mouth="open", shoes="#ff8fc7"),
        "birthday_f": dict(hair_style="ponytail", hair_color="#3a2622", top="#ff9ccd", outfit="dress", accent="#ffffff", hat="party", lashes=True, eyes="happy", mouth="open", shoes="#ffffff"),
        "birthday_m": dict(hair_style="short", hair_color="#5a3320", top="#7ed6a5", bottom="#4a5578", outfit="polo", accent="#ffffff", hat="party", mouth="open", shoes="#ffd166"),
        "office_m": dict(hair_style="short", hair_color="#2e2226", top="#f6f8ff", bottom="#39405e", outfit="office", accent="#e6554d", glasses=True, shoes="#3a2622"),
        "office_f": dict(hair_style="long", hair_color="#3a2622", top="#f6f8ff", bottom="#39405e", outfit="office", accent="#5aa9e6", lashes=True, shoes="#3a2622"),
        "uncle": dict(skin="#f4c9a0", hair_style="bald", hair_color="#9a949c", top="#d9c48a", bottom="#6b6252", outfit="polo", accent="#a8905a", mustache=True, eyes="happy", shoes="#8a6a4a"),
        "auntie": dict(skin="#fad3b4", hair_style="curly", hair_color="#5a4a52", top="#b06ad0", bottom="#4a4460", outfit="floral", accent="#ffd166", lashes=True, shoes="#e6554d"),
        "waiter": dict(hair_style="short", hair_color="#3a2622", top="#4a4460", bottom="#33304a", outfit="office", accent="#ffd166", shoes="#2e2226"),
    }
    for name, kw in chars.items():
        write(name, chibi(**kw))
    write("lancan_1", hostess(dress="#f0559c", style="strapless", hair_style="long", hair_color="#2e2226", shadow="#f0a0c8"))
    write("lancan_2", hostess(dress="#8a4ff0", style="slit", hair_style="wavy", hair_color="#8a4a2a", skin="#fad3b4", lips="#d0407a", shadow="#b79af0"))
    write("lancan_3", hostess(dress="#2a2438", style="halter", hair_style="bob", hair_color="#2e2226", lips="#e0405a", accent="#ff7ac8", shoes="#e6554d", shadow="#8a8aa8"))
    write("lancan_4", hostess(dress="#d83a3a", style="aodai", sleeve="#d83a3a", hair_style="bun", hair_color="#2e2226", lips="#c8323c", accent="#ffd166", shoes="#d83a3a", shadow="#f0b0a0"))
    write("lancan_5", hostess(dress="#3ad0c0", style="croptop", hair_style="ponytail", hair_color="#e8c26a", skin="#fad3b4", lips="#f0559c", accent="#ffffff", shoes="#ffffff", shadow="#9ae0d8"))
    write("lancan_6", hostess(dress="#1f6fd0", style="gown", hair_style="wavy", hair_color="#2e2226", lips="#d0407a", accent="#ffffff", shoes="#c9c9d6", shadow="#9ab8f0"))
    write("lancan_7", hostess(dress="#f4f0e6", style="jacket", sleeve="#3a3550", hair_style="bob", hair_color="#c8506e", lips="#b03060", accent="#ffd166", shoes="#3a3550", shadow="#b0a0c0"))
    write("lancan_8", host_male(suit="#3a3560", accent="#f0559c", hair_color="#2e2226"))

    more = {
        "student_m": dict(hair_style="spiky", hair_color="#2e2226", top="#ffffff", bottom="#39405e", outfit="jacket", accent="#3d6fd0", shoes="#ffffff", glasses=True),
        "student_f": dict(hair_style="ponytail", hair_color="#3a2622", top="#ffffff", bottom="#39405e", outfit="jacket", accent="#e6554d", lashes=True, mouth="open", shoes="#ffffff"),
        "drunk_uncle": dict(skin="#f4c9a0", hair_style="short", hair_color="#4a4046", top="#f6f8ff", bottom="#5a5a66", outfit="tank", mustache=True, eyes="happy", flush=True, shoes="#3d6fd0"),
        "beer_uncle": dict(skin="#f0bf94", hair_style="bald", hair_color="#3a2622", top="#e6554d", bottom="#4a4460", outfit="polo", accent="#ffd166", mouth="open", flush=True, shoes="#8a6a4a"),
        "auntie_2": dict(skin="#fad3b4", hair_style="bob", hair_color="#3a2622", top="#f0559c", bottom="#f0559c", outfit="floral", accent="#ffffff", lashes=True, mouth="open", shoes="#ffd166"),
        "auntie_3": dict(hair_style="curly", hair_color="#7a3a2a", top="#3ab8a0", bottom="#3ab8a0", outfit="floral", accent="#ffd166", lashes=True, eyes="happy", shoes="#ffffff"),
        "couple_m": dict(hair_style="short", hair_color="#5a3320", top="#f4f0e6", bottom="#39405e", outfit="jacket", accent="#8a6a4a", shoes="#ffffff"),
        "couple_f": dict(hair_style="long", hair_color="#8a4a2a", top="#ffb3c8", outfit="dress", accent="#ffffff", lashes=True, eyes="happy", shoes="#e6554d"),
        "grandpa": dict(skin="#f4c9a0", hair_style="bald", hair_color="#f0f0f0", top="#b8c8d8", bottom="#6b6252", outfit="polo", accent="#8a9ab0", glasses=True, shoes="#8a6a4a"),
        "grandma": dict(skin="#fad3b4", hair_style="bun", hair_color="#e8e4ea", top="#8a5a9a", bottom="#3a3550", outfit="floral", accent="#f0d0ff", eyes="happy", shoes="#3a3550"),
        "genz_f": dict(hair_style="bob", hair_color="#ff8fc7", top="#2a2438", bottom="#c8f060", outfit="tshirt", accent="#c8f060", lashes=True, mouth="open", shoes="#ffffff", extra="headphones"),
        "genz_m": dict(hair_style="spiky", hair_color="#e8d27a", top="#c8f060", bottom="#2a2438", outfit="jacket", accent="#2a2438", mouth="open", shoes="#ff8fc7"),
    }
    more["guard"] = dict(skin="#f0bf94", hair_style="short", hair_color="#4a4046", top="#4a78c8", bottom="#2e3a5e", outfit="office", accent="#ffd166", hat="cap", shoes="#2e2226", mustache=True)
    for name, kw in more.items():
        write(name, chibi(**kw))
    props()
    with open(os.path.join(OUT, "motorbike.svg")) as f:
        bike = f.read()
    for i, color in enumerate(["#e6554d", "#4d8fe6", "#f4f0e6", "#57b98a"]):
        write(f"motorbike_{i}", bike.replace("BODY", color))
    os.remove(os.path.join(OUT, "motorbike.svg"))


if __name__ == "__main__":
    main()
