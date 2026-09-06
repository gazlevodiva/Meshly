#!/usr/bin/env python3
"""Builds the Meshly mark and every app icon from a single description.

    python3 tool/generate_icons.py                # current parameters
    python3 tool/generate_icons.py --width 1.7 --scale 2.4

Why a script rather than a folder of images: the mark's geometry has to be
tuned (bar thickness, node size, scale), and recomputing eight
quadrilaterals by hand and then cutting three dozen PNGs manually is a
reliable way to make a mistake and not notice it.

IMPORTANT, about transparency. The only SVG renderer available on macOS is
the system `qlmanage`, and it FILLS A TRANSPARENT BACKGROUND WITH WHITE.
Such a file looks right on white while its alpha channel is fully opaque.
That is harmless for the app icon (its background is painted anyway), but
Android draws a notification icon FROM ALPHA ALONE, ignoring colour — and
the file turns into a white rectangle in the status bar. Silhouettes are
therefore drawn black-on-white and their alpha derived from luminance.
Verify the result by its alpha: white on white is indistinguishable by eye.
"""
import argparse, glob, math, os, struct, subprocess, sys, zlib

BRAND = '#2F6BFF'
INK = '#FFFFFF'
NODES = [(12, 3.5), (20.5, 12), (12, 20.5), (3.5, 12)]  # north, east, south, west
DENSITIES = [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]
RES = 'android/app/src/main/res'
ICONSET = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'


# ── mark geometry ────────────────────────────────────────────────────────

def _bars(width):
    out = []
    for i in range(4):
        (x1, y1), (x2, y2) = NODES[i], NODES[(i + 1) % 4]
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy)
        px, py = -dy / length * width / 2, dx / length * width / 2
        pts = [(x1 + px, y1 + py), (x2 + px, y2 + py),
               (x2 - px, y2 - py), (x1 - px, y1 - py)]
        out.append('M' + 'L'.join(f'{x:.2f} {y:.2f}' for x, y in pts) + 'Z')
    return '\n           '.join(out)


def _nodes(radius):
    r = radius
    return '\n           '.join(
        f'M{x + r:.2f} {y:.2f}A{r} {r} 0 1 1 {x - r:.2f} {y:.2f}'
        f'A{r} {r} 0 1 1 {x + r:.2f} {y:.2f}Z' for x, y in NODES)


def _shape(width, radius):
    # Bars and nodes are two separate shapes rather than one: inside a single
    # path their overlaps cancel out and bite white notches into the nodes.
    return f'  <path d="{_bars(width)}"/>\n  <path d="{_nodes(radius)}"/>'


def write_svgs(width, radius, scale):
    shape = _shape(width, radius)
    with open('assets/logo/glyph.svg', 'w') as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
                f'fill="currentColor">\n{shape}\n</svg>\n')

    offset = (108 - 24 * scale) / 2
    inner = shape.replace('\n  ', '\n    ').strip()
    # Both files carry an opaque background. The adaptive icon's foreground
    # layer is meant to be transparent per the spec, but this way it also
    # survives launchers that substitute their own background for ours.
    for name in ('mark', 'adaptive-foreground'):
        with open(f'assets/logo/{name}.svg', 'w') as f:
            f.write('<svg xmlns="http://www.w3.org/2000/svg" '
                    'viewBox="0 0 108 108">\n'
                    f'  <rect width="108" height="108" fill="{BRAND}"/>\n'
                    f'  <g fill="{INK}" transform="translate({offset:.2f} '
                    f'{offset:.2f}) scale({scale})">\n  {inner}\n  </g>\n</svg>\n')


# ── PNG without third-party libraries ────────────────────────────────────

