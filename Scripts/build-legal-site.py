#!/usr/bin/env python3
"""Generate the public legal pages from the App's offline documents."""
from html import escape
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
source = (root / 'WeatherIsland/WeatherTabsView.swift').read_text()
model = source.split('enum WeatherSettingsDocument:', 1)[1].split('struct WeatherSettingsDocumentView:', 1)[0]
date = re.search(r'static let updatedDate = "([^"]+)"', model).group(1)
introductions = dict(re.findall(r'case \.(terms|privacy): "([^"]+)"', model))
section_source = model.split('var sections:', 1)[1]
resource_source = source.split('private enum WeatherServiceResource:', 1)[1].split('private struct WeatherServiceLinks:', 1)[0]
titles = dict(re.findall(r'case \.(\w+): "([^"]+)"', resource_source))
urls = dict(re.findall(r'case \.(\w+): address = "([^"]+)"', resource_source))
output = root / 'LegalSite'
output.mkdir(exist_ok=True)

for kind, title, resources in [
    ('privacy', '隐私政策', ['dataPrivacy', 'mapsPrivacy', 'hostingPrivacy']),
    ('terms', '服务协议', ['dataTerms', 'weather', 'air']),
]:
    section_block = re.search(r'case \.' + kind + r': \[(.*?)\n        \]', section_source, re.S).group(1)
    sections = re.findall(r'\("([^"]+)", "([^"]+)"\)', section_block)
    assert len(sections) >= 7, f'Missing sections for {kind}'
    content = '\n'.join(f'<section><h2>{escape(heading)}</h2><p>{escape(text)}</p></section>' for heading, text in sections)
    links = '\n'.join(f'<li><a href="{escape(urls[key], quote=True)}">{escape(titles[key])}<span aria-hidden="true"> ↗</span></a></li>' for key in resources)
    navigation = ''.join(f'<a href="{page}.html"' + (' aria-current="page"' if page == kind else '') + f'>{label}</a>' for page, label in [('privacy', '隐私政策'), ('terms', '服务协议')])
    html = f'''<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light dark">
  <meta name="description" content="气象岛 · {title}。了解天气服务、定位权限、第三方服务与本地数据处理。">
  <title>{title} · 气象岛 WeatherIsland</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <a class="skip" href="#document">跳至正文</a>
  <header><a class="brand" href="index.html"><span class="seal" aria-hidden="true">晴</span><span>气象岛<small>WEATHER ISLAND</small></span></a><nav aria-label="协议导航"><a href="index.html">官网首页</a>{navigation}</nav></header>
  <main id="document">
    <p class="eyebrow">山水入怀，晴雨有时。</p>
    <h1>{title}</h1>
    <p class="date">更新日期：{escape(date)} · 适用于当前版本</p>
    <p class="introduction">{escape(introductions[kind])}</p>
    {content}
    <section class="resources"><h2>相关服务说明</h2><ul>{links}</ul></section>
  </main>
  <footer><p>气象岛 · {title}全文完</p><p>同一份协议，也可在 App「设置」中离线阅读。</p></footer>
</body>
</html>
'''
    (output / f'{kind}.html').write_text(html)
(output / '.nojekyll').touch()
print('Generated LegalSite/privacy.html and terms.html from App documents; homepage preserved.')
