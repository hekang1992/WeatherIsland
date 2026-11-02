#!/usr/bin/env python3
"""Publish only LegalSite files to the repository's dedicated gh-pages branch."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
REPO = 'repos/hekang1992/WeatherIsland'

def api(path, method='GET', payload=None, missing_ok=False):
    result = subprocess.run(['gh', 'api', f'{REPO}/{path}', '--method', method] + (['--input', '-'] if payload is not None else []),
                            input=json.dumps(payload) if payload is not None else None, capture_output=True, text=True)
    if result.returncode:
        if missing_ok and 'HTTP 404' in result.stderr:
            return None
        raise RuntimeError(result.stderr.strip())
    return json.loads(result.stdout) if result.stdout.strip() else {}

subprocess.run(['python3', str(ROOT / 'Scripts/build-legal-site.py')], check=True)
pages = api('pages', missing_ok=True)
if pages and pages.get('source') != {'branch': 'gh-pages', 'path': '/'}:
    raise RuntimeError('Existing Pages site has a different source; preserving its configuration.')
ref = api('git/ref/heads/gh-pages', missing_ok=True)
previous = ref['object']['sha'] if ref else None
payload = {'tree': [{'path': name, 'mode': '100644', 'type': 'blob', 'content': (ROOT / 'LegalSite' / name).read_text()}
                    for name in ['.nojekyll', 'index.html', 'privacy.html', 'terms.html', 'styles.css']]}
if previous:
    payload['base_tree'] = api(f'git/commits/{previous}')['tree']['sha']
tree = api('git/trees', 'POST', payload)
if previous and payload.get('base_tree') == tree['sha']:
    commit = {'sha': previous}
else:
    commit = api('git/commits', 'POST', {'message': 'Publish WeatherIsland privacy policy and terms', 'tree': tree['sha'], 'parents': [previous] if previous else []})
if previous and commit['sha'] != previous:
    api('git/refs/heads/gh-pages', 'PATCH', {'sha': commit['sha'], 'force': False})
elif not previous:
    api('git/refs', 'POST', {'ref': 'refs/heads/gh-pages', 'sha': commit['sha']})
if pages is None:
    pages = api('pages', 'POST', {'build_type': 'legacy', 'source': {'branch': 'gh-pages', 'path': '/'}})
if not pages.get('https_enforced'):
    api('pages', 'PUT', {'https_enforced': True})
print(json.dumps({'url': pages['html_url'], 'commit': commit['sha'], 'source': pages['source']}, ensure_ascii=False))