def _read_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    pos, idat = 8, b''
    width = height = depth = color = interlace = None
    while pos < len(data):
        size = struct.unpack('>I', data[pos:pos + 4])[0]
        kind, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
        if kind == b'IHDR':
            (width, height, depth, color,
             _compression, _filter, interlace) = struct.unpack('>IIBBBBB', body[:13])
        elif kind == b'IDAT':
            idat += body
        pos += 12 + size
    assert depth == 8 and color in (2, 6), f'{path}: depth={depth} color={color}'
    # An interlaced PNG stores its rows in seven passes. Our row-by-row
    # unfiltering would not crash on one — it would quietly assemble a
    # plausible but wrong image, which no eye can catch. So fail loudly.
    assert interlace == 0, f'{path}: interlaced PNG is not supported'
    channels = 4 if color == 6 else 3
    raw, out, prev, pos = zlib.decompress(idat), bytearray(), bytearray(width * channels), 0
    for _ in range(height):
        filt, pos = raw[pos], pos + 1
        line = bytearray(raw[pos:pos + width * channels])
        pos += width * channels
        for i in range(len(line)):
            a = line[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            if filt == 1:
                line[i] = (line[i] + a) & 255
            elif filt == 2:
                line[i] = (line[i] + b) & 255
            elif filt == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif filt == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc
                                      else b if pb <= pc else c)) & 255
        out += line
        prev = line
    return width, height, channels, bytes(out)


def _write_png(path, width, height, pixels, channels):
    """channels=3 writes no alpha (App Store forbids it on iOS icons),
    channels=4 keeps it (silhouettes)."""
    stride = width * channels
    raw = b''.join(b'\x00' + pixels[y * stride:(y + 1) * stride]
                   for y in range(height))

    def chunk(kind, body):
        return (struct.pack('>I', len(body)) + kind + body
                + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff))

    color_type = 6 if channels == 4 else 2
    open(path, 'wb').write(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, color_type, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(raw, 9))
        + chunk(b'IEND', b''))


# ── rasterisation ────────────────────────────────────────────────────────

def _render(svg_path, size, tmp):
    for stale in glob.glob(f'{tmp}/*.png'):
        os.remove(stale)
    try:
        subprocess.run(['qlmanage', '-t', '-s', str(size), '-o', tmp, svg_path],
                       capture_output=True, check=True)
    except FileNotFoundError:
        sys.exit('qlmanage is required (ships with macOS): no other SVG renderer here')
    except subprocess.CalledProcessError as err:
        sys.exit(f'qlmanage failed to render {svg_path}:\n'
                 f'{err.stderr.decode(errors="replace")}')
    produced = glob.glob(f'{tmp}/*.png')
    assert produced, f'qlmanage produced nothing for {svg_path}'
    return produced[0]


def _check_size(out_path, width, height, size):
    # The renderer must return exactly the size asked for. A file silently
    # written one pixel short passes every check we have and surfaces only
    # at App Store submission.
    assert (width, height) == (size, size), (
        f'{out_path}: got {width}x{height}, expected {size}x{size}')


def _opaque(svg_path, out_path, size, tmp):
    """Opaque image: the SVG paints its own background, no alpha needed."""
    src = _render(svg_path, size, tmp)
    width, height, channels, data = _read_png(src)
    _check_size(out_path, width, height, size)
    pixels = bytearray()
    for i in range(width * height):
        pixels += data[i * channels:i * channels + 3]
    _write_png(out_path, width, height, bytes(pixels), 3)


def _silhouette(ink_svg, out_path, size, rgb, tmp):
    """Silhouette: the mark is drawn black-on-white, luminance → alpha."""
    src = _render(ink_svg, size, tmp)
    width, height, channels, data = _read_png(src)
    _check_size(out_path, width, height, size)
    pixels = bytearray()
    for i in range(width * height):
        pixels += bytes(rgb) + bytes([255 - data[i * channels]])
    _write_png(out_path, width, height, bytes(pixels), 4)


