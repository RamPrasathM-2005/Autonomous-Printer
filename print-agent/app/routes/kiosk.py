import json
from flask import Blueprint, render_template_string, jsonify, request
from app.config import config
from app.services.printer_monitor import printer_monitor
from app.services.job_poller import job_poller
from app.services.backend_client import backend_client
from app.services.print_service import print_service
from app.utils.errors import OtpReleaseException, BackendCommunicationException

kiosk_bp = Blueprint("kiosk", __name__)

KIOSK_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Autonomous Print | Station Kiosk</title>
  <style>
    :root {
      --bg: #0b0f19;
      --card-bg: #141b2d;
      --card-border: #1f2a44;
      --text: #ffffff;
      --text-muted: #94a3b8;
      --accent: #2563eb;
      --accent-hover: #1d4ed8;
      --accent-glow: rgba(37, 99, 235, 0.4);
      --success: #10b981;
      --error: #ef4444;
      --warning: #f59e0b;
    }

    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      user-select: none;
      -webkit-user-select: none;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 20px;
      overflow: hidden;
    }

    .kiosk-card {
      background: var(--card-bg);
      border: 2px solid var(--card-border);
      border-radius: 20px;
      width: 100%;
      max-width: 520px;
      padding: 32px 28px;
      box-shadow: 0 20px 50px rgba(0, 0, 0, 0.6);
      text-align: center;
      position: relative;
    }

    .station-header {
      border-bottom: 2px dashed var(--card-border);
      padding-bottom: 18px;
      margin-bottom: 20px;
    }

    .station-title {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: 2px;
      text-transform: uppercase;
      color: #f1f5f9;
      margin-bottom: 4px;
    }

    .station-subtitle {
      font-size: 14px;
      font-weight: 700;
      letter-spacing: 3px;
      color: #60a5fa;
      text-transform: uppercase;
    }

    .status-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      font-size: 12px;
      font-weight: 600;
      padding: 4px 12px;
      border-radius: 9999px;
      background: rgba(16, 185, 129, 0.15);
      color: #34d399;
      border: 1px solid rgba(16, 185, 129, 0.3);
      margin-top: 10px;
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 8px var(--success);
    }

    .prompt-text {
      font-size: 18px;
      font-weight: 600;
      color: #e2e8f0;
      margin-bottom: 18px;
    }

    .otp-display-container {
      display: flex;
      justify-content: center;
      gap: 10px;
      margin-bottom: 22px;
    }

    .otp-box {
      width: 54px;
      height: 64px;
      background: #0f172a;
      border: 2px solid #334155;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 32px;
      font-weight: 700;
      font-family: 'Courier New', Courier, monospace;
      color: #ffffff;
      transition: all 0.15s ease;
    }

    .otp-box.filled {
      border-color: var(--accent);
      background: rgba(37, 99, 235, 0.15);
      box-shadow: 0 0 14px var(--accent-glow);
    }

    .otp-box.active {
      border-color: #60a5fa;
      box-shadow: 0 0 10px rgba(96, 165, 250, 0.5);
    }

    .keypad-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      max-width: 380px;
      margin: 0 auto 20px auto;
    }

    .key-btn {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 12px;
      color: #ffffff;
      font-size: 26px;
      font-weight: 700;
      padding: 16px 0;
      cursor: pointer;
      touch-action: manipulation;
      transition: all 0.1s ease;
    }

    .key-btn:active {
      background: #334155;
      transform: scale(0.96);
    }

    .key-btn.action-btn {
      font-size: 14px;
      font-weight: 800;
      letter-spacing: 1px;
      color: #94a3b8;
    }

    .print-btn {
      background: linear-gradient(135deg, #10b981 0%, #059669 100%);
      color: #ffffff;
      border: none;
      border-radius: 14px;
      width: 100%;
      max-width: 380px;
      padding: 18px 0;
      font-size: 20px;
      font-weight: 800;
      letter-spacing: 2px;
      text-transform: uppercase;
      cursor: pointer;
      box-shadow: 0 8px 24px rgba(16, 185, 129, 0.35);
      transition: all 0.15s ease;
      touch-action: manipulation;
    }

    .print-btn:hover:not(:disabled) {
      filter: brightness(1.1);
      transform: translateY(-2px);
    }

    .print-btn:active:not(:disabled) {
      transform: translateY(1px);
    }

    .print-btn:disabled {
      opacity: 0.45;
      cursor: not-allowed;
      box-shadow: none;
    }

    .footer-help {
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 18px;
      line-height: 1.4;
    }

    /* Modal Overlay for Status / Messages */
    .overlay {
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: rgba(11, 15, 25, 0.95);
      border-radius: 18px;
      display: none;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 30px;
      z-index: 10;
    }

    .overlay.active {
      display: flex;
    }

    .overlay-icon {
      width: 72px;
      height: 72px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 36px;
      margin-bottom: 20px;
    }

    .overlay-icon.loading {
      border: 4px solid rgba(255, 255, 255, 0.1);
      border-top-color: var(--accent);
      animation: spin 1s linear infinite;
    }

    .overlay-icon.success {
      background: rgba(16, 185, 129, 0.2);
      color: var(--success);
      border: 2px solid var(--success);
    }

    .overlay-icon.error {
      background: rgba(239, 68, 68, 0.2);
      color: var(--error);
      border: 2px solid var(--error);
    }

    .overlay-title {
      font-size: 24px;
      font-weight: 800;
      margin-bottom: 10px;
    }

    .overlay-msg {
      font-size: 16px;
      color: #94a3b8;
      max-width: 360px;
      line-height: 1.5;
      margin-bottom: 24px;
    }

    .overlay-btn {
      background: #1e293b;
      border: 1px solid #334155;
      color: #ffffff;
      padding: 12px 28px;
      border-radius: 10px;
      font-size: 15px;
      font-weight: 700;
      cursor: pointer;
    }

    @keyframes spin {
      from { transform: rotate(0deg); }
      to { transform: rotate(360deg); }
    }
  </style>
</head>
<body>

  <div class="kiosk-card">
    <!-- Header -->
    <div class="station-header">
      <div class="station-title">AUTONOMOUS PRINT</div>
      <div class="station-subtitle">PRINT STATION</div>
      <div class="status-badge">
        <span class="status-dot"></span>
        <span id="printer-name">HP_LaserJet_400_M401dn_F36EC0</span>
        <span style="opacity: 0.6;">(READY)</span>
      </div>
    </div>

    <!-- OTP Prompt -->
    <div class="prompt-text">Enter your 6-digit OTP</div>

    <!-- 6 Digits Display -->
    <div class="otp-display-container">
      <div class="otp-box active" id="box-0"></div>
      <div class="otp-box" id="box-1"></div>
      <div class="otp-box" id="box-2"></div>
      <div class="otp-box" id="box-3"></div>
      <div class="otp-box" id="box-4"></div>
      <div class="otp-box" id="box-5"></div>
    </div>

    <!-- Touchscreen Keypad -->
    <div class="keypad-grid">
      <button class="key-btn" onclick="pressKey('1')">1</button>
      <button class="key-btn" onclick="pressKey('2')">2</button>
      <button class="key-btn" onclick="pressKey('3')">3</button>
      <button class="key-btn" onclick="pressKey('4')">4</button>
      <button class="key-btn" onclick="pressKey('5')">5</button>
      <button class="key-btn" onclick="pressKey('6')">6</button>
      <button class="key-btn" onclick="pressKey('7')">7</button>
      <button class="key-btn" onclick="pressKey('8')">8</button>
      <button class="key-btn" onclick="pressKey('9')">9</button>
      <button class="key-btn action-btn" onclick="clearOtp()">CLEAR</button>
      <button class="key-btn" onclick="pressKey('0')">0</button>
      <button class="key-btn action-btn" onclick="backspaceOtp()">⌫</button>
    </div>

    <!-- Print Button -->
    <button class="print-btn" id="btn-print" onclick="submitOtp()" disabled>
      PRINT
    </button>

    <!-- Footer Instruction -->
    <div class="footer-help">
      Enter the OTP received<br>after completing payment.
    </div>

    <!-- Status / Overlay Screen -->
    <div class="overlay" id="overlay">
      <div class="overlay-icon" id="overlay-icon"></div>
      <div class="overlay-title" id="overlay-title">Verifying OTP...</div>
      <div class="overlay-msg" id="overlay-msg">Connecting to printer station...</div>
      <button class="overlay-btn" id="overlay-close-btn" onclick="closeOverlay()" style="display: none;">Try Again</button>
    </div>
  </div>

  <script>
    let currentOtp = "";
    let autoResetTimer = null;

    function updateDisplay() {
      for (let i = 0; i < 6; i++) {
        const box = document.getElementById(`box-${i}`);
        if (i < currentOtp.length) {
          box.textContent = currentOtp[i];
          box.classList.add("filled");
          box.classList.remove("active");
        } else if (i === currentOtp.length) {
          box.textContent = "";
          box.classList.remove("filled");
          box.classList.add("active");
        } else {
          box.textContent = "";
          box.classList.remove("filled");
          box.classList.remove("active");
        }
      }
      document.getElementById("btn-print").disabled = (currentOtp.length !== 6);
    }

    function pressKey(num) {
      if (currentOtp.length < 6) {
        currentOtp += num;
        updateDisplay();
        if (currentOtp.length === 6) {
          // Auto submit when 6th digit entered
          submitOtp();
        }
      }
    }

    function backspaceOtp() {
      if (currentOtp.length > 0) {
        currentOtp = currentOtp.slice(0, -1);
        updateDisplay();
      }
    }

    function clearOtp() {
      currentOtp = "";
      updateDisplay();
    }

    // Keyboard support for testing / external hardware keypads
    window.addEventListener("keydown", (e) => {
      if (document.getElementById("overlay").classList.contains("active")) {
        if (e.key === "Escape") closeOverlay();
        return;
      }
      if (e.key >= '0' && e.key <= '9') {
        pressKey(e.key);
      } else if (e.key === 'Backspace') {
        backspaceOtp();
      } else if (e.key === 'Escape' || e.key === 'c' || e.key === 'C') {
        clearOtp();
      } else if (e.key === 'Enter') {
        submitOtp();
      }
    });

    async function submitOtp() {
      if (currentOtp.length !== 6) return;

      const overlay = document.getElementById("overlay");
      const icon = document.getElementById("overlay-icon");
      const title = document.getElementById("overlay-title");
      const msg = document.getElementById("overlay-msg");
      const closeBtn = document.getElementById("overlay-close-btn");

      // Show Loading State
      overlay.classList.add("active");
      icon.className = "overlay-icon loading";
      icon.textContent = "";
      title.textContent = "Verifying OTP...";
      msg.textContent = "Connecting to backend verification flow...";
      closeBtn.style.display = "none";

      try {
        const resp = await fetch("/local/release", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ otp: currentOtp })
        });

        const data = await resp.json().catch(() => ({}));

        if (resp.ok) {
          // Stage 1: Verified
          icon.className = "overlay-icon success";
          icon.textContent = "✓";
          title.textContent = "OTP Verified";
          msg.textContent = "Printing...";

          setTimeout(() => {
            // Stage 2: Printing Started
            title.textContent = "Printing Started";
            msg.textContent = "Please collect your document from the printer tray.";

            // Reset after 8 seconds
            if (autoResetTimer) clearTimeout(autoResetTimer);
            autoResetTimer = setTimeout(() => {
              closeOverlay();
            }, 8000);
          }, 1500);

        } else {
          // Specific Error Handling as required:
          icon.className = "overlay-icon error";
          icon.textContent = "✕";
          closeBtn.style.display = "block";

          const errCode = data.error || data.error_code || "";
          const errMsg = data.message || "";

          if (errCode === "ALREADY_PRINTED" || errMsg.includes("already been printed")) {
            title.textContent = "This order has already been printed.";
            msg.textContent = "This OTP was already used and cannot be reprinted.";
          } else if (errCode === "OTP_EXPIRED" || errMsg.includes("expired")) {
            title.textContent = "OTP Expired";
            msg.textContent = "Please generate/request a new OTP from your mobile or web app.";
          } else if (errCode === "PAYMENT_REQUIRED" || errMsg.includes("Payment")) {
            title.textContent = "Payment Pending";
            msg.textContent = "Payment has not been completed for this order.";
          } else if (errCode === "TOO_MANY_ATTEMPTS") {
            title.textContent = "Too Many Attempts";
            msg.textContent = "Maximum attempts exceeded. Please request a new OTP.";
          } else if (errCode === "INVALID_OTP") {
            title.textContent = "Invalid OTP";
            msg.textContent = "Please check the OTP and try again.";
          } else if (resp.status === 503 || errCode === "BACKEND_UNAVAILABLE") {
            title.textContent = "Backend Unavailable";
            msg.textContent = "Printer station backend is currently unreachable. Please wait a moment and try again.";
          } else {
            title.textContent = "Invalid OTP";
            msg.textContent = errMsg || "Please check the OTP and try again.";
          }

          // Auto reset error overlay after 6 seconds
          if (autoResetTimer) clearTimeout(autoResetTimer);
          autoResetTimer = setTimeout(() => {
            closeOverlay();
          }, 6000);
        }
      } catch (e) {
        icon.className = "overlay-icon error";
        icon.textContent = "✕";
        closeBtn.style.display = "block";
        title.textContent = "Connection Error";
        msg.textContent = "Print agent communication failed. Ensure station services are running.";
        
        if (autoResetTimer) clearTimeout(autoResetTimer);
        autoResetTimer = setTimeout(() => {
          closeOverlay();
        }, 5000);
      }
    }

    function closeOverlay() {
      if (autoResetTimer) clearTimeout(autoResetTimer);
      document.getElementById("overlay").classList.remove("active");
      clearOtp();
    }

    // Refresh printer name from local agent
    fetch("/local/status").then(r => r.json()).then(d => {
      if (d && d.printer_name) {
        document.getElementById("printer-name").textContent = d.printer_name;
      }
    }).catch(() => {});
  </script>
</body>
</html>
"""

@kiosk_bp.route("/kiosk", methods=["GET"])
@kiosk_bp.route("/", methods=["GET"])
def get_kiosk_page():
    return render_template_string(KIOSK_HTML)
