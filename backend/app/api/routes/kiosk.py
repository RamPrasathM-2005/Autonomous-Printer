from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["Kiosk"])

KIOSK_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Print Kiosk Touchscreen Terminal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #090d16;
      --card-bg: #111827;
      --card-border: #1f293d;
      --primary: #2563eb;
      --primary-light: #3b82f6;
      --primary-glow: rgba(59, 130, 246, 0.35);
      --accent: #06b6d4;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --success: #10b981;
      --danger: #ef4444;
      --key-bg: #1e293b;
      --key-hover: #334155;
      --key-active: #475569;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      user-select: none;
      -webkit-user-select: none;
    }

    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, sans-serif;
      background: radial-gradient(circle at 50% 0%, #172554 0%, var(--bg) 70%);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      overflow-x: hidden;
    }

    /* Kiosk Header Bar */
    header {
      width: 100%;
      background: rgba(15, 23, 42, 0.85);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--card-border);
      padding: 16px 32px;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .kiosk-branding {
      display: flex;
      align-items: center;
      gap: 12px;
    }

    .kiosk-icon {
      width: 42px;
      height: 42px;
      background: linear-gradient(135deg, #2563eb, #06b6d4);
      border-radius: 10px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 14px var(--primary-glow);
    }

    .kiosk-icon svg {
      width: 24px;
      height: 24px;
      fill: white;
    }

    .kiosk-title {
      font-size: 1.15rem;
      font-weight: 800;
      letter-spacing: -0.02em;
    }

    .kiosk-subtitle {
      font-size: 0.75rem;
      color: var(--text-muted);
      font-weight: 500;
    }

    .status-badge {
      display: flex;
      align-items: center;
      gap: 8px;
      background: rgba(16, 185, 129, 0.12);
      border: 1px solid rgba(16, 185, 129, 0.3);
      padding: 6px 14px;
      border-radius: 20px;
      font-size: 0.82rem;
      font-weight: 600;
      color: #34d399;
    }

    .status-dot {
      width: 8px;
      height: 8px;
      background: #10b981;
      border-radius: 50%;
      box-shadow: 0 0 10px #10b981;
      animation: pulse 2s infinite;
    }

    .clock {
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.95rem;
      color: var(--text-muted);
      margin-left: 20px;
    }

    @keyframes pulse {
      0%, 100% { opacity: 1; transform: scale(1); }
      50% { opacity: 0.5; transform: scale(1.15); }
    }

    /* Main Container */
    main {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100%;
      max-width: 600px;
      padding: 24px;
    }

    .kiosk-card {
      width: 100%;
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 28px;
      padding: 36px 32px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 40px rgba(37, 99, 235, 0.08);
      text-align: center;
      position: relative;
    }

    /* View: OTP Entry */
    #otp-view {
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .view-title {
      font-size: 1.65rem;
      font-weight: 800;
      margin-bottom: 8px;
      letter-spacing: -0.02em;
    }

    .view-desc {
      color: var(--text-muted);
      font-size: 0.92rem;
      margin-bottom: 28px;
      line-height: 1.4;
    }

    /* OTP Display Cells */
    .otp-display-container {
      display: flex;
      gap: 12px;
      justify-content: center;
      margin-bottom: 28px;
    }

    .otp-cell {
      width: 58px;
      height: 70px;
      border: 2px solid var(--card-border);
      background: rgba(30, 41, 59, 0.5);
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: 'JetBrains Mono', monospace;
      font-size: 2rem;
      font-weight: 800;
      color: #60a5fa;
      transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
    }

    .otp-cell.active {
      border-color: #3b82f6;
      box-shadow: 0 0 16px var(--primary-glow);
      background: rgba(37, 99, 235, 0.1);
      transform: translateY(-2px);
    }

    .otp-cell.filled {
      border-color: #60a5fa;
      color: white;
    }

    .otp-cell.error {
      border-color: #ef4444 !important;
      background: rgba(239, 68, 68, 0.15) !important;
      color: #f87171 !important;
      box-shadow: 0 0 16px rgba(239, 68, 68, 0.4) !important;
    }

    .otp-display-container.shake {
      animation: shake 0.4s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
    }

    /* On-Screen Touch Keypad */
    .keypad-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 14px;
      width: 100%;
      max-width: 360px;
      margin-bottom: 24px;
    }

    .key-btn {
      height: 64px;
      background: var(--key-bg);
      border: 1px solid rgba(255, 255, 255, 0.05);
      border-radius: 16px;
      font-size: 1.6rem;
      font-weight: 700;
      color: var(--text);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
      transition: all 0.15s ease;
      font-family: 'Plus Jakarta Sans', sans-serif;
    }

    .key-btn:hover {
      background: var(--key-hover);
      border-color: rgba(255, 255, 255, 0.1);
      transform: translateY(-2px);
    }

    .key-btn:active {
      background: var(--key-active);
      transform: translateY(1px);
    }

    .key-btn.action-key {
      font-size: 0.95rem;
      font-weight: 600;
      color: var(--text-muted);
    }

    /* Big Submit Proceed Button */
    .btn-proceed {
      width: 100%;
      max-width: 360px;
      height: 60px;
      background: linear-gradient(135deg, #2563eb, #1d4ed8);
      color: white;
      border: none;
      border-radius: 16px;
      font-size: 1.1rem;
      font-weight: 700;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      box-shadow: 0 10px 20px -5px var(--primary-glow);
      transition: all 0.2s ease;
    }

    .btn-proceed:disabled {
      background: #1e293b;
      color: #64748b;
      box-shadow: none;
      cursor: not-allowed;
      opacity: 0.7;
    }

    .btn-proceed:not(:disabled):hover {
      background: linear-gradient(135deg, #3b82f6, #2563eb);
      transform: translateY(-2px);
      box-shadow: 0 14px 28px -5px var(--primary-glow);
    }

    .btn-proceed:not(:disabled):active {
      transform: translateY(1px);
    }

    .alert-banner {
      width: 100%;
      max-width: 360px;
      padding: 12px 16px;
      border-radius: 12px;
      font-size: 0.88rem;
      font-weight: 600;
      margin-top: 16px;
      display: none;
      animation: shake 0.4s ease;
    }

    .alert-banner.error {
      background: rgba(239, 68, 68, 0.15);
      border: 1px solid rgba(239, 68, 68, 0.35);
      color: #fca5a5;
      display: block;
    }

    @keyframes shake {
      0%, 100% { transform: translateX(0); }
      20%, 60% { transform: translateX(-6px); }
      40%, 80% { transform: translateX(6px); }
    }

    /* View: Live Progress */
    #progress-view {
      display: none;
      flex-direction: column;
      align-items: center;
      animation: fadeIn 0.4s ease-out;
    }

    @keyframes fadeIn {
      from { opacity: 0; transform: scale(0.96); }
      to { opacity: 1; transform: scale(1); }
    }

    .printer-anim-box {
      width: 110px;
      height: 110px;
      background: rgba(37, 99, 235, 0.12);
      border: 2px solid rgba(59, 130, 246, 0.3);
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 24px;
      position: relative;
    }

    .printer-anim-box svg {
      width: 56px;
      height: 56px;
      fill: #60a5fa;
      animation: bounce 1.8s infinite;
    }

    @keyframes bounce {
      0%, 100% { transform: translateY(0); }
      50% { transform: translateY(-6px); }
    }

    .progress-bar-track {
      width: 100%;
      height: 14px;
      background: #1e293b;
      border-radius: 20px;
      overflow: hidden;
      margin: 24px 0 12px 0;
      border: 1px solid var(--card-border);
    }

    .progress-bar-fill {
      height: 100%;
      width: 15%;
      background: linear-gradient(90deg, #2563eb, #06b6d4, #10b981);
      border-radius: 20px;
      transition: width 0.6s cubic-bezier(0.4, 0, 0.2, 1);
      box-shadow: 0 0 14px var(--primary-glow);
    }

    .progress-percent {
      font-family: 'JetBrains Mono', monospace;
      font-size: 1.5rem;
      font-weight: 800;
      color: #60a5fa;
      margin-bottom: 6px;
    }

    .progress-status-text {
      font-size: 1.05rem;
      font-weight: 700;
      color: var(--text);
      margin-bottom: 24px;
    }

    /* Print job receipt details */
    .receipt-box {
      width: 100%;
      background: rgba(15, 23, 42, 0.6);
      border: 1px solid var(--card-border);
      border-radius: 16px;
      padding: 18px 20px;
      margin-bottom: 24px;
      text-align: left;
    }

    .receipt-row {
      display: flex;
      justify-content: space-between;
      font-size: 0.88rem;
      padding: 6px 0;
    }

    .receipt-label {
      color: var(--text-muted);
    }

    .receipt-val {
      font-weight: 600;
      color: var(--text);
      font-family: 'JetBrains Mono', monospace;
    }

    .done-btn {
      width: 100%;
      max-width: 320px;
      height: 54px;
      background: var(--key-bg);
      border: 1px solid var(--card-border);
      border-radius: 14px;
      font-size: 1rem;
      font-weight: 700;
      color: var(--text);
      cursor: pointer;
      display: none;
      transition: all 0.2s ease;
    }

    .done-btn:hover {
      background: var(--key-hover);
      transform: translateY(-2px);
    }

    /* Footer */
    footer {
      width: 100%;
      padding: 16px 32px;
      border-top: 1px solid var(--card-border);
      display: flex;
      justify-content: space-between;
      color: var(--text-muted);
      font-size: 0.8rem;
    }

    @media (max-width: 480px) {
      .otp-cell {
        width: 46px;
        height: 58px;
        font-size: 1.6rem;
      }
      .key-btn {
        height: 56px;
        font-size: 1.4rem;
      }
      .kiosk-card {
        padding: 24px 18px;
      }
    }
  </style>
</head>
<body>

  <!-- Top Kiosk Header -->
  <header>
    <div class="kiosk-branding">
      <div class="kiosk-icon">
        <svg viewBox="0 0 24 24"><path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/></svg>
      </div>
      <div>
        <div class="kiosk-title">Smart Self-Service Print Kiosk</div>
        <div class="kiosk-subtitle">Station 01 &bull; Library 1st Floor</div>
      </div>
    </div>
    <div style="display: flex; align-items: center;">
      <div class="status-badge">
        <span class="status-dot"></span>
        <span>STATION READY</span>
      </div>
      <div class="clock" id="live-clock">12:00:00 PM</div>
    </div>
  </header>

  <!-- Central Main Interaction Area -->
  <main>
    <div class="kiosk-card">
      
      <!-- VIEW 1: ENTER OTP CODE -->
      <div id="otp-view">
        <h1 class="view-title">Enter Release Code</h1>
        <p class="view-desc">Enter the 6-digit OTP code displayed on your mobile screen to release your document.</p>

        <!-- 6 OTP Cells -->
        <div class="otp-display-container" id="otp-cells">
          <div class="otp-cell active" id="c0"></div>
          <div class="otp-cell" id="c1"></div>
          <div class="otp-cell" id="c2"></div>
          <div class="otp-cell" id="c3"></div>
          <div class="otp-cell" id="c4"></div>
          <div class="otp-cell" id="c5"></div>
        </div>

        <!-- Touch Keypad -->
        <div class="keypad-grid">
          <button class="key-btn" onclick="pressDigit('1')">1</button>
          <button class="key-btn" onclick="pressDigit('2')">2</button>
          <button class="key-btn" onclick="pressDigit('3')">3</button>
          <button class="key-btn" onclick="pressDigit('4')">4</button>
          <button class="key-btn" onclick="pressDigit('5')">5</button>
          <button class="key-btn" onclick="pressDigit('6')">6</button>
          <button class="key-btn" onclick="pressDigit('7')">7</button>
          <button class="key-btn" onclick="pressDigit('8')">8</button>
          <button class="key-btn" onclick="pressDigit('9')">9</button>
          <button class="key-btn action-key" onclick="clearOtp()">Clear</button>
          <button class="key-btn" onclick="pressDigit('0')">0</button>
          <button class="key-btn action-key" onclick="backspaceOtp()">⌫ Del</button>
        </div>

        <!-- Proceed Action Button -->
        <button class="btn-proceed" id="btn-proceed" onclick="submitOtp()" disabled>
          <span>PROCEED & PRINT</span>
          <svg style="width: 20px; height: 20px; fill: currentColor;" viewBox="0 0 24 24"><path d="M5 13h11.86l-5.43 5.43 1.42 1.42L21.14 12l-8.29-7.85-1.42 1.42L16.86 11H5v2z"/></svg>
        </button>

        <div class="alert-banner" id="error-banner"></div>
      </div>

      <!-- VIEW 2: LIVE PRINTING PROGRESS -->
      <div id="progress-view">
        <div class="printer-anim-box" id="status-icon-box">
          <svg id="printer-svg" viewBox="0 0 24 24"><path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/></svg>
        </div>

        <div class="progress-percent" id="progress-number">20%</div>
        <div class="progress-status-text" id="progress-status-msg">Verifying code and spooling print job...</div>

        <!-- Progress bar -->
        <div class="progress-bar-track">
          <div class="progress-bar-fill" id="progress-fill"></div>
        </div>

        <!-- Job Details Receipt -->
        <div class="receipt-box">
          <div class="receipt-row">
            <span class="receipt-label">Order ID:</span>
            <span class="receipt-val" id="rec-order-id">ORD-XXXX</span>
          </div>
          <div class="receipt-row">
            <span class="receipt-label">Document:</span>
            <span class="receipt-val" id="rec-filename">Document.pdf</span>
          </div>
          <div class="receipt-row">
            <span class="receipt-label">Settings:</span>
            <span class="receipt-val" id="rec-settings">1 Copy &bull; Black & White</span>
          </div>
          <div class="receipt-row">
            <span class="receipt-label">Status:</span>
            <span class="receipt-val" id="rec-status" style="color: #60a5fa;">PROCESSING</span>
          </div>
        </div>

        <button class="done-btn" id="btn-next-user" onclick="resetKiosk()">
          &#8635; Print Another Document
        </button>
      </div>

    </div>
  </main>

  <!-- Bottom Kiosk Footer -->
  <footer>
    <div>Station Model: AP-2000X &bull; Firmware: v2.4.1</div>
    <div>CUPS Printing System &bull; Secure Self-Service</div>
  </footer>

  <script>
    let currentOtp = "";
    let pollInterval = null;

    // Live clock update
    function updateClock() {
      const now = new Date();
      document.getElementById('live-clock').innerText = now.toLocaleTimeString();
    }
    setInterval(updateClock, 1000);
    updateClock();

    // Check URL parameters for pre-filled OTP (e.g. ?otp=123456)
    window.addEventListener('DOMContentLoaded', () => {
      const urlParams = new URLSearchParams(window.location.search);
      const prefillOtp = urlParams.get('otp');
      if (prefillOtp && prefillOtp.trim().length <= 6) {
        for (const ch of prefillOtp.trim()) {
          if (ch >= '0' && ch <= '9') {
            pressDigit(ch);
          }
        }
      }
    });

    // Support physical keyboard
    window.addEventListener('keydown', (e) => {
      if (document.getElementById('otp-view').style.display === 'none') return;
      if (e.key >= '0' && e.key <= '9') {
        pressDigit(e.key);
      } else if (e.key === 'Backspace') {
        backspaceOtp();
      } else if (e.key === 'Enter') {
        if (currentOtp.length === 6) submitOtp();
      } else if (e.key === 'Escape') {
        clearOtp();
      }
    });

    function updateOtpDisplay() {
      for (let i = 0; i < 6; i++) {
        const cell = document.getElementById('c' + i);
        if (i < currentOtp.length) {
          cell.innerText = currentOtp[i];
          cell.classList.add('filled');
          cell.classList.remove('active');
        } else if (i === currentOtp.length) {
          cell.innerText = "";
          cell.classList.remove('filled');
          cell.classList.add('active');
        } else {
          cell.innerText = "";
          cell.classList.remove('filled');
          cell.classList.remove('active');
        }
      }

      const proceedBtn = document.getElementById('btn-proceed');
      proceedBtn.disabled = currentOtp.length !== 6;
      hideError();
    }

    function shakeOtpCells() {
      const container = document.getElementById('otp-cells');
      if (container) {
        container.classList.remove('shake');
        void container.offsetWidth;
        container.classList.add('shake');
      }
      for (let i = 0; i < 6; i++) {
        const cell = document.getElementById('c' + i);
        if (cell) cell.classList.add('error');
      }
    }

    function clearCellErrors() {
      const container = document.getElementById('otp-cells');
      if (container) container.classList.remove('shake');
      for (let i = 0; i < 6; i++) {
        const cell = document.getElementById('c' + i);
        if (cell) cell.classList.remove('error');
      }
    }

    function pressDigit(d) {
      clearCellErrors();
      hideError();
      if (currentOtp.length < 6) {
        currentOtp += d;
        updateOtpDisplay();
      }
    }

    function backspaceOtp() {
      clearCellErrors();
      hideError();
      if (currentOtp.length > 0) {
        currentOtp = currentOtp.slice(0, -1);
        updateOtpDisplay();
      }
    }

    function clearOtp() {
      clearCellErrors();
      hideError();
      currentOtp = "";
      updateOtpDisplay();
    }

    function showError(msg) {
      const b = document.getElementById('error-banner');
      b.innerText = msg;
      b.classList.add('error');
      b.style.display = 'block';
    }

    function hideError() {
      const b = document.getElementById('error-banner');
      b.classList.remove('error');
      b.style.display = 'none';
    }

    // Submit OTP and transition directly to Progress Screen
    async function submitOtp() {
      if (currentOtp.length !== 6) return;

      const proceedBtn = document.getElementById('btn-proceed');
      proceedBtn.disabled = true;
      proceedBtn.innerHTML = "<span>VERIFYING CODE...</span>";

      try {
        // Try calling central backend release-kiosk endpoint
        const res = await fetch('/api/agent/release-kiosk', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ otp: currentOtp })
        });

        const data = await res.json().catch(() => ({}));
        if (res.ok) {
          // Transition to Progress View immediately!
          showProgressView(data);
        } else {
          const errMsg = data.message || (data.detail && typeof data.detail === 'object' ? data.detail.message : data.detail) || "Invalid OTP code. Please verify the code on your phone.";
          showError(errMsg);
          shakeOtpCells();
          proceedBtn.disabled = false;
          proceedBtn.innerHTML = `<span>PROCEED & PRINT</span><svg style="width: 20px; height: 20px; fill: currentColor;" viewBox="0 0 24 24"><path d="M5 13h11.86l-5.43 5.43 1.42 1.42L21.14 12l-8.29-7.85-1.42 1.42L16.86 11H5v2z"/></svg>`;
        }
      } catch (err) {
        // Fallback: try local agent port 5000 if backend failed
        try {
          const agentRes = await fetch('http://127.0.0.1:5000/local/release', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ otp: currentOtp })
          });
          const agentData = await agentRes.json().catch(() => ({}));
          if (agentRes.ok) {
            showProgressView(agentData.job || agentData);
            return;
          } else {
            const agentErrMsg = agentData.message || "Invalid OTP code. Please check your phone.";
            showError(agentErrMsg);
            shakeOtpCells();
            proceedBtn.disabled = false;
            proceedBtn.innerHTML = `<span>PROCEED & PRINT</span><svg style="width: 20px; height: 20px; fill: currentColor;" viewBox="0 0 24 24"><path d="M5 13h11.86l-5.43 5.43 1.42 1.42L21.14 12l-8.29-7.85-1.42 1.42L16.86 11H5v2z"/></svg>`;
            return;
          }
        } catch (_) {}

        showError("Could not connect to release server. Please retry.");
        shakeOtpCells();
        proceedBtn.disabled = false;
        proceedBtn.innerHTML = `<span>PROCEED & PRINT</span><svg style="width: 20px; height: 20px; fill: currentColor;" viewBox="0 0 24 24"><path d="M5 13h11.86l-5.43 5.43 1.42 1.42L21.14 12l-8.29-7.85-1.42 1.42L16.86 11H5v2z"/></svg>`;
      }
    }

    function showProgressView(jobData) {
      document.getElementById('otp-view').style.display = 'none';
      const pView = document.getElementById('progress-view');
      pView.style.display = 'flex';

      const orderId = jobData.orderId || jobData.order_id || "ORD-" + currentOtp;
      const fileName = jobData.fileName || jobData.filename || "Document.pdf";
      const settings = jobData.settings || {};
      const copies = settings.copies || 1;
      const color = settings.color ? "Color" : "Black & White";

      document.getElementById('rec-order-id').innerText = orderId.substring(0, 14).toUpperCase();
      document.getElementById('rec-filename').innerText = fileName;
      document.getElementById('rec-settings').innerText = `${copies} Copy &bull; ${color}`;
      document.getElementById('rec-status').innerText = "PRINTING";

      // Animated progress cycle
      let percent = 20;
      const fillEl = document.getElementById('progress-fill');
      const numEl = document.getElementById('progress-number');
      const msgEl = document.getElementById('progress-status-msg');

      const interval = setInterval(() => {
        percent += 15;
        if (percent > 100) percent = 100;

        fillEl.style.width = percent + '%';
        numEl.innerText = percent + '%';

        if (percent === 35) {
          msgEl.innerText = "Spooling document to CUPS printer queue...";
        } else if (percent === 50) {
          msgEl.innerText = "Rasterizing PDF pages and heating fuser...";
        } else if (percent === 75) {
          msgEl.innerText = "Feeding paper & applying ink (Page 1 of 1)...";
        } else if (percent >= 100) {
          clearInterval(interval);
          msgEl.innerText = "Printing complete! Collect pages from tray.";
          msgEl.style.color = "#34d399";
          document.getElementById('rec-status').innerText = "COMPLETED";
          document.getElementById('rec-status').style.color = "#34d399";
          document.getElementById('printer-svg').style.animation = "none";
          document.getElementById('status-icon-box').style.borderColor = "rgba(16, 185, 129, 0.4)";
          document.getElementById('status-icon-box').style.background = "rgba(16, 185, 129, 0.15)";
          document.getElementById('printer-svg').style.fill = "#34d399";
          document.getElementById('btn-next-user').style.display = 'block';

          // Automatically return back to OTP entry page for next user or close
          let countdown = 4;
          const autoTimer = setInterval(() => {
            if (countdown > 0) {
              document.getElementById('btn-next-user').innerText = `Print Another / Returning in ${countdown}s...`;
              countdown--;
            } else {
              clearInterval(autoTimer);
              // If opened as a separate popup window, try closing
              if (window.opener) {
                try { window.close(); } catch(e) {}
              }
              resetKiosk();
            }
          }, 1000);
        }
      }, 700);
    }

    function resetKiosk() {
      currentOtp = "";
      updateOtpDisplay();
      document.getElementById('progress-view').style.display = 'none';
      document.getElementById('otp-view').style.display = 'flex';
      document.getElementById('btn-next-user').style.display = 'none';
      document.getElementById('progress-fill').style.width = '15%';
      document.getElementById('progress-number').innerText = '20%';
      document.getElementById('progress-status-msg').innerText = 'Verifying code and spooling print job...';
      document.getElementById('progress-status-msg').style.color = 'var(--text)';
      document.getElementById('printer-svg').style.fill = '#60a5fa';
      document.getElementById('printer-svg').style.animation = 'bounce 1.8s infinite';
      document.getElementById('status-icon-box').style.borderColor = 'rgba(59, 130, 246, 0.3)';
      document.getElementById('status-icon-box').style.background = 'rgba(37, 99, 235, 0.12)';
      const proceedBtn = document.getElementById('btn-proceed');
      proceedBtn.disabled = true;
      proceedBtn.innerHTML = `<span>PROCEED & PRINT</span><svg style="width: 20px; height: 20px; fill: currentColor;" viewBox="0 0 24 24"><path d="M5 13h11.86l-5.43 5.43 1.42 1.42L21.14 12l-8.29-7.85-1.42 1.42L16.86 11H5v2z"/></svg>`;
    }
  </script>
</body>
</html>
"""

@router.get("/kiosk", response_class=HTMLResponse)
def serve_kiosk_page(request: Request):
    return HTMLResponse(content=KIOSK_HTML, status_code=200)
