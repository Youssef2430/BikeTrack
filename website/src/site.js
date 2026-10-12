(() => {
  'use strict';
  document.documentElement.classList.add('js');
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)');

  if ('IntersectionObserver' in window && !reduceMotion.matches) {
    const reveals = new IntersectionObserver(entries => {
      for (const entry of entries) if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        reveals.unobserve(entry.target);
      }
    }, { threshold: 0.12 });
    document.querySelectorAll('.reveal').forEach(element => reveals.observe(element));
  } else {
    document.querySelectorAll('.reveal').forEach(element => element.classList.add('is-visible'));
  }

  const root = document.documentElement;
  const motion = !reduceMotion.matches;
  const finePointer = matchMedia('(hover: hover) and (pointer: fine)').matches;

  // Headings arrive word by word; "move" keeps a span of its own to react to the ribbon.
  document.querySelectorAll('.words').forEach(heading => {
    let index = 0;
    for (const child of [...heading.childNodes]) {
      if (child.nodeType === Node.TEXT_NODE) {
        const fragment = document.createDocumentFragment();
        for (const part of child.textContent.split(/(\s+)/)) {
          if (!part) continue;
          if (/^\s+$/.test(part)) { fragment.append(part); continue; }
          const word = document.createElement('span');
          word.className = 'w';
          word.style.setProperty('--i', index++);
          word.textContent = part;
          fragment.append(word);
        }
        child.replaceWith(fragment);
      } else if (child.classList.contains('move')) {
        child.classList.add('w');
        child.style.setProperty('--i', index++);
        child.innerHTML = `<span class="nudge">${child.textContent}</span>`;
      }
    }
  });

  // The headline rises letter by letter and stretches from condensed to wide as it lands.
  const headline = document.querySelector('.headline');
  const letters = [];
  if (headline) {
    headline.querySelectorAll('.word').forEach(word => {
      const text = word.textContent;
      word.textContent = '';
      [...text].forEach((character, position) => {
        const letter = document.createElement('span');
        letter.className = 'ch';
        letter.textContent = character;
        letter.style.setProperty('--i', letters.length);
        letter.style.setProperty('--j', position);
        word.append(letter);
        letters.push(letter);
      });
    });
  }
  const settle = () => { root.classList.remove('intro'); root.classList.add('settled'); };
  if (!motion || !letters.length) settle();
  else {
    const fontsReady = document.fonts ? Promise.race([document.fonts.ready, new Promise(done => setTimeout(done, 1200))]) : Promise.resolve();
    fontsReady.then(() => {
      root.classList.add('intro');
      letters.at(-1).addEventListener('animationend', settle, { once: true });
      setTimeout(settle, 3000);
    });
  }

  // With a mouse, letters near the cursor swell wider and heavier.
  if (motion && finePointer && headline) {
    const copy = document.querySelector('.hero-copy');
    let centres = [];
    let frame = 0;
    let pointer = [0, 0];
    const measure = () => {
      centres = letters.map(letter => {
        const bounds = letter.getBoundingClientRect();
        return [bounds.left + bounds.width / 2, bounds.top + bounds.height / 2];
      });
    };
    const paint = () => {
      frame = 0;
      letters.forEach((letter, index) => {
        const [x, y] = centres[index];
        const pull = Math.max(0, 1 - Math.hypot(pointer[0] - x, (pointer[1] - y) * 1.4) / 170);
        letter.style.setProperty('--s', `${112 + 13 * pull}%`);
        letter.style.setProperty('--w', String(Math.round(850 + 50 * pull)));
      });
    };
    copy.addEventListener('pointermove', event => {
      if (!root.classList.contains('settled')) return;
      pointer = [event.clientX, event.clientY];
      if (!centres.length) measure();
      if (!frame) frame = requestAnimationFrame(paint);
    });
    copy.addEventListener('pointerleave', () => {
      centres = [];
      letters.forEach(letter => { letter.style.removeProperty('--s'); letter.style.removeProperty('--w'); });
    });
    addEventListener('scroll', () => { centres = []; }, { passive: true });
    addEventListener('resize', () => { centres = []; }, { passive: true });
  }

  // The eyebrow boots like a dot-matrix display. Screen readers get the settled text.
  const boot = document.querySelector('.boot');
  if (boot) {
    const text = boot.textContent;
    const spoken = document.createElement('span');
    spoken.className = 'sr-only';
    spoken.textContent = text;
    boot.after(spoken);
    boot.setAttribute('aria-hidden', 'true');
    if (motion) {
      const pool = 'ZONE0123456789BPMW+:';
      const started = performance.now();
      const scramble = now => {
        const progress = Math.min(1, (now - started) / 1100);
        const settled = Math.floor(progress * text.length);
        boot.textContent = [...text].map((character, index) =>
          index < settled || character === ' ' ? character : pool[Math.floor(Math.random() * pool.length)]).join('');
        if (progress < 1) requestAnimationFrame(scramble);
      };
      requestAnimationFrame(scramble);
    }
  }

  // A demo readout that drifts like a real ride; the dot beats at the shown heart rate.
  const heartRate = document.querySelector('.hr b');
  const power = document.querySelector('.pw b');
  const pulse = document.querySelector('.pulse');
  if (heartRate && power && pulse) {
    let bpm = 139;
    let watts = 208;
    let trend = 1;
    pulse.style.setProperty('--beat', `${60 / bpm}s`);
    if (motion) setInterval(() => {
      if (document.hidden) return;
      if (Math.random() < 0.15) trend = -trend;
      bpm = Math.round(Math.min(162, Math.max(128, bpm + trend * Math.random() * 3)));
      watts = Math.round(Math.min(260, Math.max(170, watts + (Math.random() - 0.45) * 14 + trend * 3)));
      heartRate.textContent = bpm;
      power.textContent = watts;
      pulse.style.setProperty('--beat', `${60 / bpm}s`);
    }, 1000);
  }

  // The zone ribbon mirrors the Watch app: zones in order, the active one lit,
  // sliding right as effort rises and left as it falls.
  const ribbon = document.querySelector('.ribbon');
  if (!ribbon) return;
  const caption = document.querySelector('.zone-caption');
  const zones = [
    { id: 1, name: 'Recovery', color: '#57b5ff', range: '95–113 bpm' },
    { id: 2, name: 'Endurance', color: '#40d4b0', range: '114–132 bpm' },
    { id: 3, name: 'Aerobic', color: '#bafa05', range: '133–151 bpm' },
    { id: 4, name: 'Threshold', color: '#ffa824', range: '152–170 bpm' },
    { id: 5, name: 'Maximum', color: '#ff403b', range: '171+ bpm' }
  ];
  const glyphs = {
    Z: ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
    O: ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
    N: ['10001', '10001', '11001', '10101', '10011', '10001', '10001'],
    E: ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
    1: ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    2: ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    3: ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
    4: ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    5: ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    ' ': ['00', '00', '00', '00', '00', '00', '00']
  };

  function dotMatrix(text) {
    let cursor = 0;
    let dots = '';
    for (const character of text) {
      const rows = glyphs[character] || glyphs[' '];
      rows.forEach((row, y) => [...row].forEach((bit, x) => {
        if (bit === '1') dots += `<rect x="${cursor + x}" y="${y}" width=".92" height=".92" rx=".18"/>`;
      }));
      cursor += rows[0].length + 1;
    }
    return `<svg viewBox="0 0 ${cursor - 1} 7" fill="rgba(0,0,0,.8)" aria-hidden="true">${dots}</svg>`;
  }

  const ticks = new Map();
  for (const zone of zones) for (const half of ['a', 'b']) {
    const tick = document.createElement('span');
    tick.className = 'tick';
    tick.dataset.zone = zone.id;
    ribbon.append(tick);
    ticks.set(zone.id + half, tick);
  }
  const pill = document.createElement('span');
  pill.className = 'pill';
  pill.innerHTML = '<span class="face"></span><span class="pointer"></span>';
  ribbon.append(pill);
  const face = pill.querySelector('.face');

  let selected = 3;
  let label = null;

  function layout(rising) {
    const width = ribbon.clientWidth;
    const height = parseFloat(getComputedStyle(ribbon).getPropertyValue('--h')) || ribbon.clientHeight / 1.12;
    const pillWidth = height * 3.5;
    const pillGap = height * 0.1;
    const tickGap = height * 0.08;
    const entries = zones.flatMap(zone => zone.id === selected ? [null] : [zone.id + 'a', zone.id + 'b']);
    const pillIndex = entries.indexOf(null);
    const count = entries.length - 1;
    const pillGaps = (pillIndex > 0) + (pillIndex < count);
    const tickGaps = count - pillGaps;
    const tickWidth = Math.min(height * 0.36, Math.max(1, (width - pillWidth - pillGaps * pillGap - tickGaps * tickGap) / count));
    let x = Math.max(0, (width - pillWidth - count * tickWidth - pillGaps * pillGap - tickGaps * tickGap) / 2);
    let pillX = 0;
    entries.forEach((entry, index) => {
      if (index > 0) x += index === pillIndex || index - 1 === pillIndex ? pillGap : tickGap;
      if (entry === null) { pillX = x; x += pillWidth; return; }
      const tick = ticks.get(entry);
      const shade = Math.round(255 * Math.max(0.045, 0.21 * Math.pow(0.72, Math.abs(index - pillIndex) - 1)));
      tick.style.cssText = `width:${tickWidth}px;transform:translateX(${x}px);background-color:rgb(${shade},${shade},${shade});opacity:1`;
      x += tickWidth;
    });
    // The active zone's ticks fold away under the pill.
    for (const half of ['a', 'b']) {
      const tick = ticks.get(selected + half);
      tick.style.cssText = `width:${tickWidth}px;transform:translateX(${pillX + pillWidth / 2 - tickWidth / 2}px);background-color:#111;opacity:0`;
    }
    pill.style.width = `${pillWidth}px`;
    pill.style.transform = `translateX(${pillX}px)`;
    const zone = zones[selected - 1];
    face.style.backgroundColor = zone.color;
    if (rising !== undefined || !label) swapLabel(zone, rising);
  }

  function swapLabel(zone, rising) {
    const next = document.createElement('span');
    next.className = 'label';
    next.innerHTML = dotMatrix(`ZONE ${zone.id}`);
    const animate = label && rising !== undefined && !reduceMotion.matches;
    if (animate) next.style.transform = `translateX(${rising ? -100 : 100}%)`;
    face.append(next);
    if (label) {
      const previous = label;
      if (animate) {
        previous.style.transform = `translateX(${rising ? 100 : -100}%)`;
        previous.style.opacity = '0';
        setTimeout(() => previous.remove(), 600);
      } else previous.remove();
    }
    if (animate) requestAnimationFrame(() => requestAnimationFrame(() => { next.style.transform = 'none'; }));
    label = next;
    ribbon.setAttribute('aria-valuenow', zone.id);
    ribbon.setAttribute('aria-valuetext', `Zone ${zone.id}, ${zone.name}, ${zone.range}`);
    caption.innerHTML = `<strong style="color:${zone.color}">${zone.name}</strong> <span>${zone.range}</span>`;
  }

  const nudge = document.querySelector('.nudge');
  function select(id) {
    id = Math.min(zones.length, Math.max(1, id));
    if (id === selected) return;
    const rising = id > selected;
    selected = id;
    layout(rising);
    if (nudge && motion) {
      nudge.classList.remove('nudge-up', 'nudge-down');
      void nudge.offsetWidth;
      nudge.classList.add(rising ? 'nudge-up' : 'nudge-down');
    }
  }

  // A gentle demo ride: up through the zones, then back down, until someone takes over.
  const path = [3, 4, 5, 4, 3, 2, 1, 2];
  let step = 0;
  let timer = 0;
  function stopDemo() { clearInterval(timer); timer = 0; }
  if (!reduceMotion.matches) {
    timer = setInterval(() => {
      if (document.hidden) return;
      step = (step + 1) % path.length;
      select(path[step]);
    }, 2200);
  }

  ribbon.addEventListener('click', event => {
    stopDemo();
    const tick = event.target.closest('.tick');
    if (tick) return select(Number(tick.dataset.zone));
    const bounds = pill.getBoundingClientRect();
    if (event.clientX < bounds.left) select(selected - 1);
    else if (event.clientX > bounds.right) select(selected + 1);
  });
  ribbon.addEventListener('keydown', event => {
    const change = { ArrowLeft: -1, ArrowDown: -1, ArrowRight: 1, ArrowUp: 1 }[event.key];
    if (event.key === 'Home' || event.key === 'End') {
      event.preventDefault();
      stopDemo();
      select(event.key === 'Home' ? 1 : zones.length);
    } else if (change) {
      event.preventDefault();
      stopDemo();
      select(selected + change);
    }
  });
  addEventListener('resize', () => layout(), { passive: true });
  layout();
  requestAnimationFrame(() => ribbon.classList.add('ready'));
})();
