#!/usr/bin/env python3
"""Render seven exact-size App Store product images from original WeatherIsland assets.

Requires Pillow and the bundled macOS Songti/Heiti fonts. All UI images are
existing app previews; the script never fabricates app controls or readings.
"""
from pathlib import Path
import json
import math
import zipfile
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageCms

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'Branding' / 'AppStore'
OUT.mkdir(parents=True, exist_ok=True)
S = 2
INK = '#2b4438'
MUTED = '#707b68'
RED = '#a85745'
PAPER = '#f5f1e6'
SERIF = '/System/Library/Fonts/Supplemental/Songti.ttc'
SANS = '/System/Library/Fonts/STHeiti Light.ttc'
LATIN = '/System/Library/Fonts/Supplemental/Arial.ttf'
PROFILE = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
MANIFEST = []


def font(size, kind='serif'):
    path, index = (SERIF, 6) if kind == 'serif' else ((SANS, 1) if kind == 'sans' else (LATIN, 0))
    return ImageFont.truetype(path, round(size*S), index=index)


def text(im, xy, value, size, fill=INK, kind='serif', anchor='lt', tracking=0):
    draw = ImageDraw.Draw(im)
    ft = font(size, kind)
    x, y = xy[0]*S, xy[1]*S
    if tracking:
        lengths = [draw.textlength(c, font=ft) for c in value]
        total = sum(lengths) + max(0, len(value)-1)*tracking*S
        if anchor.startswith('m'): x -= total/2
        if anchor.startswith('r'): x -= total
        reference = 'H' if kind == 'latin' else '国'
        baseline = y - ft.getbbox(reference, anchor='ls')[1]
        for c, length in zip(value, lengths):
            draw.text((round(x), round(baseline)), c, font=ft, fill=fill, anchor='ls')
            x += length + tracking*S
    else:
        draw.text((round(x), round(y)), value, font=ft, fill=fill, anchor=anchor)


def line(im, xy, fill='#cbd2c0', width=1):
    ImageDraw.Draw(im).line(tuple(v*S for v in xy), fill=fill, width=max(1, round(width*S)))


def rounded(im, box, radius, fill, outline=None, width=1):
    ImageDraw.Draw(im).rounded_rectangle(tuple(round(x*S) for x in box), radius=round(radius*S), fill=fill, outline=outline, width=round(width*S))


def canvas(w, h, palette='paper'):
    base = Image.new('RGB', (w*S, h*S), PAPER)
    # A subtle, deterministic paper grain with a broad color wash.
    noise = Image.effect_noise((w*S,h*S), 5).convert('RGB')
    base = Image.blend(base, noise, .022)
    if palette == 'sage': wash = '#e2e8d7'
    elif palette == 'blue': wash = '#e0e9e4'
    else: wash = '#e6e8d9'
    grad = Image.new('L',(1,h*S)); px=grad.load()
    for y in range(h*S): px[0,y]=round(130*max(0,(y/(h*S)-.28)/.72))
    grad=grad.resize(base.size)
    base.paste(Image.new('RGB',base.size,wash),(0,0),grad)
    return base


def shadow_paste(im, source, xy, blur=28, offset=(0,18), opacity=.17):
    rgba=source.convert('RGBA')
    # Separate the shadow from its artwork so the screenshot stays crisp.
    layer=Image.new('RGBA',im.size)
    mask=rgba.getchannel('A').point(lambda p:round(p*opacity))
    silhouette=Image.new('RGBA',rgba.size,'#263c2f');silhouette.putalpha(mask)
    layer.alpha_composite(silhouette,(round((xy[0]+offset[0])*S),round((xy[1]+offset[1])*S)))
    layer=layer.filter(ImageFilter.GaussianBlur(blur*S))
    im.paste(layer,(0,0),layer)
    im.paste(rgba,(round(xy[0]*S),round(xy[1]*S)),rgba)


def asset(name):
    return Image.open(ROOT/'Previews'/name).convert('RGB')


def phone(name, width, angle=0):
    screen=asset(name)
    border=10
    screenw=round((width-2*border)*S)
    screenh=round(screen.height*screenw/screen.width)
    device=Image.new('RGBA',(round(width*S),screenh+round(2*border*S)))
    draw=ImageDraw.Draw(device)
    r=round(width*.135*S)
    draw.rounded_rectangle((0,0,device.width-1,device.height-1),radius=r,fill='#33453a',outline='#83907e',width=round(1.5*S))
    draw.rounded_rectangle((4*S,4*S,device.width-4*S-1,device.height-4*S-1),radius=r-4*S,fill='#24362d')
    screen=screen.resize((screenw,screenh),Image.Resampling.LANCZOS)
    mask=Image.new('L',screen.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,screenw-1,screenh-1),radius=r-border*S,fill=255)
    device.paste(screen,(border*S,border*S),mask)
    if angle:device=device.rotate(angle,Image.Resampling.BICUBIC,expand=True)
    return device


