(() => {
  'use strict';
  const root = document.documentElement;
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');
  const motionButton = document.querySelector('.motion-toggle');
  let paused = reduceMotion.matches;
  try { paused = paused || localStorage.getItem('biketrack-motion-paused') === 'true'; } catch { /* Storage is optional. */ }

  const motionAllowed = () => !paused && !reduceMotion.matches;
  function syncMotion() {
    root.classList.toggle('motion-paused', !motionAllowed());
    root.classList.toggle('js-motion', motionAllowed());
    motionButton.setAttribute('aria-pressed', String(!motionAllowed()));
    const label = !motionAllowed() ? 'Enable decorative motion' : 'Pause decorative motion';
    motionButton.setAttribute('aria-label', label);
    motionButton.title = label;
    motionButton.querySelector('path').setAttribute('d', !motionAllowed() ? 'm6 3 10 7-10 7Z' : 'M7 4v12M13 4v12');
    if (!motionAllowed()) document.querySelectorAll('.reveal').forEach(element => element.classList.add('is-visible'));
  }
  motionButton.addEventListener('click', () => {
    if (reduceMotion.matches) {
      // The operating-system accessibility preference always takes precedence.
      paused = true;
      motionButton.title = 'Reduced motion is enabled in your device settings';
      return;
    }
    paused = !paused;
    try { localStorage.setItem('biketrack-motion-paused', String(paused)); } catch { /* Keep the preference for this visit. */ }
    syncMotion();
  });
  reduceMotion.addEventListener('change', syncMotion);
  syncMotion();

  if ('IntersectionObserver' in window) {
    const reveals = new IntersectionObserver(entries => {
      for (const entry of entries) if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        reveals.unobserve(entry.target);
      }
    }, { threshold: 0.1, rootMargin: '0px 0px -25px 0px' });
    document.querySelectorAll('.reveal').forEach(element => reveals.observe(element));
  } else {
    document.querySelectorAll('.reveal').forEach(element => element.classList.add('is-visible'));
  }

  const hero = document.querySelector('.hero');
  const art = document.querySelector('.hero-art');
  const device = document.querySelector('.hero-device-wrap');
  const progress = document.querySelector('.reading-progress');
  let frame = 0;
  let pointerX = 0;
  let pointerY = 0;
  function paint() {
    frame = 0;
    const total = document.documentElement.scrollHeight - innerHeight;
    progress.style.transform = `scaleX(${total > 0 ? Math.min(1, scrollY / total) : 0})`;
    if (motionAllowed() && finePointer.matches && innerWidth > 680) {
      const offset = -Math.min(scrollY, hero.offsetHeight) * 0.025;
      device.style.transform = `translate3d(${pointerX * 10}px, ${offset + pointerY * 8}px, 0) rotate(${pointerX * 2}deg)`;
    } else {
      device.style.removeProperty('transform');
    }
  }
  function queuePaint() { if (!frame) frame = requestAnimationFrame(paint); }
  addEventListener('scroll', queuePaint, { passive: true });
  addEventListener('resize', queuePaint, { passive: true });
  art.addEventListener('pointermove', event => {
    if (!motionAllowed() || !finePointer.matches) return;
    const bounds = art.getBoundingClientRect();
    pointerX = ((event.clientX - bounds.left) / bounds.width - 0.5) * 2;
    pointerY = ((event.clientY - bounds.top) / bounds.height - 0.5) * 2;
    queuePaint();
  });
  art.addEventListener('pointerleave', () => { pointerX = 0; pointerY = 0; queuePaint(); });
  queuePaint();

  const menuToggle = document.querySelector('.menu-toggle');
  const mobileMenu = document.querySelector('.mobile-nav');
  function setMenu(open) {
    menuToggle.setAttribute('aria-expanded', String(open));
    menuToggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
    mobileMenu.hidden = !open;
  }
  menuToggle.addEventListener('click', () => setMenu(menuToggle.getAttribute('aria-expanded') !== 'true'));
  mobileMenu.querySelectorAll('a').forEach(link => link.addEventListener('click', () => setMenu(false)));
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && !mobileMenu.hidden) { setMenu(false); menuToggle.focus(); } });
  document.addEventListener('click', event => { if (!mobileMenu.hidden && !event.target.closest('.header')) setMenu(false); });
  window.matchMedia('(max-width: 680px)').addEventListener('change', event => { if (!event.matches) setMenu(false); });

  const tabs = [...document.querySelectorAll('[data-screen]')];
  const screens = [...document.querySelectorAll('[data-view]')];
  function activateTab(tab, focus = false) {
    const active = tab.dataset.screen;
    tabs.forEach((button, index) => {
      const selected = button === tab;
      button.setAttribute('aria-selected', String(selected));
      button.tabIndex = selected ? 0 : -1;
      document.getElementById(button.getAttribute('aria-controls')).hidden = !selected;
      if (selected) document.getElementById('screen-counter').textContent = String(index + 1).padStart(2, '0');
    });
    screens.forEach(screen => {
      const selected = screen.dataset.view === active;
      screen.classList.toggle('active', selected);
      screen.setAttribute('aria-hidden', String(!selected));
    });
    if (focus) tab.focus();
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => activateTab(tab));
    tab.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowDown' || event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) { event.preventDefault(); activateTab(tabs[next], true); }
    });
  });

  const zones = {
    1: { value: 105, name: 'Recovery', range: '50–60% OF MAX HR', description: 'A clearer view of your lighter efforts.' },
    2: { value: 124, name: 'Endurance', range: '60–70% OF MAX HR', description: 'The rhythm of a steady session.' },
    3: { value: 145, name: 'Aerobic', range: '70–80% OF MAX HR', description: 'The shape of a sustained effort.' },
    4: { value: 161, name: 'Threshold', range: '80–90% OF MAX HR', description: 'Those moments when the effort rises.' },
    5: { value: 180, name: 'Maximum', range: '90%+ OF MAX HR', description: 'Your highest efforts, in context.' }
  };
  let numberAnimation;
  const zoneValue = document.getElementById('zone-value');
  document.querySelectorAll('[data-zone]').forEach(button => button.addEventListener('click', () => {
    const id = button.dataset.zone;
    const zone = zones[id];
    document.querySelectorAll('[data-zone]').forEach(other => other.setAttribute('aria-pressed', String(other === button)));
    document.querySelector('.zone-card').style.setProperty('--zone-accent', button.style.getPropertyValue('--zone-color'));
    document.getElementById('zone-number').textContent = `ZONE ${id}`;
    document.getElementById('zone-name').textContent = zone.name;
    document.getElementById('zone-description').textContent = zone.description;
    document.getElementById('zone-range').textContent = zone.range;
    if (numberAnimation) cancelAnimationFrame(numberAnimation);
    if (!motionAllowed()) { zoneValue.textContent = zone.value; return; }
    const from = Number(zoneValue.textContent);
    const start = performance.now();
    function tick(now) {
      const t = Math.min((now - start) / 380, 1);
      const eased = 1 - (1 - t) ** 3;
      zoneValue.textContent = Math.round(from + (zone.value - from) * eased);
      if (t < 1) numberAnimation = requestAnimationFrame(tick);
    }
    numberAnimation = requestAnimationFrame(tick);
  }));

  // Animate actual measured FAQ height, retaining native details/summary semantics.
  document.querySelectorAll('.faq details').forEach(details => {
    const summary = details.querySelector('summary');
    let animation = null;
    let targetOpen = details.open;
    summary.addEventListener('click', event => {
      if (!motionAllowed() || !details.animate) return;
      event.preventDefault();
      const startHeight = details.getBoundingClientRect().height;
      if (animation) { animation.onfinish = null; animation.cancel(); }
      targetOpen = !targetOpen;
      if (targetOpen) details.open = true;
      const endHeight = targetOpen ? details.scrollHeight : summary.getBoundingClientRect().height;
      animation = details.animate([{ height: `${startHeight}px` }, { height: `${endHeight}px` }], { duration: 320, easing: 'cubic-bezier(.22, 1, .36, 1)' });
      animation.onfinish = () => { details.open = targetOpen; animation = null; queuePaint(); };
    });
    details.addEventListener('toggle', () => { if (!animation) targetOpen = details.open; });
  });
})();
