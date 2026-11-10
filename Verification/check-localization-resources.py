#!/usr/bin/env python3
"""Validate the shared catalog, localized system resources and release packages."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import zipfile

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = ('zh-Hans', 'en', 'vi')
FORMAT = re.compile(r'%(?:(\d+)\$)?(@|lld|ld|d|f|s)')


def units(value):
    if 'stringUnit' in value:
        yield value['stringUnit']['value']
    for variants in value.get('variations', {}).values():
        for child in variants.values():
            yield from units(child)


def placeholders(value):
    return Counter((int(m[1]) if m[1] else i + 1, m[2])
                   for i, m in enumerate(FORMAT.finditer(value)))


def check(assets=False):
    catalog = json.loads((ROOT / 'Shared/Localizable.xcstrings').read_text())
    entries = catalog['strings']
    translated = 0
    for key, entry in entries.items():
        if entry.get('shouldTranslate') is False:
            continue
        translated += 1
        source_units = list(units(entry.get('localizations', {}).get('zh-Hans', {})))
        expected = placeholders(source_units[0]) if source_units else placeholders(key)
        for language in LANGUAGES:
            texts = list(units(entry.get('localizations', {}).get(language, {})))
            assert texts, f'Missing {language}: {key}'
            for text in texts:
                assert text.strip(), f'Empty {language}: {key}'
                assert expected == placeholders(text), f'Placeholders {language}: {key}'
                if language != 'zh-Hans':
                    assert not re.search(r'[\u4e00-\u9fff]', text), f'Untranslated {language}: {key}'
    for language in LANGUAGES:
        for target in ('WeatherIsland', 'WeatherWidgets'):
            text = (ROOT / target / f'{language}.lproj/InfoPlist.strings').read_text()
            assert 'CFBundleDisplayName' in text
        assert (ROOT / 'WeatherIsland' / f'{language}.lproj/LaunchScreen.storyboard').is_file()
    result = {'catalogEntries': len(entries), 'translatedEntries': translated, 'languages': list(LANGUAGES)}
    if assets:
        result['releasePackages'] = []
        for locale in ('zh-Hans', 'en-US', 'vi'):
            directory = ROOT / 'Branding/AppStore' / locale
            validation = json.loads((directory / 'validation.json').read_text())
            metadata = json.loads((directory / 'metadata.json').read_text())
            assert validation['passed'] and len(validation['images']) == 7
            assert len(metadata['name']) <= 30 and len(metadata['subtitle']) <= 30
            assert len(metadata['promotionalText']) <= 170 and len(metadata['description']) <= 4000
            assert len(metadata['keywords'].encode('utf8')) <= 100
            manifest = json.loads((directory / 'manifest.json').read_text())
            assert len(manifest) == 7
            with zipfile.ZipFile(directory / validation['archive']['file']) as archive:
                assert archive.testzip() is None and len(archive.namelist()) == 7
                for image in validation['images']:
                    data = (directory / image['file']).read_bytes()
                    assert data[:8] == b'\x89PNG\r\n\x1a\n'
                    width, height, depth, color_type = struct.unpack('>IIBB', data[16:26])
                    assert [width, height] == image['dimensions'] and color_type == 2 and depth == 8
                    assert hashlib.sha256(data).hexdigest() == image['sha256']
                    assert archive.read(image['file']) == data
            for item in manifest:
                for source in item['sourceAssets']:
                    assert hashlib.sha256((ROOT / source['file']).read_bytes()).hexdigest() == source['sha256'], source['file']
            result['releasePackages'].append({'locale': locale, 'images': 7, 'keywordsUTF8Bytes': len(metadata['keywords'].encode('utf8'))})
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets', action='store_true', help='Also validate all three final marketing packages and their source hashes.')
    args = parser.parse_args()
    print(json.dumps({'passed': True, **check(args.assets)}, ensure_ascii=False, indent=2))