def card(name, width, radius=35):
    im=asset(name);im=im.resize((round(width*S),round(im.height*width*S/im.width)),Image.Resampling.LANCZOS).convert('RGBA')
    mask=Image.new('L',im.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,im.width-1,im.height-1),radius=round(radius*S),fill=255)
    im.putalpha(mask)
    return im


def painting(name, width, angle=0):
    picture=asset(name);picture.thumbnail((round(width*S),round(width*S)),Image.Resampling.LANCZOS)
    padding=9*S
    frame=Image.new('RGB',(picture.width+2*padding,picture.height+2*padding),'#f8f4e9')
    frame.paste(picture,(padding,padding))
    frame=frame.convert('RGBA')
    if angle:frame=frame.rotate(angle,Image.Resampling.BICUBIC,expand=True)
    return frame


def brand(im, width, number=None):
    icon=Image.open(ROOT/'WeatherIsland/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png').convert('RGB').resize((62*S,62*S),Image.Resampling.LANCZOS)
    mask=Image.new('L',icon.size);ImageDraw.Draw(mask).rounded_rectangle((0,0,62*S-1,62*S-1),radius=16*S,fill=255)
    im.paste(icon,(82*S,77*S),mask)
    text(im,(163,78),'气象岛',39,tracking=3)
    text(im,(165,124),'WEATHER ISLAND',12,kind='latin',tracking=2.8,fill=MUTED)
    if number:
        text(im,(width-85,90),number,15,kind='sans',fill=MUTED,anchor='rt',tracking=1.7)
    line(im,(83,173,width-83,173),'#cbd1c0')


def headline(im, first, second, subtitle, eyebrow):
    text(im,(589.5,236),eyebrow,20,kind='sans',anchor='mt',tracking=5,fill=RED)
    text(im,(589.5,304),first,100,anchor='mt',tracking=1)
    text(im,(589.5,439),second,100,anchor='mt',tracking=1)
    text(im,(589.5,602),subtitle,28,kind='sans',anchor='mt',fill=MUTED,tracking=1.5)
    line(im,(560,680,619,680),RED,2)


def mountains(im, start=1700, opacity=.40):
    layer=Image.new('RGBA',im.size)
    d=ImageDraw.Draw(layer)
    w=im.width/S;h=im.height/S
    for k,(color,alpha) in enumerate([('#a1b49b',.32),('#7d987c',.25),('#476f59',.22)]):
        points=[]
        for x in range(-30,round(w)+31,12):
            y=start+105*k + 70*math.sin(x/155+k*2)+40*math.sin(x/70-k)
            points.append((round(x*S),round(y*S)))
        rgb=tuple(int(color[i:i+2],16) for i in (1,3,5))
        d.polygon(points+[(round((w+40)*S),round((h+40)*S)),(-40*S,round((h+40)*S))],fill=rgb+(round(alpha*opacity*255),))
    im.paste(layer,(0,0),layer)


def seal(im,x,y,word='晴雨'):
    rounded(im,(x,y,x+42,y+74),3,None,RED,1.5)
    for i,c in enumerate(word):text(im,(x+21,y+9+i*29),c,24,fill=RED,anchor='mt')


def footer(im, label, color=MUTED):
    text(im,(589.5,2497),label,18,kind='sans',anchor='mt',fill=color,tracking=3)


