#!/usr/bin/env python3
"""Create the Hyprland wallpaper once, including on concurrent installs."""
import math
import os
from pathlib import Path
import struct
import sys
import tempfile
import tomllib
import zlib


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


# Soft colour glows that blurred, translucent windows pick up.
# (palette key, centre x and y as a fraction of the size, radius as a fraction
# of the height, strength)
GLOWS = (
    ('blue', 0.15, 0.25, 0.40, 0.55),
    ('magenta', 0.85, 0.75, 0.45, 0.50),
    ('cyan', 0.62, 0.05, 0.22, 0.35),
)


def gaussian(size, centre, radius):
    return [math.exp(-((i - centre) / radius) ** 2 / 2) for i in range(size)]


def render(palette, width, height):
    top, bottom = (bytes.fromhex(palette[key][1:]) for key in ('bg_dark', 'bg_highlight'))
    glows = []
    for key, x, y, radius, strength in GLOWS:
        colour = bytes.fromhex(palette[key][1:])
        glows.append((colour, gaussian(width, x * width, radius * height),
                      gaussian(height, y * height, radius * height), strength))
    rows = bytearray()
    for y in range(height):
        base = [a + (b - a) * y / (height - 1) for a, b in zip(top, bottom)]
        channels = [[value] * width for value in base]
        for colour, along_x, along_y, strength in glows:
            row_weight = strength * along_y[y]
            if row_weight < 1e-4:
                continue
            for channel, target in zip(channels, colour):
                for x, weight in enumerate(along_x):
                    channel[x] += (target - channel[x]) * row_weight * weight
        rows.append(0)
        rows.extend(bytes(round(value) for pixel in zip(*channels) for value in pixel))
    return rows


def write_wallpaper(path):
    if os.path.lexists(path):
        return
    tokens = Path(__file__).resolve().parents[1] / 'theme/tokens.toml'
    with tokens.open('rb') as source:
        palette = tomllib.load(source)['palette']
    width, height = 1920, 1080
    rows = render(palette, width, height)
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent) as temp:
        temp.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
                   + chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b''))
        temp.flush()
        try:
            os.link(temp.name, path)
        except FileExistsError:
            pass


if __name__ == '__main__':
    write_wallpaper(Path(sys.argv[1]))
