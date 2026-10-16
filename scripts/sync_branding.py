#!/usr/bin/env python3
"""Atualiza os recursos locais; build e execução independem de docs-gerais."""
import hashlib
import json
from pathlib import Path
import re
import sys

MOBILE = Path(__file__).resolve().parents[1]
SOURCE = MOBILE.parent / 'docs-gerais/identidade-visual'
CHECK = '--check' in sys.argv
FILES = []


def snapshot(target, data):
    path = MOBILE / target
    if CHECK:
        if not path.is_file() or path.read_bytes() != data:
            raise ValueError(f'Recurso desatualizado: {target}. Execute python3 scripts/sync_branding.py.')
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


def copy(source, target):
    data = source.read_bytes()
    snapshot(target, data)
    FILES.append({'path': target, 'sha256': hashlib.sha256(data).hexdigest()})


def dart_string(value):
    return json.dumps(value, ensure_ascii=False).replace('$', r'\$')


try:
    tokens = json.loads((SOURCE / 'tokens.json').read_text())
    geometry = json.loads((SOURCE / 'icone/geometria.json').read_text())
    selection = json.loads((SOURCE / 'assinatura/selecao.json').read_text())
    for name in ['Manrope-Variable.ttf', 'DMMono-Regular.ttf', 'DMMono-Medium.ttf', 'Manrope-OFL.txt', 'DMMono-OFL.txt']:
        copy(SOURCE / 'assets' / name, 'assets/branding/fonts/' + name)
    for entry in selection['files']:
        if not entry['path'].startswith('selecionada/png/'):
            continue
        origin = SOURCE / 'assinatura' / entry['path']
        assert hashlib.sha256(origin.read_bytes()).hexdigest() == entry['sha256'], entry['path']
        copy(origin, 'assets/branding/author/' + origin.name)
    copy(SOURCE / 'assinatura/README.md', 'assets/branding/author/README.md')
    native = SOURCE / 'icone/android/res'
    for origin in sorted(native.rglob('*')):
        if origin.is_file():
            copy(origin, 'android/app/src/main/res/' + str(origin.relative_to(native)))
    ios = SOURCE / 'icone/ios/AppIcon.appiconset'
    for origin in sorted(ios.iterdir()):
        if origin.is_file():
            copy(origin, 'ios/Runner/Assets.xcassets/AppIcon.appiconset/' + origin.name)
    for name in ['LaunchImage.png', 'LaunchImage@2x.png', 'LaunchImage@3x.png']:
        copy(SOURCE / 'icone/png/symbol-lime-512.png', 'ios/Runner/Assets.xcassets/LaunchImage.imageset/' + name)
    for source, target in [('favicon-32.png', 'favicon.png'), ('icon-192.png', 'icons/Icon-192.png'), ('icon-512.png', 'icons/Icon-512.png'), ('icon-maskable-192.png', 'icons/Icon-maskable-192.png'), ('icon-maskable-512.png', 'icons/Icon-maskable-512.png')]:
        copy(SOURCE / 'icone/web' / source, 'web/' + target)

    color = tokens['color']
    snapshot('android/app/src/main/res/values/wms_surface_colors.xml', (
        '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
        f'    <color name="wms_surface_background">{color["background"]}</color>\n'
        '</resources>\n'
    ).encode())
    snapshot('android/app/src/main/res/drawable/wms_splash_mark.xml', (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="128dp" android:height="128dp"\n'
        '    android:viewportWidth="128" android:viewportHeight="128">\n'
        f'    <path android:fillColor="{color["brand"]["accent"]}" android:pathData="{geometry["path"]}" />\n'
        '</vector>\n'
    ).encode())
    roles = {
        'ink': color['brand']['ink'], 'primary': color['brand']['primary'], 'primaryHover': color['brand']['primaryHover'],
        'onPrimary': color['brand']['onPrimary'], 'accent': color['brand']['accent'], 'onAccent': color['brand']['onAccent'],
        'soft': color['brand']['soft'], 'background': color['background'], 'surface': color['surface'],
        'surfaceMuted': color['surfaceMuted'], 'text': color['text']['primary'], 'muted': color['text']['secondary'],
        'inverseText': color['text']['inverse'], 'inverseMuted': color['text']['inverseSecondary'],
        'border': color['border']['subtle'], 'control': color['border']['control'],
    }
    for name, semantic in color['semantic'].items():
        roles[name] = semantic['foreground']
        roles[name + 'Background'] = semantic['background']
    assert all(re.fullmatch(r'#[0-9a-fA-F]{6}', value) for value in roles.values())

    # The canonical symbol deliberately contains only straight segments.
    commands = re.findall(r'([MHVLZ])([^MHVLZ]*)', geometry['path'])
    assert ''.join(command + values for command, values in commands) == geometry['path']
    x = y = 0
    statements = []
    for command, raw in commands:
        values = [float(value) for value in raw.split()]
        if command == 'Z':
            statements.append('  ..close();')
            continue
        if command in ('M', 'L'):
            x, y = values
        elif command == 'H':
            x, = values
        else:
            y, = values
        method = 'moveTo' if command == 'M' else 'lineTo'
        statements.append(f'  ..{method}({x:g}, {y:g})')
    author = tokens['assets']['authorCredit']
    constants = {
        'name': tokens['metadata']['project'], 'descriptor': tokens['metadata']['descriptor'],
        'tagline': tokens['metadata']['tagline'], 'sansFont': tokens['typography']['family']['sans'],
        'monoFont': tokens['typography']['family']['mono'], 'authorName': author['name'],
        'authorLabel': author['label'], 'portfolio': author['portfolio'],
        'authorLight': 'assets/branding/author/' + Path(author['pngLight']).name,
        'authorDark': 'assets/branding/author/' + Path(author['pngDark']).name,
    }
    dart = "// Gerado por scripts/sync_branding.py.\nimport 'dart:ui';\n\nabstract final class BrandColors {\n"
    dart += ''.join(f'  static const {name} = Color(0xFF{value[1:]});\n' for name, value in roles.items())
    dart += '}\n\nabstract final class AppBrand {\n'
    for name, value in constants.items():
        line = f'  static const {name} = {dart_string(value)};'
        dart += (line if len(line) <= 80 else f'  static const {name} =\n      {dart_string(value)};') + '\n'
    dart += ''.join(f'  static const {name}Radius = {tokens["radius"][name]}.0;\n' for name in ['control', 'card', 'feature'])
    dart += '}\n\nPath createBrandSymbolPath() => Path()\n' + '\n'.join(statements) + '\n'
    snapshot('lib/src/app/branding/brand_tokens.dart', dart.encode())
    snapshot('assets/branding/provenance.json', (json.dumps({'concept': tokens['metadata']['concept'], 'symbol': geometry, 'signatureSource': selection['source'], 'files': FILES}, ensure_ascii=False, indent=2) + '\n').encode())
    print('Branding mobile ' + ('conferido' if CHECK else 'sincronizado') + ': tokens, fontes, símbolo, autoria e ícones Android/iOS/web.')
except (OSError, ValueError, KeyError, AssertionError) as error:
    print(f'Não foi possível sincronizar a identidade: {error}', file=sys.stderr)
    raise SystemExit(1)
