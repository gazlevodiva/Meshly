#!/usr/bin/env python3
"""Собирает знак Meshly и все иконки приложения из одного описания.

    python3 tool/generate_icons.py                # текущие параметры
    python3 tool/generate_icons.py --width 1.7 --scale 2.4

Почему это скрипт, а не набор картинок в репозитории: геометрию знака
приходится подбирать (толщина, размер узлов, масштаб), а руками
пересчитывать восемь четырёхугольников и потом вручную резать три десятка
PNG — верный способ ошибиться и не заметить.

ВАЖНО про прозрачность. Единственный доступный отрисовщик SVG на macOS —
системный `qlmanage`, и он ЗАЛИВАЕТ ПРОЗРАЧНЫЙ ФОН БЕЛЫМ. На белом такой
файл выглядит правильно, но альфа-канал у него сплошь непрозрачный.
Для иконки приложения это безразлично (фон и так закрашен), а иконку
уведомления Android рисует ПО ОДНОЙ ЛИШЬ АЛЬФЕ, игнорируя цвета — и файл
превращается в белый прямоугольник в строке состояния. Поэтому силуэты
рисуются чёрным по белому, а прозрачность вычисляется из яркости.
Проверять результат надо по альфе: белое на белом на глаз не отличить.
"""
import argparse, glob, math, os, struct, subprocess, sys, zlib

BRAND = '#2F6BFF'
INK = '#FFFFFF'
NODES = [(12, 3.5), (20.5, 12), (12, 20.5), (3.5, 12)]  # север, восток, юг, запад
DENSITIES = [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]
RES = 'android/app/src/main/res'
ICONSET = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'


# ── геометрия знака ──────────────────────────────────────────────────────

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
    # Перекладины и узлы — две отдельные фигуры, а не одна: в общем контуре
    # их перекрытия взаимно вычитаются и выедают белые выемки в узлах.
    return f'  <path d="{_bars(width)}"/>\n  <path d="{_nodes(radius)}"/>'


def write_svgs(width, radius, scale):
    shape = _shape(width, radius)
    with open('assets/logo/glyph.svg', 'w') as f:
        f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
                f'fill="currentColor">\n{shape}\n</svg>\n')

    offset = (108 - 24 * scale) / 2
    inner = shape.replace('\n  ', '\n    ').strip()
    # Оба файла с непрозрачным фоном. Передний слой адаптивной иконки по
    # спецификации должен быть прозрачным, но так он переживает и лаунчеры,
    # которые подставляют собственный фон вместо объявленного нами.
    for name in ('mark', 'adaptive-foreground'):
        with open(f'assets/logo/{name}.svg', 'w') as f:
            f.write('<svg xmlns="http://www.w3.org/2000/svg" '
                    'viewBox="0 0 108 108">\n'
                    f'  <rect width="108" height="108" fill="{BRAND}"/>\n'
                    f'  <g fill="{INK}" transform="translate({offset:.2f} '
                    f'{offset:.2f}) scale({scale})">\n  {inner}\n  </g>\n</svg>\n')


# ── PNG без сторонних библиотек ──────────────────────────────────────────

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
    # Чересстрочный PNG хранит строки в семь проходов. Наша построчная
    # распаковка на нём не упадёт, а тихо соберёт правдоподобную, но
    # неверную картинку — такое глазами не отличить, поэтому падаем громко.
    assert interlace == 0, f'{path}: чересстрочный PNG не поддерживается'
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
    """channels=3 — без альфы (у иконок iOS она запрещена при публикации),
    channels=4 — с альфой (силуэты)."""
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


# ── растеризация ─────────────────────────────────────────────────────────

def _render(svg_path, size, tmp):
    for stale in glob.glob(f'{tmp}/*.png'):
        os.remove(stale)
    try:
        subprocess.run(['qlmanage', '-t', '-s', str(size), '-o', tmp, svg_path],
                       capture_output=True, check=True)
    except FileNotFoundError:
        sys.exit('Нужен qlmanage (входит в macOS): другого отрисовщика SVG здесь нет')
    except subprocess.CalledProcessError as err:
        sys.exit(f'qlmanage не смог отрисовать {svg_path}:\n'
                 f'{err.stderr.decode(errors="replace")}')
    produced = glob.glob(f'{tmp}/*.png')
    assert produced, f'qlmanage не отрисовал {svg_path}'
    return produced[0]


def _check_size(out_path, width, height, size):
    # Отрисовщик обязан отдать ровно запрошенный размер. Молча записанный
    # файл на пиксель меньше пройдёт все наши проверки и всплывёт только
    # при публикации в App Store.
    assert (width, height) == (size, size), (
        f'{out_path}: получено {width}x{height} вместо {size}x{size}')


def _opaque(svg_path, out_path, size, tmp):
    """Непрозрачная картинка: фон закрашен в самом SVG, альфа не нужна."""
    src = _render(svg_path, size, tmp)
    width, height, channels, data = _read_png(src)
    _check_size(out_path, width, height, size)
    pixels = bytearray()
    for i in range(width * height):
        pixels += data[i * channels:i * channels + 3]
    _write_png(out_path, width, height, bytes(pixels), 3)


def _silhouette(ink_svg, out_path, size, rgb, tmp):
    """Силуэт: знак нарисован чёрным по белому, яркость → прозрачность."""
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

    # Знак вплотную к краям — для заставки и экрана запуска, там поле даёт
    # сам экран.
    ink_svg = _ink(tmp, 'ink', '<svg xmlns="http://www.w3.org/2000/svg" '
                   f'viewBox="0 0 24 24" fill="#000000">\n{shape}\n</svg>\n')

    # Иконка уведомления: Android и оболочки производителей дополнительно
    # кадрируют её, поэтому знак нужно отодвинуть от краёв примерно на 8%
    # холста — вплотную он выглядит обрезанным в строке состояния.
    inset = _ink(tmp, 'ink-inset', '<svg xmlns="http://www.w3.org/2000/svg" '
                 'viewBox="0 0 24 24" fill="#000000">\n'
                 f'  <g transform="translate(1.0 1.0) scale(0.916)">\n'
                 f'  {shape}\n  </g>\n</svg>\n')

    # Монохромный слой (Android 13+): система тонирует его под обои. Без
    # него иконка остаётся полноцветной среди перекрашенных соседей.
    # Геометрия — как у переднего слоя, чтобы размер совпадал.
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
                        help='толщина перекладин (в единицах сетки 24×24)')
    parser.add_argument('--radius', type=float, default=2.2,
                        help='радиус узла')
    parser.add_argument('--scale', type=float, default=2.4,
                        help='масштаб знака внутри плитки 108×108')
    args = parser.parse_args()

    if not os.path.isdir('assets/logo'):
        sys.exit('Запускать из корня проекта meshly/')

    tmp = '.dart_tool/logo-build'
    os.makedirs(tmp, exist_ok=True)
    write_svgs(args.width, args.radius, args.scale)
    build_pngs(tmp, args.scale)
    print(f'знак: толщина {args.width}, узлы {args.radius}, масштаб {args.scale}')
    print('пересобраны: SVG в assets/logo, иконки Android и iOS,')
    print('силуэты уведомления, заставки и монохромного слоя')


if __name__ == '__main__':
    main()
