#!/usr/bin/env python3
"""Generate Dwell's Android and web launcher PNGs from a tiny stdlib rasterizer."""
from pathlib import Path
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
GREEN, WHITE = (63, 128, 82), (255, 255, 255)


def inside_polygon(x, y, points):
    hit = False
    j = len(points) - 1
    for i, (xi, yi) in enumerate(points):
        xj, yj = points[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def color(x, y, maskable=False):
    # All geometry uses the same 512-unit viewBox as assets/dwell-mark.svg.
    rounded = 112
    corner = (x < rounded or x > 512-rounded) and (y < rounded or y > 512-rounded)
    inside = True
    if corner:
        cx = rounded if x < 256 else 512-rounded
        cy = rounded if y < 256 else 512-rounded
        inside = (x-cx)**2 + (y-cy)**2 <= rounded**2
    base = GREEN
    roof = inside_polygon(x, y, [(88,244),(256,94),(424,244)])
    wall = 132 <= x <= 380 and 224 <= y <= 424
    if roof or wall:
        base = WHITE
    if 218 <= x <= 294 and 310 <= y <= 424:
        base = GREEN
    if 156 <= x <= 199 and 272 <= y <= 315:
        base = GREEN
    return (*base, 255 if maskable or inside else 0)


def chunk(kind, data):
    return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)


def png(size, path, maskable=False):
    scale = 2
    rows = bytearray()
    for py in range(size):
        rows.append(0)
        for px in range(size):
            samples = [color((px+(sx+.5)/scale)*512/size,
                             (py+(sy+.5)/scale)*512/size, maskable)
                       for sy in range(scale) for sx in range(scale)]
            alpha = sum(c[3] for c in samples)
            if alpha:
                rgb = tuple(sum(c[i] * c[3] for c in samples) // alpha for i in range(3))
            else:
                rgb = (0, 0, 0)
            rows.extend((*rgb, alpha // len(samples)))
    data = b'\x89PNG\r\n\x1a\n'
    data += chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 6, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(bytes(rows), 9))
    data += chunk(b'IEND', b'')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def main():
    for density, size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
        png(size, ROOT / 'android/app/src/main/res' / f'mipmap-{density}' / 'ic_launcher.png')
    for filename, size, maskable in [('Icon-192.png',192,False),('Icon-512.png',512,False),
                                     ('Icon-maskable-192.png',192,True),('Icon-maskable-512.png',512,True),
                                     ('favicon.png',48,False)]:
        target = ROOT / 'web' / ('icons' if filename.startswith('Icon') else '') / filename
        png(size, target, maskable)
    ios_icons = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    images = json.loads((ios_icons / 'Contents.json').read_text())['images']
    for image in images:
        width = float(image['size'].split('x')[0])
        scale = int(image['scale'].removesuffix('x'))
        png(round(width * scale), ios_icons / image['filename'], maskable=True)


if __name__ == '__main__':
    main()
