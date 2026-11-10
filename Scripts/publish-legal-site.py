#!/usr/bin/env python3
"""Publish the official website and legal pages to the dedicated gh-pages branch."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
REPO = 'repos/hekang1992/WeatherIsland'
SITE = ROOT / 'LegalSite'
TEXT_FILES = {'.nojekyll', 'index.html', 'privacy.html', 'terms.html', 'styles.css',
              'home.css', 'home.js', 'robots.txt', 'sitemap.xml'}
ASSET_TYPES = {'.webp', '.png', '.jpg', '.svg'}


def api(path, method='GET', payload=None, missing_ok=False):
    result = subprocess.run(
        ['gh', 'api', f'{REPO}/{path}', '--method', method]
        + (['--input', '-'] if payload is not None else []),
        input=json.dumps(payload) if payload is not None else None,
        capture_output=True, text=True)
    if result.returncode:
        if missing_ok and 'HTTP 404' in result.stderr:
            return None
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else {}


subprocess.run(['python3', str(ROOT / 'Scripts/build-legal-site.py')], check=True)
files = sorted(path for path in SITE.rglob('*') if path.is_file())
for path in files:
    relative = path.relative_to(SITE)
    if path.is_symlink() or any(part.startswith('.') for part in relative.parts if part != '.nojekyll'):
        raise RuntimeError(f'Unexpected site file: {relative}')
    allowed = relative.as_posix() in TEXT_FILES or (relative.parts[0] == 'assets' and path.suffix in ASSET_TYPES)
    if not allowed or path.stat().st_size > 5_000_000:
        raise RuntimeError(f'Unexpected file or oversized site asset: {relative}')

pages = api('pages', missing_ok=True)
if pages and pages.get('source') != {'branch': 'gh-pages', 'path': '/'}:
    raise RuntimeError('Existing Pages site has a different source; preserving its configuration.')
ref = api('git/ref/heads/gh-pages', missing_ok=True)
previous = ref['object']['sha'] if ref else None
base_tree = api(f'git/commits/{previous}')['tree']['sha'] if previous else None
existing = api(f'git/trees/{base_tree}?recursive=1')['tree'] if base_tree else []
if any(item['type'] not in {'tree', 'blob'} for item in existing):
    raise RuntimeError('Unexpected objects on the site branch; preserving the branch.')
known_blobs = {item['sha'] for item in existing if item['type'] == 'blob'}
entries = []
for path in files:
    data = path.read_bytes()
    sha = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
    if sha not in known_blobs:
        blob = api('git/blobs', 'POST', {'content': base64.b64encode(data).decode(), 'encoding': 'base64'})
        if blob['sha'] != sha:
            raise RuntimeError(f'Git blob mismatch for {path.name}')
        known_blobs.add(sha)
    entries.append({'path': path.relative_to(SITE).as_posix(), 'mode': '100644', 'type': 'blob', 'sha': sha})

tree = api('git/trees', 'POST', {'tree': entries})
if previous and base_tree == tree['sha']:
    commit = {'sha': previous}
else:
    commit = api('git/commits', 'POST', {
        'message': 'Publish WeatherIsland official website and legal pages',
        'tree': tree['sha'], 'parents': [previous] if previous else []})
if previous and commit['sha'] != previous:
    api('git/refs/heads/gh-pages', 'PATCH', {'sha': commit['sha'], 'force': False})
elif not previous:
    api('git/refs', 'POST', {'ref': 'refs/heads/gh-pages', 'sha': commit['sha']})
if pages is None:
    pages = api('pages', 'POST', {'build_type': 'legacy', 'source': {'branch': 'gh-pages', 'path': '/'}})
if not pages.get('https_enforced'):
    api('pages', 'PUT', {'https_enforced': True})
print(json.dumps({'url': pages['html_url'], 'commit': commit['sha'], 'source': pages['source'], 'files': len(entries)}, ensure_ascii=False))
