"use strict";
const form = document.getElementById('release-form');
const input = document.getElementById('release-code');
const release = document.getElementById('release');
const result = document.getElementById('result');
let submitting = false;
let idleTimer;

function updateInput() {
  input.value = input.value.replace(/[^0-9]/g, '').slice(0, 6);
  release.disabled = submitting || input.value.length !== 6;
  clearTimeout(idleTimer);
  if (input.value) idleTimer = setTimeout(() => { input.value = ''; updateInput(); }, 30000);
}
input.addEventListener('input', updateInput);
document.querySelectorAll('[data-digit]').forEach(button => {
  button.addEventListener('click', () => {
    if (!submitting) { input.value += button.dataset.digit; updateInput(); }
  });
});
document.getElementById('clear').addEventListener('click', () => {
  if (!submitting) { input.value = ''; result.textContent = ''; updateInput(); }
});
document.getElementById('backspace').addEventListener('click', () => {
  if (!submitting) { input.value = input.value.slice(0, -1); updateInput(); }
});
form.addEventListener('submit', async event => {
  event.preventDefault();
  if (submitting || !/^[0-9]{6}$/.test(input.value)) return;
  const otp = input.value;
  submitting = true;
  input.value = '';
  input.disabled = true;
  document.querySelectorAll('.keypad button').forEach(button => { button.disabled = true; });
  updateInput();
  result.className = '';
  result.textContent = 'Verifying...';
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25000);
  try {
    const response = await fetch('/local/release', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({otp}), signal: controller.signal, cache: 'no-store',
    });
    const data = await response.json();
    if (response.ok && data.status === 'RELEASED') {
      result.textContent = 'Print released. Check your order for progress.';
    } else {
      result.className = 'error';
      result.textContent = data.message || 'Unable to release print. Check your order status.';
    }
  } catch (_) {
    result.className = 'error';
    // A lost response may follow a committed release; never retry automatically.
    result.textContent = 'Release unconfirmed. Check your order status.';
  } finally {
    clearTimeout(timeout);
    submitting = false;
    input.disabled = false;
    document.querySelectorAll('.keypad button').forEach(button => { button.disabled = false; });
    updateInput();
  }
});
async function checkHealth() {
  const status = document.getElementById('station-status');
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch('/local/status', {cache: 'no-store', signal: controller.signal});
    if (!response.ok) throw new Error('unavailable');
    const data = await response.json();
    status.textContent = ({READY: 'Ready', BUSY: 'Busy', ERROR: 'Unavailable'})[data.printer_state] || 'Unavailable';
  } catch (_) { status.textContent = 'Unavailable'; }
  finally { clearTimeout(timeout); setTimeout(checkHealth, 10000); }
}
updateInput();
checkHealth();
