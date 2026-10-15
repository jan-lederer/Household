#!/usr/bin/env python3
"""Generate Dwell's Android and web launcher PNGs from a tiny stdlib rasterizer."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
CREAM, SAGE, ORANGE = (248, 247, 243), (54, 89, 75), (212, 140, 100)


def inside_polygon(x, y, points):
    hit = False
    j = len(points) - 1
    for i, (xi, yi) in enumerate(points):
        xj, yj = points[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def color(x, y):
    # All geometry uses the same 512-unit viewBox as assets/dwell-mark.svg.
    rounded = 112
    if not (x < rounded and y < rounded or x > 512-rounded and y < rounded or
            x < rounded and y > 512-rounded or x > 512-rounded and y > 512-rounded):
        base = CREAM
    else:
        cx = rounded if x < 256 else 512-rounded
        cy = rounded if y < 256 else 512-rounded
        base = CREAM if (x-cx)**2 + (y-cy)**2 <= rounded**2 else (255,255,255)
    roof = inside_polygon(x, y, [(88,244),(256,94),(424,244)])
    wall = 132 <= x <= 380 and 224 <= y <= 424
    if roof or wall:
        base = SAGE
    if 218 <= x <= 294 and 310 <= y <= 424:
        base = CREAM
    if 156 <= x <= 199 and 272 <= y <= 315:
        base = CREAM
    # Four-point sparkle, matching the vector mark.
    if inside_polygon(x, y, [(389,90),(397,115),(422,123),(397,131),
                             (389,156),(381,131),(356,123),(381,115)]):
        base = ORANGE
    return base


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)


def png(size, path):
    scale = 2
    rows = bytearray()
    for py in range(size):
        rows.append(0)
        for px in range(size):
            samples = [color((px+(sx+.5)/scale)*512/size,
                             (py+(sy+.5)/scale)*512/size)
                       for sy in range(scale) for sx in range(scale)]
            rows.extend(tuple(sum(c[i] for c in samples)//len(samples) for i in range(3)))
    data = b'\x89PNG\r\n\x1a\n'
    data += chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 2, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(bytes(rows), 9))
    data += chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def main():
    for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
        png(size, ROOT / 'android/app/src/main/res' / f'mipmap-{density}' / 'ic_launcher.png')
    for filename, size in [('Icon-192.png',192),('Icon-512.png',512),
                           ('Icon-maskable-192.png',192),('Icon-maskable-512.png',512),
                           ('favicon.png',48)]:
        target = ROOT / 'web' / ('icons' if filename.startswith('Icon') else '') / filename
        png(size, target)


if __name__ == '__main__':
    main()
