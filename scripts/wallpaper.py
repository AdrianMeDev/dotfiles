#!/usr/bin/env python3
"""Create the Hyprland wallpaper once, including on concurrent installs."""
import os
from pathlib import Path
import struct
import sys
import tempfile
import tomllib
import zlib


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def write_wallpaper(path):
    if os.path.lexists(path):
        return
    tokens = Path(__file__).resolve().parents[1] / 'theme/tokens.toml'
    with tokens.open('rb') as source:
        palette = tomllib.load(source)['palette']
    top, bottom = (bytes.fromhex(palette[key][1:]) for key in ('bg_dark', 'bg_highlight'))
    width, height = 1920, 1080
    rows = bytearray()
    for y in range(height):
        pixel = bytes(a + (b - a) * y // (height - 1) for a, b in zip(top, bottom))
        rows.extend(b'\0' + pixel * width)
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
