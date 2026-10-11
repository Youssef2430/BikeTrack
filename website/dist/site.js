const storageKey = 'biketrack-design-shortlist';
function saved() { try { const value = JSON.parse(localStorage.getItem(storageKey) || '[]'); return Array.isArray(value) ? value.filter(x => typeof x === 'string') : []; } catch { return []; } }
function updateFavorites() { document.querySelectorAll('[data-favorite]').forEach(button => { const active = saved().includes(button.dataset.favorite); button.setAttribute('aria-pressed', String(active)); button.innerHTML = `${active ? '♥' : '♡'} <span>${active ? 'Shortlisted' : 'Shortlist'}</span>`; }); }
document.querySelectorAll('[data-favorite]').forEach(button => button.addEventListener('click', () => { const values = saved(); const id = button.dataset.favorite; try { localStorage.setItem(storageKey, JSON.stringify(values.includes(id) ? values.filter(x => x !== id) : [...values, id])); } catch { button.innerHTML = 'Storage unavailable'; } updateFavorites(); }));
window.addEventListener('storage', updateFavorites);
updateFavorites();

const tabs = [...document.querySelectorAll('[data-screen]')];
function activateTab(button, focus = false) {
  tabs.forEach(tab => { const active = tab === button; tab.setAttribute('aria-selected', String(active)); tab.tabIndex = active ? 0 : -1; document.getElementById(tab.getAttribute('aria-controls')).hidden = !active; });
  const img = document.querySelector('.experience-watch img');
  img.src = `../assets/${button.dataset.screen}.png`;
  img.alt = `BikeTrack ${button.dataset.screen} screen showing simulated demo workout data`;
  if (focus) button.focus();
}
tabs.forEach((button, i) => {
  button.addEventListener('click', () => activateTab(button));
  button.addEventListener('keydown', event => {
    let target;
    if (event.key === 'ArrowDown' || event.key === 'ArrowRight') target = (i + 1) % tabs.length;
    if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') target = (i + tabs.length - 1) % tabs.length;
    if (event.key === 'Home') target = 0;
    if (event.key === 'End') target = tabs.length - 1;
    if (target !== undefined) { event.preventDefault(); activateTab(tabs[target], true); }
  });
});
const data = { power: { value: '208', unit: 'W', label: 'POWER / ZONE 3', screen: 'power' }, heart: { value: '145', unit: 'BPM', label: 'HEART RATE / ZONE 3', screen: 'heart' }, cadence: { value: '86', unit: 'RPM', label: 'CADENCE / PEDAL RHYTHM', screen: 'live' } };
document.querySelectorAll('[data-metric]').forEach(button => button.addEventListener('click', () => {
  const metric = data[button.dataset.metric];
  document.querySelectorAll('[data-metric]').forEach(other => other.setAttribute('aria-pressed', String(other === button)));
  document.getElementById('metric-value').textContent = metric.value;
  document.getElementById('metric-unit').textContent = metric.unit;
  document.getElementById('metric-label').textContent = metric.label;
  const img = document.querySelector('.dashboard-watch img');
  img.src = `../assets/${metric.screen}.png`;
  img.alt = `BikeTrack ${metric.screen} screen showing simulated demo workout data`;
  document.querySelector('.metric-dashboard').dataset.active = button.dataset.metric;
}));
if (window.self !== window.top) document.body.classList.add('embedded');