def save(im,name,title,features,sources):
    im=im.resize((im.width//S,im.height//S),Image.Resampling.LANCZOS).convert('RGB')
    path=OUT/name
    im.save(path,optimize=True,icc_profile=PROFILE,dpi=(72,72))
    MANIFEST.append({'file':name,'size':list(im.size),'mode':im.mode,'title':title,'features':features,'sourceAssets':sources})
    print(f'{name}: {im.width} × {im.height}, RGB, {path.stat().st_size:,} bytes',flush=True)


def render_original():
    # 01 — Clear, readable weather in an original landscape.
    im=canvas(1179,2556)
    brand(im,1179,'01 / 日常晴雨')
    headline(im,'把天气，','读成一卷山水。','逐小时天气 · 多日预报 · 空气质量','山水入怀，晴雨有时')
    mountains(im,1790,.75)
    # An oversize landscape circle echoes the actual brand mark.
    art=asset('Scene-16.png').resize((1250*S,860*S),Image.Resampling.LANCZOS)
    mask=Image.new('L',art.size);ImageDraw.Draw(mask).ellipse((0,-200*S,1250*S,1050*S),fill=110)
    im.paste(art,(-40*S,1370*S),mask)
    shadow_paste(im,phone('Weather-Artwork-Home.png',756),(211.5,765),blur=34,opacity=.19)
    seal(im,84,1950)
    footer(im,'在每一天的晴雨里，找到从容。')
    save(im,'01-weather-1179x2556.png','把天气，读成一卷山水。',['天气首页','逐小时天气','多日预报','空气质量'],['Weather-Artwork-Home.png','Scene-16.png'])
    del im

    # 02 — Gallery UI, supported by the original landscape works.
    im=canvas(1179,2556,'sage')
    brand(im,1179,'02 / 宋韵画境')
    headline(im,'五十幅画境，','每天都有新风景。','十组宋韵主题 · 自由选择心仪画境','山水可居，晴雨可赏')
    mountains(im,1710,.8)
    shadow_paste(im,painting('Scene-21.png',440,7),(-68,890),blur=16,opacity=.11)
    shadow_paste(im,painting('Scene-16.png',420,-7),(838,1190),blur=16,opacity=.11)
    shadow_paste(im,painting('Scene-46.png',430,5),(-58,1860),blur=16,opacity=.11)
    shadow_paste(im,phone('Weather-Artwork-Gallery.png',730),(224.5,790),blur=34,opacity=.19)
    seal(im,1012,2075,'画境')
    footer(im,'把喜欢的风景，留在每天。')
    save(im,'02-scenes-1179x2556.png','五十幅画境，每天都有新风景。',['50幅原创画境','10组宋韵主题','画境画廊'],['Weather-Artwork-Gallery.png','Scene-21.png','Scene-16.png','Scene-46.png'])
    del im

    # 03 — Forecast-map UI. No radar or real-time rain-stop claims.
    im=canvas(1179,2556,'blue')
    brand(im,1179,'03 / 晴雨地图')
    headline(im,'放眼晴雨，','看见天气的走向。','降水 · 气温 · 风速 · 云量','一城之间，一览晴雨')
    # Quiet contour rings suggest a wider field of view without imitating app UI.
    d=ImageDraw.Draw(im)
    for r in [470,650,840]:
     d.ellipse(((589-r)*S,(1630-r)*S,(589+r)*S,(1630+r)*S),outline='#cad7c9',width=S)
    shadow_paste(im,phone('Weather-Map-Layout-Phone.png',754),(212.5,765),blur=34,opacity=.19)
    seal(im,1012,1925,'晴雨')
    footer(im,'地图展示预报数据，非实时雷达。')
    save(im,'03-maps-1179x2556.png','放眼晴雨，看见天气的走向。',['天气地图','四种预报图层','时间轴'],['Weather-Map-Layout-Phone.png'])
    del im

    # 04 — Genuine exported widgets in their original aspect ratios.
    im=canvas(1179,2556,'sage')
    brand(im,1179,'04 / 桌面天气')
    headline(im,'抬眼之间，','天气就在桌面。','山水天气 · 带伞提醒 · 日出日落','日常所需，抬眼即见')
    mountains(im,1690,.6)
    shadow_paste(im,card('Widget-landscape-large.png',700,45),(87,790),blur=28,opacity=.13)
    # A vertical editorial caption makes room for the large widget without covering it.
    for i,c in enumerate('一方山水常伴左右'):
     text(im,(970,900+i*49),c,30,anchor='mt',fill='#698064')
    seal(im,949,1350,'日常')
    shadow_paste(im,card('Widget-rain-medium.png',866,62),(227,1585),blur=25,opacity=.12)
    text(im,(88,1715),'带',30,fill='#5f7b7b');text(im,(88,1763),'伞',30,fill='#5f7b7b')
    shadow_paste(im,card('Widget-daylight-medium.png',866,62),(87,2040),blur=25,opacity=.12)
    text(im,(1025,2155),'日',30,fill='#9b7a55');text(im,(1025,2203),'光',30,fill='#9b7a55')
    footer(im,'三种主题 · 小、中、大三种尺寸')
    save(im,'04-widgets-1179x2556.png','抬眼之间，天气就在桌面。',['山水天气','带伞提醒','日出日落','三种尺寸'],['Widget-landscape-large.png','Widget-rain-medium.png','Widget-daylight-medium.png'])
    del im

    # Landscape — Brand and product overview, composed for its own aspect ratio.
    im=canvas(2556,1179)
    brand(im,2556)
    text(im,(2395,95),'山水入怀，晴雨有时。',18,kind='sans',anchor='rt',fill=MUTED,tracking=3)
    mountains(im,850,.65)
    text(im,(92,240),'天气的清晰，山水的诗意。',24,kind='sans',fill=RED,tracking=3)
    text(im,(86,320),'把天气，',112,tracking=2)
    text(im,(86,465),'读成一卷山水。',112,tracking=2)
    text(im,(94,645),'清晰预报与东方画境，让每一天的出发多一分从容。',27,kind='sans',fill=MUTED)
    for x,label in [(94,'城市天气'),(316,'原创画境'),(538,'晴雨地图'),(760,'桌面组件')]:
     line(im,(x,752,x+145,752),'#9eae94')
     text(im,(x,780),label,25,kind='sans',fill='#52684e',tracking=2)
    text(im,(94,1011),'山水入怀，晴雨有时。',29,tracking=4,fill='#5b7056')
    text(im,(96,1065),'WEATHER, WITH A LITTLE POETRY.',13,kind='latin',fill=MUTED,tracking=2.3)
    # Three actual UI screens form a balanced device composition on the right.
    shadow_paste(im,phone('Weather-Artwork-Gallery.png',336,5),(1258,265),blur=22,opacity=.17)
    shadow_paste(im,phone('Weather-Map-Layout-Phone.png',346,-5),(2117,245),blur=22,opacity=.17)
    shadow_paste(im,phone('Weather-Artwork-Home.png',416),(1660,212),blur=28,opacity=.20)
    seal(im,2450,92,'晴雨')
    save(im,'05-overview-2556x1179.png','气象岛：天气的清晰，山水的诗意。',['天气首页','原创画境','天气地图','桌面小组件'],['Weather-Artwork-Gallery.png','Weather-Artwork-Home.png','Weather-Map-Layout-Phone.png'])
    del im

    (OUT/'manifest.json').write_text(json.dumps(MANIFEST,ensure_ascii=False,indent=2)+'\n')
    # Review contact sheet stays separate from the five full-resolution upload images.
    thumbs=Image.new('RGB',(1600,1210),'#e3e6db')
    d=ImageDraw.Draw(thumbs)
    label_font=ImageFont.truetype(SANS,20,index=1)
    for i,item in enumerate(MANIFEST[:4]):
     picture=Image.open(OUT/item['file']);picture.thumbnail((370,802),Image.Resampling.LANCZOS)
     x=16+i*398
     thumbs.paste(picture,(x,35));d.text((x,8),f'0{i+1}  ·  1179 × 2556',font=label_font,fill=INK)
    wide=Image.open(OUT/MANIFEST[4]['file']);wide.thumbnail((760,351),Image.Resampling.LANCZOS)
    thumbs.paste(wide,(420,850))
    thumbs.save(OUT/'preview.jpg',quality=93,icc_profile=PROFILE)
    with zipfile.ZipFile(OUT/'WeatherIsland-AppStore-5-Images.zip','w',zipfile.ZIP_DEFLATED) as archive:
     for item in MANIFEST:archive.write(OUT/item['file'],arcname=item['file'])
    print('Created review preview, manifest and ZIP containing exactly five PNGs.',flush=True)


def render_additional():
    # Two genuine city screens; no fabricated city cards or weather values.
    im=canvas(1179,2556,'blue')
    brand(im,1179,'06 / 城市天气')
    headline(im,'关心的城市，','都有一方晴空。','收藏城市 · 自由切换 · 手动选城','身边的日常，远方的牵挂')
    mountains(im,1710,.68)
    shadow_paste(im,phone('Weather-Artwork-Cities.png',570),(62,810),blur=30,opacity=.16)
    shadow_paste(im,phone('Weather-Home-Manual-City.png',650),(450,960),blur=32,opacity=.20)
    line(im,(91,2178,301,2178),'#a6b49f')
    text(im,(92,2220),'此刻的身边',32,tracking=3)
    text(im,(92,2272),'也有远方的晴雨',26,fill=MUTED,tracking=2)
    seal(im,94,2340,'远方')
    footer(im,'把在意的城市，放进自己的小岛。')
    save(im,'06-cities-1179x2556.png','关心的城市，都有一方晴空。',['城市收藏','城市切换','手动选城'],['Weather-Artwork-Cities.png','Weather-Home-Manual-City.png'])
    del im

    im=canvas(1179,2556,'sage')
    brand(im,1179,'07 / 晴雨画境')
    headline(im,'晴雨更迭，','山水各有意境。','十一种天气预览 · 选一幅心仪画境','一江山水，不同的天空')
    mountains(im,1770,.70)
    shadow_paste(im,phone('Weather-Artwork-Detail.png',650),(78,825),blur=34,opacity=.18)
    # Crop the actual app-exported effect previews, preserving their rendering.
    grid=asset('Weather-Effects-Grid.png')
    for crop,xy,label,number in [
        ((36,107,486,417),(765,1040),'晴天','01'),
        ((510,486,960,796),(765,1485),'大雨','02'),
        ((36,864,486,1175),(765,1930),'雷暴','03'),
    ]:
        piece=grid.crop(crop).resize((338*S,round((crop[3]-crop[1])*338*S/(crop[2]-crop[0]))),Image.Resampling.LANCZOS)
        framed=Image.new('RGB',(piece.width+12*S,piece.height+12*S),'#faf7ee')
        framed.paste(piece,(6*S,6*S))
        shadow_paste(im,framed,xy,blur=17,offset=(0,12),opacity=.12)
        text(im,(xy[0],xy[1]-52),label,29,tracking=3)
        text(im,(xy[0]+350,xy[1]-47),number,14,kind='latin',anchor='rt',fill=MUTED,tracking=2)
    footer(im,'天气效果为预览演示。')
    save(im,'07-weather-scenes-1179x2556.png','晴雨更迭，山水各有意境。',['11种天气预览','画境详情','画境选择'],['Weather-Artwork-Detail.png','Weather-Effects-Grid.png'])
    del im


def package_and_validate():
    import hashlib
    import io
    checks=[]
    for item in MANIFEST:
        path=OUT/item['file']
        with Image.open(path) as image:
            image.load()
            assert list(image.size)==item['size']
            assert image.format=='PNG' and image.mode=='RGB'
            assert image.info.get('icc_profile')
            checks.append({'file':path.name,'dimensions':list(image.size),'format':image.format,'mode':image.mode,'alpha':False,'sRGB_profile':'srgb' in ImageCms.getProfileDescription(ImageCms.ImageCmsProfile(io.BytesIO(image.info['icc_profile']))).lower(),'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
            assert checks[-1]['sRGB_profile']
    archives={}
    for name,items in [('WeatherIsland-AppStore-Additional-2-Images.zip',MANIFEST[5:]),('WeatherIsland-AppStore-7-Images.zip',MANIFEST)]:
        with zipfile.ZipFile(OUT/name,'w',zipfile.ZIP_DEFLATED) as archive:
            for item in items: archive.write(OUT/item['file'],arcname=item['file'])
        with zipfile.ZipFile(OUT/name) as archive:
            assert archive.testzip() is None
            assert archive.namelist()==[item['file'] for item in items]
            for item in items: assert archive.read(item['file'])==(OUT/item['file']).read_bytes()
        archives[name]={'passed':True,'image_count':len(items),'bytes':(OUT/name).stat().st_size}
    (OUT/'manifest.json').write_text(json.dumps(MANIFEST,ensure_ascii=False,indent=2)+'\n')
    (OUT/'validation.json').write_text(json.dumps({'passed':True,'images':checks,'archives':archives},ensure_ascii=False,indent=2)+'\n')
    thumbs=Image.new('RGB',(980,1120),'#e3e6db')
    for i,item in enumerate(MANIFEST[5:]):
        picture=Image.open(OUT/item['file']);picture.thumbnail((470,1020),Image.Resampling.LANCZOS)
        thumbs.paste(picture,(15+i*490,38))
    thumbs.save(OUT/'preview-additional.jpg',quality=94,icc_profile=PROFILE)
    print('Validated seven RGB PNGs and two ZIP archives.',flush=True)


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--additional-only',action='store_true',help='Keep the first five images and render only the two additions.')
    args=parser.parse_args()
    if args.additional_only:
        MANIFEST.extend(json.loads((OUT/'manifest.json').read_text())[:5])
        assert len(MANIFEST)==5
    else:
        render_original()
    render_additional()
    package_and_validate()