def _hex(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def _ink(tmp, name, body):
    path = f'{tmp}/{name}.svg'
    with open(path, 'w') as f:
        f.write(body)
    return path


def build_pngs(tmp, scale):
    shape = open('assets/logo/glyph.svg').read()
    shape = shape[shape.index('<path'):shape.rindex('</svg>')].strip()

    # The mark flush to the edges — for the splash and launch screens, where
    # the screen itself provides the margin.
    ink_svg = _ink(tmp, 'ink', '<svg xmlns="http://www.w3.org/2000/svg" '
                   f'viewBox="0 0 24 24" fill="#000000">\n{shape}\n</svg>\n')

    # Notification icon: Android and vendor shells crop it further, so the
    # mark needs roughly 8% of the canvas as margin — flush to the edges it
    # looks clipped in the status bar.
    inset = _ink(tmp, 'ink-inset', '<svg xmlns="http://www.w3.org/2000/svg" '
                 'viewBox="0 0 24 24" fill="#000000">\n'
                 f'  <g transform="translate(1.0 1.0) scale(0.916)">\n'
                 f'  {shape}\n  </g>\n</svg>\n')

    # Monochrome layer (Android 13+): the system tints it to match the
    # wallpaper. Without it our icon stays full-colour among re-tinted
    # neighbours. Same geometry as the foreground so the sizes agree.
    offset = (108 - 24 * scale) / 2
    mono = _ink(tmp, 'ink-mono', '<svg xmlns="http://www.w3.org/2000/svg" '
                'viewBox="0 0 108 108" fill="#000000">\n'
                f'  <g transform="translate({offset:.2f} {offset:.2f}) '
                f'scale({scale})">\n  {shape}\n  </g>\n</svg>\n')

    for density, factor in DENSITIES:
        folder = f'{RES}/mipmap-{density}'
        os.makedirs(folder, exist_ok=True)
        _opaque('assets/logo/mark.svg',
                f'{folder}/ic_launcher.png', round(48 * factor), tmp)
        _opaque('assets/logo/adaptive-foreground.svg',
                f'{folder}/ic_launcher_foreground.png', round(108 * factor), tmp)
        _silhouette(mono, f'{folder}/ic_launcher_monochrome.png',
                    round(108 * factor), (0, 0, 0), tmp)

        folder = f'{RES}/drawable-{density}'
        os.makedirs(folder, exist_ok=True)
        _silhouette(inset, f'{folder}/ic_notification.png',
                    round(24 * factor), _hex(INK), tmp)
        _silhouette(ink_svg, f'{folder}/splash_logo.png',
                    round(96 * factor), _hex(BRAND), tmp)

    # Image for the README: GitHub does not always render SVG in markdown.
    _opaque('assets/logo/mark.svg', 'assets/logo/logo.png', 256, tmp)

    launch = 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
    for name, factor in [('LaunchImage.png', 1), ('LaunchImage@2x.png', 2),
                         ('LaunchImage@3x.png', 3)]:
        _silhouette(ink_svg, f'{launch}/{name}', 96 * factor, _hex(BRAND), tmp)

    import json
    spec = json.load(open(f'{ICONSET}/Contents.json'))
    for entry in {i['filename']: i for i in spec['images']}.values():
        side = float(entry['size'].split('x')[0]) * int(entry['scale'][0])
        _opaque('assets/logo/mark.svg',
                f"{ICONSET}/{entry['filename']}", round(side), tmp)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--width', type=float, default=1.7,
                        help='bar thickness, in units of the 24x24 grid')
    parser.add_argument('--radius', type=float, default=2.2,
                        help='node radius')
    parser.add_argument('--scale', type=float, default=2.4,
                        help='mark scale inside the 108x108 tile')
    args = parser.parse_args()

    if not os.path.isdir('assets/logo'):
        sys.exit('Run from the meshly/ project root')

    tmp = '.dart_tool/logo-build'
    os.makedirs(tmp, exist_ok=True)
    write_svgs(args.width, args.radius, args.scale)
    build_pngs(tmp, args.scale)
    print(f'mark: width {args.width}, nodes {args.radius}, scale {args.scale}')
    print('rebuilt: SVGs in assets/logo, Android and iOS icons,')
    print('notification, splash and monochrome silhouettes')


if __name__ == '__main__':
    main()
