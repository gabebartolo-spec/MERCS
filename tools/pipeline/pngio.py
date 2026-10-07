"""Minimal PNG reader and writer (Python standard library only), shared by the pipeline tools.

Reads 8-bit greyscale, grey+alpha, RGB, RGBA and palette PNGs (non-interlaced, as Blender writes
them) into an Image of RGBA bytes. Writes 8-bit RGBA with filter 0 and fixed zlib settings and no
ancillary chunks (no time, no text), so the same pixels always give the same file bytes from one
Python build. Different zlib builds may compress differently, so cross-machine checks compare
`Image.pixel_sha256()`, not file hashes.
"""
from __future__ import annotations

import hashlib
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path

SIGNATURE = b"\x89PNG\r\n\x1a\n"
ZLIB_LEVEL = 9
CHANNELS = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}  # PNG colour type -> samples per pixel


class PngError(ValueError):
    """The file is not a PNG this module can read."""


@dataclass
class Image:
    width: int
    height: int
    rgba: bytearray  # row-major, 4 bytes per pixel

    @classmethod
    def blank(cls, width: int, height: int) -> "Image":
        return cls(width, height, bytearray(width * height * 4))

    def get(self, x: int, y: int) -> tuple[int, int, int, int]:
        i = (y * self.width + x) * 4
        return tuple(self.rgba[i:i + 4])  # type: ignore[return-value]

    def put(self, x: int, y: int, px: tuple[int, int, int, int]) -> None:
        i = (y * self.width + x) * 4
        self.rgba[i:i + 4] = bytes(px)

    def pixel_sha256(self) -> str:
        """Hash of size plus pixels: identical images hash the same on any machine."""
        head = struct.pack(">II", self.width, self.height)
        return hashlib.sha256(head + bytes(self.rgba)).hexdigest()


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def _unfilter(raw: bytes, width: int, height: int, bpp: int) -> list[bytearray]:
    stride = width * bpp
    rows: list[bytearray] = []
    prev = bytearray(stride)
    pos = 0
    for _ in range(height):
        ftype = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        if ftype == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                left = line[i - bpp] if i >= bpp else 0
                up_left = prev[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + _paeth(left, prev[i], up_left)) & 0xFF
        elif ftype != 0:
            raise PngError(f"unknown filter type {ftype}")
        rows.append(line)
        prev = line
    return rows


def read_png(path: Path | str) -> Image:
    data = Path(path).read_bytes()
    if not data.startswith(SIGNATURE):
        raise PngError("not a PNG signature")
    pos = len(SIGNATURE)
    idat = bytearray()
    plte = b""
    trns = b""
    header = None
    while pos < len(data):
        if pos + 8 > len(data):
            raise PngError("truncated chunk header")
        length, ctype = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif ctype == b"PLTE":
            plte = body
        elif ctype == b"tRNS":
            trns = body
        elif ctype == b"IDAT":
            idat += body
        elif ctype == b"IEND":
            break
    if header is None:
        raise PngError("no IHDR chunk")
    width, height, depth, ctype_px, _, _, interlace = header
    if depth != 8 or interlace != 0 or ctype_px not in CHANNELS:
        raise PngError(f"unsupported PNG: depth {depth}, colour type {ctype_px}, interlace {interlace}")
    bpp = CHANNELS[ctype_px]
    rows = _unfilter(zlib.decompress(bytes(idat)), width, height, bpp)
    img = Image.blank(width, height)
    out = img.rgba
    o = 0
    for line in rows:
        for x in range(width):
            s = line[x * bpp:(x + 1) * bpp]
            if ctype_px == 6:
                out[o:o + 4] = s
            elif ctype_px == 2:
                out[o:o + 4] = bytes((s[0], s[1], s[2], 255))
            elif ctype_px == 0:
                out[o:o + 4] = bytes((s[0], s[0], s[0], 255))
            elif ctype_px == 4:
                out[o:o + 4] = bytes((s[0], s[0], s[0], s[1]))
            else:
                k = s[0]
                alpha = trns[k] if k < len(trns) else 255
                out[o:o + 4] = bytes((plte[3 * k], plte[3 * k + 1], plte[3 * k + 2], alpha))
            o += 4
    return img


def _chunk(ctype: bytes, body: bytes) -> bytes:
    crc = zlib.crc32(ctype + body) & 0xFFFFFFFF
    return struct.pack(">I", len(body)) + ctype + body + struct.pack(">I", crc)


def encode_png(img: Image) -> bytes:
    stride = img.width * 4
    raw = bytearray()
    for y in range(img.height):
        raw.append(0)
        raw += img.rgba[y * stride:(y + 1) * stride]
    ihdr = struct.pack(">IIBBBBB", img.width, img.height, 8, 6, 0, 0, 0)
    return (SIGNATURE + _chunk(b"IHDR", ihdr) + _chunk(b"IDAT", zlib.compress(bytes(raw), ZLIB_LEVEL))
            + _chunk(b"IEND", b""))


def write_png(path: Path | str, img: Image) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(encode_png(img))


def file_sha256(path: Path | str) -> str:
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()
