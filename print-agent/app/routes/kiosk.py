import os
from flask import Blueprint, render_template_string, redirect, url_for
from app.config import config

kiosk_bp = Blueprint("kiosk", __name__)

KIOSK_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Autonomous Print Station - Terminal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0b0f19;
      --surface: #111827;
      --surface-card: #162032;
      --border: #1f2d44;
      --border-focus: #3b82f6;
      --primary: #2563eb;
      --primary-hover: #1d4ed8;
      --primary-glow: rgba(37, 99, 235, 0.4);
      --accent: #06b6d4;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --text-dim: #64748b;
      --success: #10b981;
      --success-bg: rgba(16, 185, 129, 0.12);
      --danger: #ef4444;
      --danger-bg: rgba(239, 68, 68, 0.12);
      --warning: #f59e0b;
      --key-bg: #1a2538;
      --key-hover: #22324b;
      --key-active: #2e4363;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      user-select: none;
      -webkit-user-select: none;
      -webkit-touch-callout: none;
    }

    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      background: radial-gradient(circle at 50% 0%, #172554 0%, var(--bg) 65%);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      align-items: center;
      overflow-x: hidden;
      touch-action: manipulation;
    }

    /* Top Kiosk Header */
    header {
      width: 100%;
      background: rgba(15, 23, 42, 0.9);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border);
      padding: 14px 28px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 10;
    }

    .station-brand {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .brand-icon {
      width: 44px;
      height: 44px;
      background: linear-gradient(135deg, #2563eb, #06b6d4);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 16px var(--primary-glow);
    }

    .brand-icon svg {
      width: 24px;
      height: 24px;
      fill: #ffffff;
    }

    .brand-text h1 {
      font-size: 1.15rem;
      font-weight: 800;
      letter-spacing: -0.02em;
      color: #ffffff;
    }

    .brand-text p {
      font-size: 0.75rem;
      color: var(--text-muted);
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    .station-pills {
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      background: rgba(16, 185, 129, 0.1);
      border: 1px solid rgba(16, 185, 129, 0.3);
      padding: 6px 14px;
      border-radius: 9999px;
      font-size: 0.8rem;
      font-weight: 600;
      color: #34d399;
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #10b981;
      box-shadow: 0 0 10px #10b981;
      animation: pulseDot 2s infinite ease-in-out;
    }

    @keyframes pulseDot {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.4; transform: scale(0.85); }
    }

    .printer-model-badge {
      background: rgba(30, 41, 59, 0.8);
      border: 1px solid var(--border);
      padding: 6px 12px;
      border-radius: 9999px;
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--text-muted);
    }

    /* Main Terminal Workspace */
    main {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      width: 100%;
      max-width: 580px;
      padding: 16px 20px;
    }

    .kiosk-card {
      width: 100%;
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 24px 28px;
      box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5);
      position: relative;
    }

    .card-title-group {
      text-align: center;
      margin-bottom: 20px;
    }

    .card-title-group h2 {
      font-size: 1.5rem;
      font-weight: 800;
      letter-spacing: -0.02em;
      margin-bottom: 6px;
      color: #ffffff;
    }

    .card-title-group p {
      font-size: 0.88rem;
      color: var(--text-muted);
    }

    /* 6-Digit Display Slots */
    .otp-display-container {
      display: flex;
      justify-content: center;
      gap: 12px;
      margin-bottom: 22px;
    }

    .otp-slot {
      width: 54px;
      height: 64px;
      background: var(--surface-card);
      border: 2px solid var(--border);
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: 'JetBrains Mono', monospace;
      font-size: 1.9rem;
      font-weight: 700;
      color: #ffffff;
      box-shadow: inset 0 2px 4px rgba(0,0,0,0.3);
      transition: all 0.15s ease;
    }

    .otp-slot.filled {
      border-color: var(--primary-light, #3b82f6);
      background: rgba(37, 99, 235, 0.12);
      color: #60a5fa;
      transform: scale(1.02);
    }

    .otp-slot.active {
      border-color: var(--accent);
      box-shadow: 0 0 12px rgba(6, 182, 212, 0.4);
    }

    /* Alert / Status Banners */
    .alert-banner {
      display: none;
      padding: 12px 16px;
      border-radius: 12px;
      margin-bottom: 18px;
      text-align: center;
      animation: slideIn 0.25s ease-out;
    }

    @keyframes slideIn {
      from { opacity: 0; transform: translateY(-8px); }
      to { opacity: 1; transform: translateY(0); }
    }

    .alert-banner.error {
      display: block;
      background: var(--danger-bg);
      border: 1px solid rgba(239, 68, 68, 0.35);
      color: #fca5a5;
    }

    .alert-banner.error h3 {
      font-size: 0.95rem;
      font-weight: 700;
      color: #f87171;
      margin-bottom: 3px;
    }

    .alert-banner.error p {
      font-size: 0.82rem;
      color: #fca5a5;
    }

    .alert-banner.success {
      display: block;
      background: var(--success-bg);
      border: 1px solid rgba(16, 185, 129, 0.35);
      color: #86efac;
    }

    .alert-banner.success h3 {
      font-size: 0.95rem;
      font-weight: 700;
      color: #34d399;
      margin-bottom: 3px;
    }

    .alert-banner.success p {
      font-size: 0.82rem;
      color: #a7f3d0;
    }

    /* Keypad Grid */
    .keypad-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 10px;
      margin-bottom: 18px;
    }

    .key-btn {
      background: var(--key-bg);
      border: 1px solid var(--border);
      border-radius: 14px;
      height: 60px;
      font-size: 1.45rem;
      font-weight: 700;
      color: #ffffff;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.12s ease;
      touch-action: manipulation;
    }

    .key-btn:hover {
      background: var(--key-hover);
      border-color: rgba(255, 255, 255, 0.15);
    }

    .key-btn:active {
      background: var(--key-active);
      transform: scale(0.96);
    }

    .key-btn.action-btn {
      font-size: 0.88rem;
      font-weight: 700;
      letter-spacing: 0.03em;
      color: var(--text-muted);
    }

    .key-btn.action-btn:hover {
      color: #ffffff;
    }

    .key-btn.clear-btn:active {
      background: rgba(239, 68, 68, 0.2);
      border-color: var(--danger);
      color: #f87171;
    }

    .key-btn svg {
      width: 22px;
      height: 22px;
      fill: currentColor;
    }

    /* Primary Print Button */
    .print-btn {
      width: 100%;
      height: 58px;
      background: linear-gradient(135deg, #2563eb, #1d4ed8);
      border: none;
      border-radius: 14px;
      color: #ffffff;
      font-size: 1.1rem;
      font-weight: 800;
      letter-spacing: 0.02em;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      box-shadow: 0 4px 18px var(--primary-glow);
      transition: all 0.2s ease;
      touch-action: manipulation;
    }

    .print-btn:hover:not(:disabled) {
      background: linear-gradient(135deg, #3b82f6, #2563eb);
      box-shadow: 0 6px 24px rgba(37, 99, 235, 0.5);
      transform: translateY(-1px);
    }

    .print-btn:active:not(:disabled) {
      transform: scale(0.98);
    }

    .print-btn:disabled {
      background: #1e293b;
      color: var(--text-dim);
      box-shadow: none;
      cursor: not-allowed;
      border: 1px solid var(--border);
    }

    .print-btn svg {
      width: 22px;
      height: 22px;
      fill: currentColor;
    }

    /* Spinner in Button / Overlay */
    .spinner {
      width: 22px;
      height: 22px;
      border: 3px solid rgba(255, 255, 255, 0.25);
      border-top-color: #ffffff;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    /* Fullscreen Modal / Progress Overlay */
    .modal-overlay {
      display: none;
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(11, 15, 25, 0.85);
      backdrop-filter: blur(10px);
      z-index: 100;
      align-items: center;
      justify-content: center;
      animation: fadeIn 0.2s ease;
    }

    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    .modal-content {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 24px;
      padding: 36px 40px;
      text-align: center;
      max-width: 440px;
      width: 90%;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.7);
    }

    .modal-icon-wrap {
      width: 80px;
      height: 80px;
      margin: 0 auto 20px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .modal-icon-wrap.loading {
      background: rgba(37, 99, 235, 0.15);
      border: 2px solid rgba(37, 99, 235, 0.3);
    }

    .modal-icon-wrap.success {
      background: rgba(16, 185, 129, 0.15);
      border: 2px solid rgba(16, 185, 129, 0.3);
    }

    .modal-icon-wrap.loading .spinner {
      width: 38px;
      height: 38px;
      border-width: 4px;
      border-top-color: #3b82f6;
    }

    .modal-icon-wrap svg {
      width: 44px;
      height: 44px;
    }

    .modal-content h3 {
      font-size: 1.45rem;
      font-weight: 800;
      margin-bottom: 8px;
      color: #ffffff;
    }

    .modal-content p {
      font-size: 0.95rem;
      color: var(--text-muted);
      line-height: 1.5;
    }

    .countdown-pill {
      display: inline-block;
      margin-top: 18px;
      padding: 6px 16px;
      background: rgba(255, 255, 255, 0.06);
      border-radius: 9999px;
      font-size: 0.8rem;
      font-weight: 600;
      color: var(--text-dim);
    }

    /* Footer Note */
    footer {
      width: 100%;
      text-align: center;
      padding: 14px 20px;
      font-size: 0.78rem;
      color: var(--text-dim);
      border-top: 1px solid rgba(31, 45, 68, 0.4);
    }

    /* Responsive adjustments for 1024x768 */
    @media (max-height: 800px) {
      header { padding: 10px 24px; }
      .brand-icon { width: 38px; height: 38px; }
      .kiosk-card { padding: 18px 24px; }
      .card-title-group { margin-bottom: 14px; }
      .card-title-group h2 { font-size: 1.35rem; }
      .otp-slot { width: 48px; height: 56px; font-size: 1.65rem; }
      .key-btn { height: 52px; font-size: 1.3rem; }
      .print-btn { height: 52px; font-size: 1.02rem; }
      footer { padding: 10px 16px; }
    }
  </style>
</head>
<body oncontextmenu="return false;">

  <!-- Header -->
  <header>
    <div class="station-brand">
      <div class="brand-icon">
        <svg viewBox="0 0 24 24">
          <path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/>
        </svg>
      </div>
      <div class="brand-text">
        <h1>AUTONOMOUS PRINT STATION</h1>
        <p>Self-Service Instant Release Terminal</p>
      </div>
    </div>

    <div class="station-pills">
      <span class="printer-model-badge">{{ printer_name }}</span>
      <div class="status-badge" id="stationStatusBadge">
        <span class="status-dot" id="stationStatusDot"></span>
        <span id="stationStatusText">READY</span>
      </div>
    </div>
  </header>

  <!-- Main Kiosk Body -->
  <main>
    <div class="kiosk-card">
      <div class="card-title-group">
        <h2>Enter your 6-digit OTP</h2>
        <p>Enter the OTP received after completing payment.</p>
      </div>

      <!-- Alert Banner for Errors or Notices -->
      <div class="alert-banner" id="alertBanner">
        <h3 id="alertTitle">Invalid OTP</h3>
        <p id="alertMessage">Please check the OTP and try again.</p>
      </div>

      <!-- 6 OTP Slots -->
      <div class="otp-display-container" id="otpSlotsContainer">
        <div class="otp-slot active" data-index="0">_</div>
        <div class="otp-slot" data-index="1">_</div>
        <div class="otp-slot" data-index="2">_</div>
        <div class="otp-slot" data-index="3">_</div>
        <div class="otp-slot" data-index="4">_</div>
        <div class="otp-slot" data-index="5">_</div>
      </div>

      <!-- Touch Keypad -->
      <div class="keypad-grid">
        <button type="button" class="key-btn" onclick="pressDigit('1')">1</button>
        <button type="button" class="key-btn" onclick="pressDigit('2')">2</button>
        <button type="button" class="key-btn" onclick="pressDigit('3')">3</button>

        <button type="button" class="key-btn" onclick="pressDigit('4')">4</button>
        <button type="button" class="key-btn" onclick="pressDigit('5')">5</button>
        <button type="button" class="key-btn" onclick="pressDigit('6')">6</button>

        <button type="button" class="key-btn" onclick="pressDigit('7')">7</button>
        <button type="button" class="key-btn" onclick="pressDigit('8')">8</button>
        <button type="button" class="key-btn" onclick="pressDigit('9')">9</button>

        <button type="button" class="key-btn action-btn clear-btn" onclick="clearOTP()">CLEAR</button>
        <button type="button" class="key-btn" onclick="pressDigit('0')">0</button>
        <button type="button" class="key-btn action-btn" onclick="backspaceOTP()">
          <svg viewBox="0 0 24 24">
            <path d="M22 3H7c-.69 0-1.23.35-1.59.88L0 12l5.41 8.11c.36.53.9.89 1.59.89h15c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-3 12.59L17.59 17 14 13.41 10.41 17 9 15.59 12.59 12 9 8.41 10.41 7 14 10.59 17.59 7 19 8.41 15.41 12 19 15.59z"/>
          </svg>
        </button>
      </div>

      <!-- Action Button -->
      <button type="button" class="print-btn" id="printBtn" onclick="submitOTP()" disabled>
        <svg viewBox="0 0 24 24">
          <path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/>
        </svg>
        <span>PRINT DOCUMENT</span>
      </button>
    </div>
  </main>

  <!-- Interactive Modal / Overlay for Verifying & Printing states -->
  <div class="modal-overlay" id="statusModal">
    <div class="modal-content">
      <div class="modal-icon-wrap loading" id="modalIconWrap">
        <div class="spinner" id="modalSpinner"></div>
        <svg viewBox="0 0 24 24" id="modalCheckIcon" style="display:none; fill:#10b981;">
          <path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>
        </svg>
      </div>
      <h3 id="modalTitle">OTP Verified</h3>
      <p id="modalMessage">Printing...</p>
      <div class="countdown-pill" id="modalCountdown" style="display:none;">Resetting in 8s...</div>
    </div>
  </div>

  <!-- Footer -->
  <footer>
    Hardware Queue: {{ printer_name }} &bull; Station ID: {{ agent_id }} &bull; Local Print Node
  </footer>

  <script>
    // State
    let currentOtp = "";
    let isSubmitting = false;
    let autoResetTimer = null;
    let inactivityTimer = null;

    const slots = document.querySelectorAll('.otp-slot');
    const printBtn = document.getElementById('printBtn');
    const alertBanner = document.getElementById('alertBanner');
    const alertTitle = document.getElementById('alertTitle');
    const alertMessage = document.getElementById('alertMessage');
    const statusModal = document.getElementById('statusModal');
    const modalIconWrap = document.getElementById('modalIconWrap');
    const modalSpinner = document.getElementById('modalSpinner');
    const modalCheckIcon = document.getElementById('modalCheckIcon');
    const modalTitle = document.getElementById('modalTitle');
    const modalMessage = document.getElementById('modalMessage');
    const modalCountdown = document.getElementById('modalCountdown');

    // Touch & Keyboard inputs
    function pressDigit(d) {
      if (isSubmitting || currentOtp.length >= 6) return;
      currentOtp += d;
      updateDisplay();
      resetInactivityTimer();
    }

    function backspaceOTP() {
      if (isSubmitting || currentOtp.length === 0) return;
      currentOtp = currentOtp.slice(0, -1);
      updateDisplay();
      resetInactivityTimer();
    }

    function clearOTP() {
      if (isSubmitting) return;
      currentOtp = "";
      hideAlert();
      updateDisplay();
      resetInactivityTimer();
    }

    function updateDisplay() {
      hideAlert();
      slots.forEach((slot, index) => {
        if (index < currentOtp.length) {
          slot.textContent = currentOtp[index];
          slot.classList.add('filled');
          slot.classList.remove('active');
        } else if (index === currentOtp.length) {
          slot.textContent = '_';
          slot.classList.remove('filled');
          slot.classList.add('active');
        } else {
          slot.textContent = '_';
          slot.classList.remove('filled', 'active');
        }
      });

      printBtn.disabled = (currentOtp.length !== 6 || isSubmitting);
    }

    function showAlert(title, message, isError = true) {
      alertTitle.textContent = title;
      alertMessage.textContent = message;
      alertBanner.className = 'alert-banner ' + (isError ? 'error' : 'success');
      alertBanner.style.display = 'block';

      if (isError) {
        // Auto hide error banner after 6 seconds
        clearTimeout(alertBanner._timeout);
        alertBanner._timeout = setTimeout(hideAlert, 6000);
      }
    }

    function hideAlert() {
      alertBanner.style.display = 'none';
    }

    function resetInactivityTimer() {
      clearTimeout(inactivityTimer);
      if (currentOtp.length > 0) {
        inactivityTimer = setTimeout(() => {
          if (!isSubmitting) {
            clearOTP();
          }
        }, 30000); // 30s inactivity resets screen
      }
    }

    // Physical Keyboard Support
    window.addEventListener('keydown', (e) => {
      if (isSubmitting) return;
      if (e.key >= '0' && e.key <= '9') {
        pressDigit(e.key);
      } else if (e.key === 'Backspace') {
        backspaceOTP();
      } else if (e.key === 'Escape' || e.key === 'c' || e.key === 'C') {
        clearOTP();
      } else if (e.key === 'Enter') {
        if (currentOtp.length === 6) {
          submitOTP();
        }
      }
    });

    // Verification & Print Release Flow
    async function submitOTP() {
      if (currentOtp.length !== 6 || isSubmitting) return;
      isSubmitting = true;
      printBtn.disabled = true;
      hideAlert();

      // Show verifying modal
      modalIconWrap.className = 'modal-icon-wrap loading';
      modalSpinner.style.display = 'block';
      modalCheckIcon.style.display = 'none';
      modalTitle.textContent = 'OTP Verified';
      modalMessage.textContent = 'Printing...';
      modalCountdown.style.display = 'none';
      statusModal.style.display = 'flex';

      try {
        const response = await fetch('/local/release', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ otp: currentOtp })
        });

        const data = await response.json().catch(() => ({}));

        if (response.ok && data.status === 'RELEASED') {
          // Success state
          modalIconWrap.className = 'modal-icon-wrap success';
          modalSpinner.style.display = 'none';
          modalCheckIcon.style.display = 'block';
          modalTitle.textContent = 'Printing Started';
          modalMessage.textContent = 'Please collect your document.';
          modalCountdown.style.display = 'inline-block';

          // Countdown to reset terminal
          let secondsLeft = 8;
          modalCountdown.textContent = `Resetting screen in ${secondsLeft}s...`;
          const countdownInterval = setInterval(() => {
            secondsLeft -= 1;
            if (secondsLeft > 0) {
              modalCountdown.textContent = `Resetting screen in ${secondsLeft}s...`;
            } else {
              clearInterval(countdownInterval);
              resetTerminal();
            }
          }, 1000);

        } else {
          // Failure handling matching requirements exactly
          statusModal.style.display = 'none';
          isSubmitting = false;

          const errCode = data.error || 'ERROR';
          let errTitle = 'Invalid OTP';
          let errMsg = 'Please check the OTP and try again.';

          if (errCode === 'OTP_EXPIRED') {
            errTitle = 'OTP Expired';
            errMsg = 'Please generate/request a new OTP.';
          } else if (errCode === 'ORDER_ALREADY_COMPLETED') {
            errTitle = 'Already Printed';
            errMsg = 'This order has already been printed.';
          } else if (errCode === 'ORDER_PRINTING') {
            errTitle = 'Printing in Progress';
            errMsg = 'This order is currently printing. Please collect your document.';
          } else if (errCode === 'PRINTER_OFFLINE') {
            errTitle = 'Printer Offline';
            errMsg = data.message || 'Printer is currently offline. Please notify attendant.';
          } else if (errCode === 'BACKEND_UNAVAILABLE' || response.status === 503) {
            errTitle = 'System Unavailable';
            errMsg = 'Print server is temporarily unavailable. Please try again.';
          } else if (errCode === 'NETWORK_TIMEOUT' || response.status === 504) {
            errTitle = 'Network Timeout';
            errMsg = 'The verification request timed out. Please try again.';
          } else if (errCode === 'TOO_MANY_ATTEMPTS') {
            errTitle = 'Attempts Exceeded';
            errMsg = 'Maximum OTP attempts exceeded. Please generate/request a new OTP.';
          } else {
            errMsg = data.message || 'Please check the OTP and try again.';
          }

          showAlert(errTitle, errMsg, true);
          currentOtp = "";
          updateDisplay();
        }
      } catch (err) {
        // Network or local agent offline
        statusModal.style.display = 'none';
        isSubmitting = false;
        showAlert('Connection Error', 'Local print station cannot communicate with service.', true);
        currentOtp = "";
        updateDisplay();
      }
    }

    function resetTerminal() {
      clearTimeout(autoResetTimer);
      clearTimeout(inactivityTimer);
      currentOtp = "";
      isSubmitting = false;
      statusModal.style.display = 'none';
      hideAlert();
      updateDisplay();
    }

    // Live status polling every 10 seconds
    async function checkPrinterHealth() {
      try {
        const res = await fetch('/local/status');
        if (res.ok) {
          const data = await res.json();
          const dot = document.getElementById('stationStatusDot');
          const txt = document.getElementById('stationStatusText');
          if (data.printer_state === 'READY') {
            dot.style.background = '#10b981';
            txt.textContent = 'READY';
          } else if (data.printer_state === 'BUSY') {
            dot.style.background = '#f59e0b';
            txt.textContent = 'BUSY';
          } else {
            dot.style.background = '#ef4444';
            txt.textContent = 'ATTENTION';
          }
        }
      } catch (e) {
        // Local agent offline
      }
    }
    setInterval(checkPrinterHealth, 10000);

    // Initial render
    updateDisplay();
  </script>
</body>
</html>
"""

@kiosk_bp.route("/kiosk", methods=["GET"])
def render_kiosk():
    return render_template_string(
        KIOSK_HTML,
        printer_name=config.PRINTER_NAME,
        agent_id=config.AGENT_ID
    )

@kiosk_bp.route("/", methods=["GET"])
def index():
    return redirect(url_for("kiosk.render_kiosk"))
