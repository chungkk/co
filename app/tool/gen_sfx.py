#!/usr/bin/env python3
"""Sinh âm thanh quân cờ gỗ bằng tổng hợp modal (không cần thư viện ngoài).

Chạy trong thư mục app/:  python3 tool/gen_sfx.py
Kết quả ghi vào assets/sfx/*.wav (mono, 44.1kHz, 16-bit).

- move1..3   : quân gỗ đặt xuống bàn ("cộp"), 3 biến thể chọn ngẫu nhiên khi chơi
- capture1..2: hai quân va nhau ("cắc") rồi đặt mạnh xuống bàn, kèm tiếng lạch cạch
- select     : nhấc quân (tick nhẹ)
- check, win, end, fail: chuông/nhạc ngắn
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / 'assets' / 'sfx'


def zeros(sec):
    return [0.0] * int(SR * sec)


def add(dst, src, at=0.0, gain=1.0):
    o = int(SR * at)
    need = o + len(src)
    if need > len(dst):
        dst.extend([0.0] * (need - len(dst)))
    for i, x in enumerate(src):
        dst[o + i] += x * gain
    return dst


def modes(spec, dur, rnd):
    """spec: [(tần số Hz, biên độ, hệ số tắt dần 1/s)], pha ngẫu nhiên, tấn công rất nhanh."""
    n = int(SR * dur)
    out = [0.0] * n
    for f, a, d in spec:
        ph = rnd.uniform(0, 2 * math.pi)
        w = 2 * math.pi * f / SR
        for i in range(n):
            t = i / SR
            out[i] += a * math.exp(-d * t) * math.sin(w * i + ph)
    for i in range(min(n, 40)):  # chống "bụp" đầu tiếng
        out[i] *= i / 40
    return out


def click(dur, rnd, bright=0.6, decay=900.0):
    """Tiếng chạm khô: nhiễu trắng tắt rất nhanh, lọc thông cao đơn giản."""
    n = int(SR * dur)
    out, prev = [], 0.0
    for i in range(n):
        x = rnd.uniform(-1, 1) * math.exp(-decay * i / SR)
        y = x - bright * prev  # high-pass/pre-emphasis 1 cực
        prev = x
        out.append(y)
    return out


def lowpass(sig, a):
    out, y = [], 0.0
    for x in sig:
        y += a * (x - y)
        out.append(y)
    return out


def jitter(spec, rnd, amt=0.04):
    return [(f * (1 + rnd.uniform(-amt, amt)), a, d * (1 + rnd.uniform(-0.15, 0.15))) for f, a, d in spec]


# Cộng hưởng của quân cờ gỗ (không điều hòa) và của mặt bàn
PIECE = [(1180, 1.0, 70), (1975, 0.55, 95), (3060, 0.32, 140), (4420, 0.18, 210), (6150, 0.08, 320)]
BOARD = [(165, 0.9, 30), (240, 0.55, 38), (410, 0.3, 55)]
CLACK = [(2350, 1.0, 120), (3780, 0.6, 170), (5400, 0.35, 240), (7300, 0.15, 330)]


def place(rnd, force=1.0):
    s = zeros(0.0)
    add(s, click(0.012, rnd, 0.7, 700), 0, 0.55 * force)
    add(s, modes(jitter(PIECE, rnd), 0.16, rnd), 0.0005, 0.45 * force)
    add(s, lowpass(modes(jitter(BOARD, rnd, 0.03), 0.22, rnd), 0.35), 0.001, 0.9 * force)
    return s


def move(seed):
    rnd = random.Random(seed)
    return place(rnd, 1.0)


def capture(seed):
    rnd = random.Random(seed)
    s = zeros(0.0)
    # 1) hai quân va nhau: sắc, cao
    add(s, click(0.008, rnd, 0.85, 1400), 0, 0.8)
    add(s, modes(jitter(CLACK, rnd), 0.09, rnd), 0.0003, 0.7)
    # 2) quân đặt mạnh xuống bàn
    add(s, place(rnd, 1.25), 0.055)
    # 3) quân bị ăn lạch cạch nhẹ
    add(s, modes(jitter([(2900, 1.0, 260), (4600, 0.5, 380)], rnd), 0.04, rnd), 0.135, 0.18)
    add(s, modes(jitter([(2600, 1.0, 300), (4100, 0.5, 400)], rnd), 0.035, rnd), 0.175, 0.1)
    return s


def select(seed):
    rnd = random.Random(seed)
    s = zeros(0.0)
    add(s, click(0.006, rnd, 0.9, 1800), 0, 0.3)
    add(s, modes(jitter([(2600, 1.0, 260), (4100, 0.4, 380)], rnd), 0.05, rnd), 0, 0.25)
    return s


def tone(f, dur, decay, vol=1.0):
    n = int(SR * dur)
    return [vol * math.exp(-decay * i / SR) * min(1, i / 200) *
            (math.sin(2 * math.pi * f * i / SR) + 0.25 * math.sin(4 * math.pi * f * i / SR) + 0.08 * math.sin(6 * math.pi * f * i / SR))
            for i in range(n)]


def check(seed):
    rnd = random.Random(seed)
    s = place(rnd, 1.1)
    add(s, tone(1318.5, 0.45, 8, 0.35), 0.04)
    add(s, tone(1975.5, 0.35, 10, 0.18), 0.04)
    return s


def seq(notes):
    s = zeros(0)
    for f, dur, decay, vol, at in notes:
        add(s, tone(f, dur, decay, vol), at)
    return s


def write(name, s, peak=0.9):
    m = max(1e-9, max(abs(x) for x in s))
    tail = int(SR * 0.01)  # fade out cuối
    for i in range(tail):
        s[-1 - i] *= i / tail
    with wave.open(str(OUT / name), 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(x / m * peak * 32767)) for x in s))


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for i in range(3):
        write(f'move{i + 1}.wav', move(11 + i), 0.85)
    for i in range(2):
        write(f'capture{i + 1}.wav', capture(31 + i), 0.95)
    write('select.wav', select(5), 0.45)
    write('check.wav', check(7), 0.9)
    write('win.wav', seq([(523.25, 0.7, 5, 0.6, 0), (659.25, 0.7, 5, 0.6, 0.11), (783.99, 0.7, 5, 0.6, 0.22), (1046.5, 0.8, 4, 0.6, 0.33)]), 0.8)
    write('end.wav', seq([(392, 0.6, 5, 0.6, 0), (523.25, 0.7, 4, 0.5, 0.16)]), 0.7)
    write('fail.wav', seq([(311, 0.35, 8, 0.6, 0), (233, 0.45, 7, 0.6, 0.12)]), 0.7)
    print('đã ghi', sorted(p.name for p in OUT.glob('*.wav')))
