const key = 'biketrack-design-shortlist';
let filter = 'all';
function readSaved() { try { const value = JSON.parse(localStorage.getItem(key) || '[]'); return Array.isArray(value) ? value.filter(x => typeof x === 'string') : []; } catch { return []; } }
function refresh() {
  const selected = readSaved();
  document.getElementById('saved-count').textContent = String(selected.length).padStart(2, '0');
  document.querySelectorAll('[data-favorite]').forEach(button => { const active = selected.includes(button.dataset.favorite); button.textContent = active ? '♥' : '♡'; button.setAttribute('aria-pressed', String(active)); });
  document.querySelectorAll('.concept-card').forEach(card => { card.hidden = filter === 'saved' && !selected.includes(card.dataset.id); });
  document.querySelector('.empty-state').hidden = filter !== 'saved' || selected.length > 0;
}
document.querySelectorAll('[data-favorite]').forEach(button => button.addEventListener('click', () => { const items = readSaved(), id = button.dataset.favorite; try { localStorage.setItem(key, JSON.stringify(items.includes(id) ? items.filter(x => x !== id) : [...items, id])); } catch { button.title = 'Your browser does not allow saving favorites.'; } refresh(); }));
document.querySelectorAll('[data-filter]').forEach(button => button.addEventListener('click', () => { filter = button.dataset.filter; document.querySelectorAll('[data-filter]').forEach(item => { item.classList.toggle('active', item === button); item.setAttribute('aria-pressed', String(item === button)); }); refresh(); }));
const toggle = document.querySelector('.compare-toggle');
toggle.addEventListener('click', () => { const open = toggle.getAttribute('aria-expanded') !== 'true'; toggle.setAttribute('aria-expanded', String(open)); document.getElementById('compare-panel').hidden = !open; if (open) { [0,1].forEach(n => updateFrame(n)); document.getElementById('compare-panel').scrollIntoView({ behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth', block: 'start' }); } });
function updateFrame(n) { const select = document.getElementById(`compare-${n}`), frame = document.getElementById(`frame-${n}`); const url = `./${select.value}/`; if (frame.getAttribute('src') !== url) frame.src = url; frame.title = `${select.selectedOptions[0].textContent} design comparison`; document.getElementById(`compare-link-${n}`).href = url; }
[0,1].forEach(n => document.getElementById(`compare-${n}`).addEventListener('change', () => updateFrame(n)));
window.addEventListener('storage', refresh);
window.addEventListener('pageshow', refresh);
refresh();
