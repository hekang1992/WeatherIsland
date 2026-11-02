'use strict';
(() => {
  const scenes = {
    river: { index: '01', title: '江渚烟岚', poem: ['一叶轻舟，', '驶入今日的好风景。'], alt: '江渚烟岚：岸边垂柳、江上一叶扁舟与远处淡淡山影' },
    mountains: { index: '16', title: '千里烟岚', poem: ['远山如黛，', '心事也渐渐舒展。'], alt: '千里烟岚：青绿山峦层叠，轻雾环绕山间' },
    lotus: { index: '21', title: '半池荷风', poem: ['荷风轻拂，', '把日子过得清凉。'], alt: '半池荷风：圆形画境中的荷叶、粉色莲花与细长花茎' },
    autumn: { index: '31', title: '平沙雁落', poem: ['天高云淡，', '且听远山的回响。'], alt: '平沙雁落：淡金色远山、芦苇与天空中飞过的雁群' },
    spring: { index: '46', title: '春畦新绿', poem: ['一畦新绿，', '万物都有新的开始。'], alt: '春畦新绿：春日树影、绿色田畦与山间的一座小亭' }
  };
  const tabs = [...document.querySelectorAll('[role="tab"]')];
  const panel = document.querySelector('#scene-panel');
  const image = document.querySelector('#scene-image');
  function select(tab) {
    const key = tab.dataset.scene;
    const scene = scenes[key];
    if (!scene) return;
    tabs.forEach(item => {
      const active = item === tab;
      item.setAttribute('aria-selected', String(active));
      item.tabIndex = active ? 0 : -1;
    });
    panel.setAttribute('aria-labelledby', tab.id);
    image.src = `assets/scene-${key}.webp`;
    image.alt = scene.alt;
    document.querySelector('#scene-title').textContent = scene.title;
    document.querySelector('#scene-index').textContent = scene.index;
    document.querySelector('#scene-poem').replaceChildren(document.createTextNode(scene.poem[0]), document.createElement('br'), document.createTextNode(scene.poem[1]));
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => select(tab));
    tab.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) {
        event.preventDefault();
        tabs[next].focus();
        select(tabs[next]);
      }
    });
  });
})();
