import os
import io
import base64
from functools import lru_cache
from urllib.parse import urlsplit, urlunsplit, parse_qsl, urlencode
from flask import Blueprint, render_template_string, redirect, url_for, send_file, request, jsonify, Response
import qrcode
from app.config import config

kiosk_bp = Blueprint("kiosk", __name__)

def get_web_url() -> str:
    """The Pi displays the configured customer website; no local tunnel discovery."""
    return os.getenv("KIOSK_WEB_URL", "http://127.0.0.1:3000").strip().rstrip("/")

def get_customer_url() -> str:
    parts = urlsplit(get_web_url())
    query = dict(parse_qsl(parts.query))
    query["station"] = config.AGENT_ID
    return urlunsplit((parts.scheme, parts.netloc, parts.path or "/", urlencode(query), parts.fragment))

@lru_cache(maxsize=8)
def generate_qr_base64(url: str) -> str:
    """Generates a high-contrast PNG QR code as a base64 Data URI."""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=8,
        border=2,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#0f172a", back_color="#ffffff")
    buf = io.BytesIO()
    img.save(buf)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

KIOSK_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <link rel="icon" href="/static/achuppori-logo.png">
  <title>Achuppori - Terminal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #f8fafc;
      --surface: #ffffff;
      --surface-card: #f1f5f9;
      --border: #e2e8f0;
      --border-focus: #2563eb;
      --primary: #2563eb;
      --primary-hover: #1d4ed8;
      --primary-glow: rgba(37, 99, 235, 0.2);
      --accent: #0284c7;
      --text: #0f172a;
      --text-muted: #64748b;
      --text-dim: #94a3b8;
      --success: #10b981;
      --success-bg: rgba(16, 185, 129, 0.1);
      --danger: #ef4444;
      --danger-bg: rgba(239, 68, 68, 0.08);
      --warning: #f59e0b;
      --key-bg: #ffffff;
      --key-hover: #f1f5f9;
      --key-active: #e2e8f0;
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
      background: radial-gradient(circle at 50% 0%, #f0f7ff 0%, var(--bg) 75%);
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
      background: rgba(255, 255, 255, 0.95);
      backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border);
      padding: 8px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      z-index: 10;
      flex-wrap: wrap;
      gap: 12px;
      box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
    }

    .station-brand {
      display: flex;
      align-items: center;
      gap: 14px;
    }

    .brand-icon {
      width: 36px;
      height: 36px;
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
      color: var(--text);
      line-height: 1.2;
    }

    .brand-text p {
      font-size: 0.76rem;
      color: var(--text-muted);
      font-weight: 500;
    }

    .station-actions {
      display: flex;
      align-items: center;
      gap: 10px;
    }


    .station-pills {
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .printer-model-badge {
      background: var(--surface-card);
      border: 1px solid var(--border);
      padding: 6px 12px;
      border-radius: 9999px;
      font-size: 0.75rem;
      font-weight: 600;
      color: var(--text-muted);
    }

    .status-badge {
      display: flex;
      align-items: center;
      gap: 6px;
      background: var(--surface-card);
      border: 1px solid var(--border);
      padding: 6px 12px;
      border-radius: 9999px;
      font-size: 0.75rem;
      font-weight: 700;
      color: var(--text);
    }

    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--success);
      box-shadow: 0 0 8px var(--success);
      animation: pulseDot 2s infinite;
    }

    @keyframes pulseDot {
      0% { opacity: 0.6; transform: scale(0.9); }
      50% { opacity: 1; transform: scale(1.1); }
      100% { opacity: 0.6; transform: scale(0.9); }
    }

    /* Main Kiosk Layout Grid (Side by Side) */
    main {
      flex: 1;
      display: flex;
      align-items: center;
      justify-content: center;
      width: 100%;
      max-width: 1100px;
      padding: 8px 14px;
    }

    .kiosk-grid {
      display: grid;
      grid-template-columns: minmax(0, 1fr) minmax(0, 1.15fr);
      gap: 14px;
      width: 100%;
      align-items: stretch;
    }

    @media (max-width: 599px) {
      .kiosk-grid {
        grid-template-columns: 1fr;
      }
    }

    /* Left Card: QR Code & Mobile Info */
    .kiosk-card-left {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 12px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.05), 0 1px 3px rgba(0, 0, 0, 0.05);
      display: flex;
      flex-direction: column;
      align-items: center;
      text-align: center;
      justify-content: space-between;
      position: relative;
    }

    .qr-badge-pill {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: rgba(37, 99, 235, 0.08);
      border: 1px solid rgba(37, 99, 235, 0.25);
      color: #2563eb;
      padding: 4px 12px;
      border-radius: 9999px;
      font-size: 0.72rem;
      font-weight: 800;
      letter-spacing: 0.6px;
      text-transform: uppercase;
      margin-bottom: 12px;
    }

    .kiosk-card-left h2 {
      font-size: 1.2rem;
      font-weight: 800;
      color: var(--text);
      margin-bottom: 6px;
    }

    .kiosk-card-left p {
      font-size: 0.8rem;
      color: var(--text-muted);
      max-width: 320px;
      line-height: 1.45;
      margin-bottom: 8px;
    }

    /* QR Code Display Frame */
    .qr-frame {
      background: #ffffff;
      padding: 10px;
      border-radius: 18px;
      box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08), 0 0 15px rgba(37, 99, 235, 0.08);
      border: 2px solid var(--border);
      margin-bottom: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.2s ease;
    }

    .qr-frame:hover {
      transform: scale(1.02);
    }

    .qr-frame img {
      width: 184px;
      height: 184px;
      display: block;
      image-rendering: pixelated;
    }

    .qr-url-pill {
      background: var(--surface-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 6px 12px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.7rem;
      color: #0284c7;
      word-break: break-all;
      margin-bottom: 8px;
      max-width: 100%;
    }

    .kiosk-card-left .action-group {
      width: 100%;
      display: flex;
      flex-direction: column;
      gap: 12px;
      align-items: center;
    }


    /* 3 Simple Steps */
    .steps-list {
      display: flex;
      justify-content: space-between;
      width: 100%;
      max-width: 340px;
      margin-top: 0;
      border-top: 1px solid var(--border);
      padding-top: 8px;
      gap: 6px;
    }

    .step-micro {
      font-size: 0.7rem;
      color: var(--text-muted);
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 3px;
    }

    .step-micro span.num {
      width: 18px;
      height: 18px;
      border-radius: 50%;
      background: rgba(37, 99, 235, 0.12);
      color: #2563eb;
      font-weight: 800;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.65rem;
    }

    /* Right Card: Keypad & OTP Entry */
    .kiosk-card-right {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 12px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.05), 0 1px 3px rgba(0, 0, 0, 0.05);
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      position: relative;
    }

    .card-title-group {
      text-align: center;
      margin-bottom: 8px;
    }

    .card-title-group h2 {
      font-size: 1.2rem;
      font-weight: 800;
      letter-spacing: -0.02em;
      margin-bottom: 5px;
      color: var(--text);
    }

    .card-title-group p {
      font-size: 0.85rem;
      color: var(--text-muted);
    }

    /* 6-Digit Display Slots */
    .otp-display-container {
      display: flex;
      justify-content: center;
      gap: 6px;
      margin-bottom: 8px;
    }

    .otp-slot {
      width: 44px;
      height: 44px;
      background: #f8fafc;
      border: 2px solid #cbd5e1;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: 'JetBrains Mono', monospace;
      font-size: 1.5rem;
      font-weight: 700;
      color: var(--text);
      box-shadow: inset 0 1px 3px rgba(0,0,0,0.05);
      transition: all 0.15s ease;
    }

    .otp-slot.filled {
      border-color: #2563eb;
      background: #eff6ff;
      color: #2563eb;
      transform: scale(1.02);
    }

    .otp-slot.active {
      border-color: var(--border-focus);
      box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.2);
    }

    .otp-slot.error {
      border-color: #ef4444 !important;
      background: #fef2f2 !important;
      color: #ef4444 !important;
      box-shadow: 0 0 0 3px rgba(239, 68, 68, 0.25) !important;
    }

    .otp-display-container.shake {
      animation: otpShake 0.4s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
    }

    @keyframes otpShake {
      10%, 90% { transform: translate3d(-2px, 0, 0); }
      20%, 80% { transform: translate3d(4px, 0, 0); }
      30%, 50%, 70% { transform: translate3d(-6px, 0, 0); }
      40%, 60% { transform: translate3d(6px, 0, 0); }
    }

    /* Alert / Status Banners */
    .alert-banner {
      display: none;
      padding: 10px 14px;
      border-radius: 12px;
      margin-bottom: 14px;
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
      border: 1px solid rgba(239, 68, 68, 0.25);
      color: #b91c1c;
    }

    .alert-banner.error h3 {
      font-size: 0.92rem;
      font-weight: 700;
      color: #dc2626;
      margin-bottom: 2px;
    }

    .alert-banner.error p {
      font-size: 0.8rem;
      color: #b91c1c;
    }

    /* Keypad Grid */
    .keypad-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 6px;
      margin-bottom: 8px;
    }

    .key-btn {
      background: var(--key-bg);
      border: 1.5px solid var(--border);
      border-radius: 12px;
      height: 44px;
      font-size: 1.45rem;
      font-weight: 700;
      color: var(--text);
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.03);
      transition: all 0.12s ease;
      touch-action: manipulation;
    }

    .key-btn:hover {
      background: var(--key-hover);
      border-color: #cbd5e1;
    }

    .key-btn:active {
      background: var(--key-active);
      transform: scale(0.96);
    }

    .key-btn.action-btn {
      font-size: 0.85rem;
      font-weight: 700;
      letter-spacing: 0.03em;
      color: var(--text-muted);
      background: #f8fafc;
    }

    .key-btn.action-btn:hover {
      color: var(--text);
      background: #f1f5f9;
    }

    .key-btn.clear-btn:active {
      background: rgba(239, 68, 68, 0.1);
      border-color: var(--danger);
      color: var(--danger);
    }

    .key-btn svg {
      width: 22px;
      height: 22px;
      fill: currentColor;
    }

    /* Primary Print Button */
    .print-btn {
      width: 100%;
      height: 44px;
      background: linear-gradient(135deg, #2563eb, #1d4ed8);
      border: none;
      border-radius: 12px;
      color: #ffffff;
      font-size: 1.05rem;
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
      box-shadow: 0 6px 24px rgba(37, 99, 235, 0.4);
      transform: translateY(-1px);
    }

    .print-btn:active:not(:disabled) {
      transform: scale(0.98);
    }

    .print-btn:disabled {
      background: #e2e8f0;
      color: #94a3b8;
      box-shadow: none;
      cursor: not-allowed;
      border: 1px solid #cbd5e1;
    }

    .print-btn svg {
      width: 20px;
      height: 20px;
      fill: currentColor;
    }

    /* Fullscreen Modal / Progress Overlay */
    .modal-overlay {
      display: none;
      position: fixed;
      top: 0;
      left: 0;
      width: 100vw;
      height: 100vh;
      background: rgba(15, 23, 42, 0.45);
      backdrop-filter: blur(8px);
      z-index: 100;
      align-items: center;
      justify-content: center;
      animation: fadeIn 0.2s ease;
    }

    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    .modal-card {
      background: #ffffff;
      border: 1px solid var(--border);
      border-radius: 24px;
      padding: 36px 32px;
      text-align: center;
      max-width: 440px;
      width: 90%;
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
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
      background: rgba(37, 99, 235, 0.1);
      border: 2px solid rgba(37, 99, 235, 0.25);
    }

    .modal-icon-wrap.success {
      background: rgba(16, 185, 129, 0.1);
      border: 2px solid rgba(16, 185, 129, 0.25);
    }

    .modal-icon-wrap.error {
      background: rgba(239, 68, 68, 0.1);
      border: 2px solid rgba(239, 68, 68, 0.25);
    }

    .spinner {
      width: 38px;
      height: 38px;
      border: 4px solid rgba(37, 99, 235, 0.15);
      border-top-color: #2563eb;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }

    .modal-content h3 {
      font-size: 1.45rem;
      font-weight: 800;
      margin-bottom: 8px;
      color: var(--text);
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
      background: #f1f5f9;
      border: 1px solid #e2e8f0;
      border-radius: 9999px;
      font-size: 0.8rem;
      font-weight: 600;
      color: var(--text-muted);
    }

    .kiosk-printer-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      margin: 14px 0 16px;
      padding: 8px 16px;
      background: #f8fafc;
      border: 1.5px solid #e2e8f0;
      border-radius: 12px;
      font-size: 0.95rem;
      font-weight: 700;
      color: #0f172a;
    }

    .kiosk-printer-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #10b981;
      box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.25);
      animation: pulseDot 1.5s infinite;
    }

    .kiosk-progress-container {
      margin: 16px 0 10px;
      text-align: left;
    }

    .kiosk-progress-header {
      display: flex;
      justify-content: space-between;
      font-size: 0.82rem;
      font-weight: 700;
      color: #64748b;
      margin-bottom: 6px;
    }

    .kiosk-progress-track {
      width: 100%;
      height: 10px;
      background: #f1f5f9;
      border-radius: 9999px;
      overflow: hidden;
      border: 1px solid #e2e8f0;
    }

    .kiosk-progress-fill {
      height: 100%;
      width: 0%;
      background: linear-gradient(90deg, #2563eb, #3b82f6);
      border-radius: 9999px;
      transition: width 0.3s ease, background 0.3s ease;
    }

    .kiosk-progress-fill.completed {
      background: linear-gradient(90deg, #059669, #10b981);
    }

    footer {
      width: 100%;
      text-align: center;
      padding: 6px 14px;
      font-size: 0.76rem;
      color: var(--text-dim);
      border-top: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.85);
    }

    .kiosk-card-left, .kiosk-card-right { min-width: 0; }
    .printer-model-badge {
      max-width: 260px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    .key-btn:focus-visible, .print-btn:focus-visible {
      outline: 3px solid var(--border-focus);
      outline-offset: 2px;
    }
    /* Keep the 800x480 Pi touchscreen usable, including browser toolbars. */
    @media (min-width: 600px) and (max-height: 520px) {
      header { flex-wrap: nowrap; gap: 8px; }
      .station-brand { gap: 8px; }
      .brand-text p { display: none; }
      .printer-model-badge { max-width: 200px; }
      .kiosk-grid { gap: 12px; }
      .card-title-group p { display: none; }
      .keypad-grid { gap: 4px; }
      .otp-slot { height: 40px; }
      .qr-frame img { width: 168px; height: 168px; }
      .qr-badge-pill { margin-bottom: 6px; }
      .kiosk-card-left p { margin-bottom: 6px; }
      .kiosk-card-left, .kiosk-card-right { padding: 10px; }
      .card-title-group h2 { margin-bottom: 0; }
      /* Errors replace the title area instead of pushing the keypad down. */
      .alert-banner.error {
        position: absolute;
        top: 8px;
        left: 8px;
        right: 8px;
        z-index: 1;
        margin: 0;
        padding: 6px 10px;
        background: #fef2f2;
      }
    }
    @media (min-width: 600px) and (max-height: 420px) {
      footer { display: none; }
      header { padding: 6px 14px; }
      .brand-icon { width: 32px; height: 32px; }
      main { padding: 4px 14px; }
      .qr-frame img { width: 152px; height: 152px; }
    }
    @media (max-width: 599px) {
      header { padding: 10px 12px; }
      .printer-model-badge { max-width: 180px; }
      .otp-slot { flex: 0 1 44px; min-width: 0; }
      .kiosk-card-left { gap: 8px; }
    }
  </style>
</head>
<body oncontextmenu="return false;">

  <!-- Header -->
  <header>
    <div class="station-brand">
      <div class="brand-icon">
        <img src="/static/achuppori-logo.png" alt="Achuppori" style="width:100%;height:100%;object-fit:contain;border-radius:inherit">
      </div>
      <div class="brand-text">
        <h1>ACHUPPORI</h1>
        <p>Self-service printing</p>
      </div>
    </div>

    <div class="station-actions">
      <div class="station-pills">
        <span class="printer-model-badge">{{ printer_name }}</span>
        <div class="status-badge" id="stationStatusBadge">
          <span class="status-dot" id="stationStatusDot"></span>
          <span id="stationStatusText">READY</span>
        </div>
      </div>
    </div>
  </header>

  <!-- Main Kiosk Body: Side-by-Side View -->
  <main>
    <div class="kiosk-grid">
      
      <!-- LEFT COLUMN: Mobile QR Scan & APK Download -->
      <div class="kiosk-card-left">
        <div>
          <h2>Scan to print</h2>
          <p>Upload &amp; pay on your phone.</p>
        </div>

        <!-- High-Contrast QR Code -->
        <div class="qr-frame">
          <img src="{{ qr_data_uri }}" alt="Scan QR Code to Print" id="kioskQrImg" />
        </div>

        <div class="qr-url-pill" id="kioskQrUrlText">
          {{ web_url }}
        </div>

        <!-- Direct Actions -->
        <div class="action-group">
          <div class="steps-list">
            <div class="step-micro">
              <span>Scan QR Code</span>
            </div>
            <div class="step-micro">
              <span>Upload & Pay</span>
            </div>
            <div class="step-micro">
              <span>Enter OTP Here</span>
            </div>
          </div>
        </div>
      </div>

      <!-- RIGHT COLUMN: 6-Digit Release Keypad -->
      <div class="kiosk-card-right">
        <div class="card-title-group">
          <h2>Enter your 6-digit OTP</h2>
          <p>Use the code from your phone.</p>
        </div>

        <!-- Alert Banner for Errors or Notices -->
        <div class="alert-banner" id="alertBanner" role="alert" aria-live="polite">
          <h3 id="alertTitle">Invalid OTP</h3>
          <p id="alertMessage">Please check the OTP and try again.</p>
        </div>

        <!-- 6 Discrete Digit Slots -->
        <div class="otp-display-container" id="otpContainer">
          <div class="otp-slot" data-index="0"></div>
          <div class="otp-slot" data-index="1"></div>
          <div class="otp-slot" data-index="2"></div>
          <div class="otp-slot" data-index="3"></div>
          <div class="otp-slot" data-index="4"></div>
          <div class="otp-slot" data-index="5"></div>
        </div>

        <!-- Touchscreen 3x4 Keypad -->
        <div class="keypad-grid">
          <button class="key-btn" data-key="1">1</button>
          <button class="key-btn" data-key="2">2</button>
          <button class="key-btn" data-key="3">3</button>

          <button class="key-btn" data-key="4">4</button>
          <button class="key-btn" data-key="5">5</button>
          <button class="key-btn" data-key="6">6</button>

          <button class="key-btn" data-key="7">7</button>
          <button class="key-btn" data-key="8">8</button>
          <button class="key-btn" data-key="9">9</button>

          <button class="key-btn action-btn clear-btn" data-action="clear">CLEAR</button>
          <button class="key-btn" data-key="0">0</button>
          <button class="key-btn action-btn backspace-btn" data-action="backspace" aria-label="Delete last digit">
            <svg viewBox="0 0 24 24">
              <path d="M22 3H7c-.69 0-1.23.35-1.59.88L0 12l5.41 8.11c.36.53.9.89 1.59.89h15c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-3 12.59L17.59 17 14 13.41 10.41 17 9 15.59 12.59 12 9 8.41 10.41 7 14 10.59 17.59 7 19 8.41 15.41 12 19 15.59z"/>
            </svg>
          </button>
        </div>

        <!-- Action / Submit Button -->
        <button class="print-btn" id="printBtn" disabled>
          <svg viewBox="0 0 24 24">
            <path d="M19 8H5c-1.66 0-3 1.34-3 3v6h4v4h12v-4h4v-6c0-1.66-1.34-3-3-3zm-3 11H8v-5h8v5zm3-7c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1zm-1-9H6v4h12V3z"/>
          </svg>
          <span>PRINT DOCUMENT</span>
        </button>

      </div>
    </div>
  </main>

  <!-- Fullscreen Printing Status / Modal -->
  <div class="modal-overlay" id="statusModal">
    <div class="modal-card">
      <div class="modal-icon-wrap" id="modalIconWrap">
        <div class="spinner" id="modalSpinner"></div>
        <svg id="modalCheckIcon" viewBox="0 0 24 24" style="display:none; fill:#10b981;">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
        </svg>
        <svg id="modalErrorIcon" viewBox="0 0 24 24" style="display:none; fill:#ef4444; width:38px; height:38px;">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm5 13.59L15.59 17 12 13.41 8.41 17 7 15.59 10.59 12 7 8.41 8.41 7 12 10.59 15.59 7 17 8.41 13.41 12 17 15.59z"/>
        </svg>
      </div>
      <div class="modal-content">
        <h3 id="modalTitle">OTP Verified</h3>
        <p id="modalMessage">Connecting to physical printer...</p>

        <!-- Active Running Printer Badge -->
        <div class="kiosk-printer-badge" id="modalPrinterBadge" style="display:none;">
          <span class="kiosk-printer-dot"></span>
          <span id="modalPrinterName">Department printer</span>
        </div>

        <!-- Live Printing Progress Bar -->
        <div class="kiosk-progress-container" id="modalProgressContainer" style="display:none;">
          <div class="kiosk-progress-header">
            <span id="modalProgressStep">Preparing print job...</span>
            <span id="modalProgressPercent">0%</span>
          </div>
          <div class="kiosk-progress-track">
            <div class="kiosk-progress-fill" id="modalProgressFill"></div>
          </div>
        </div>

        <div class="countdown-pill" id="modalCountdown" style="display:none;">
          Reloading screen in 5s...
        </div>
      </div>
    </div>
  </div>

  <!-- Bottom Kiosk Footer -->
  <footer>
    Station: {{ agent_id }} &bull; Scan, upload &amp; pay, then enter OTP to print
  </footer>

  <script>
    let currentOtp = "";
    let isSubmitting = false;
    let inactivityTimer = null;
    let autoResetTimer = null;

    const otpSlots = document.querySelectorAll('.otp-slot');
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

    function resetInactivityTimer() {
      clearTimeout(inactivityTimer);
      if (currentOtp.length > 0 && !isSubmitting) {
        inactivityTimer = setTimeout(() => {
          currentOtp = "";
          updateDisplay();
          hideAlert();
        }, 30000);
      }
    }

    function updateDisplay() {
      otpSlots.forEach((slot, index) => {
        if (index < currentOtp.length) {
          slot.textContent = currentOtp[index];
          slot.classList.add('filled');
          slot.classList.remove('active');
        } else if (index === currentOtp.length) {
          slot.textContent = "";
          slot.classList.remove('filled');
          slot.classList.add('active');
        } else {
          slot.textContent = "";
          slot.classList.remove('filled');
          slot.classList.remove('active');
        }
      });

      if (currentOtp.length === 6 && !isSubmitting) {
        printBtn.disabled = false;
      } else {
        printBtn.disabled = true;
      }

      resetInactivityTimer();
    }

    function showAlert(title, message, isError = true) {
      alertTitle.textContent = title;
      alertMessage.textContent = message;
      alertBanner.className = isError ? 'alert-banner error' : 'alert-banner success';
      alertBanner.style.display = 'block';
    }

    function hideAlert() {
      alertBanner.style.display = 'none';
      alertBanner.className = 'alert-banner';
    }

    function showErrorSlots() {
      const container = document.getElementById('otpContainer');
      if (container) {
        container.classList.remove('shake');
        void container.offsetWidth;
        container.classList.add('shake');
      }
      otpSlots.forEach(slot => slot.classList.add('error'));
    }

    function clearErrorSlots() {
      const container = document.getElementById('otpContainer');
      if (container) container.classList.remove('shake');
      otpSlots.forEach(slot => slot.classList.remove('error'));
    }

    function pressDigit(val) {
      handleKeyPress(val);
    }

    function clearOtp() {
      handleKeyPress('clear');
    }

    function handleKeyPress(val) {
      if (isSubmitting) return;
      hideAlert();
      clearErrorSlots();

      if (val === 'clear') {
        currentOtp = "";
      } else if (val === 'backspace') {
        currentOtp = currentOtp.slice(0, -1);
      } else if (/^[0-9]$/.test(val)) {
        if (currentOtp.length < 6) {
          currentOtp += val;
        }
      }
      updateDisplay();
    }

    document.querySelectorAll('.key-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        const key = btn.getAttribute('data-key');
        const action = btn.getAttribute('data-action');
        if (key) handleKeyPress(key);
        else if (action) handleKeyPress(action);
      });
    });

    document.addEventListener('keydown', (e) => {
      if (e.key >= '0' && e.key <= '9') {
        handleKeyPress(e.key);
      } else if (e.key === 'Backspace') {
        handleKeyPress('backspace');
      } else if (e.key === 'Escape' || e.key === 'Delete') {
        handleKeyPress('clear');
      } else if (e.key === 'Enter') {
        if (currentOtp.length === 6 && !isSubmitting) {
          submitOTP();
        }
      }
    });

    printBtn.addEventListener('click', (e) => {
      e.preventDefault();
      if (currentOtp.length === 6 && !isSubmitting) {
        submitOTP();
      }
    });

    async function submitOTP() {
      if (currentOtp.length !== 6 || isSubmitting) return;
      isSubmitting = true;
      printBtn.disabled = true;
      hideAlert();

      const modalPrinterBadge = document.getElementById('modalPrinterBadge');
      const modalPrinterName = document.getElementById('modalPrinterName');
      const modalProgressContainer = document.getElementById('modalProgressContainer');
      const modalProgressStep = document.getElementById('modalProgressStep');
      const modalProgressPercent = document.getElementById('modalProgressPercent');
      const modalProgressFill = document.getElementById('modalProgressFill');

      modalIconWrap.className = 'modal-icon-wrap loading';
      modalSpinner.style.display = 'block';
      modalCheckIcon.style.display = 'none';
      const modalErrorIcon = document.getElementById('modalErrorIcon');
      if (modalErrorIcon) modalErrorIcon.style.display = 'none';
      modalTitle.textContent = 'Verifying Code';
      modalMessage.textContent = 'Validating release OTP...';
      modalPrinterBadge.style.display = 'none';
      modalProgressContainer.style.display = 'block';
      modalProgressFill.className = 'kiosk-progress-fill';
      modalProgressFill.style.width = '15%';
      modalProgressPercent.textContent = '15%';
      modalProgressStep.textContent = 'Verifying OTP...';
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
          const targetPrinter = data.friendlyPrinter || data.printerName || 'Department printer';
          modalPrinterName.textContent = targetPrinter;
          modalPrinterBadge.style.display = 'inline-flex';
          modalTitle.textContent = 'Printing In Progress';
          modalMessage.textContent = 'Printing job on ' + targetPrinter + '...';
          modalProgressFill.style.width = '40%';
          modalProgressPercent.textContent = '40%';
          modalProgressStep.textContent = 'Connecting to ' + targetPrinter + '...';

          const jobId = data.jobId;
          let currentPct = 40;
          let pollAttempts = 0;
          const maxPollAttempts = 600;

          const progressInterval = setInterval(async () => {
            pollAttempts += 1;
            try {
              if (jobId) {
                const statusRes = await fetch(`/local/job-status/${jobId}`);
                if (statusRes.ok) {
                  const jobData = await statusRes.json();
                  if (jobData.friendly_printer) {
                    modalPrinterName.textContent = jobData.friendly_printer;
                  }
                  if (jobData.status === 'COMPLETED') {
                    finishJob(targetPrinter);
                    return;
                  } else if (jobData.status === 'FAILED') {
                    clearInterval(progressInterval);
                    modalTitle.textContent = 'Printing Failed';
                    modalMessage.textContent = jobData.message || 'Ask the attendant for help.';
                    modalSpinner.style.display = 'none';
                    if (modalErrorIcon) modalErrorIcon.style.display = 'block';
                    return;
                  } else if (jobData.progress && jobData.progress > currentPct) {
                    currentPct = jobData.progress;
                    modalProgressFill.style.width = currentPct + '%';
                    modalProgressPercent.textContent = currentPct + '%';
                    modalProgressStep.textContent = jobData.message || ('Printing on ' + targetPrinter + '...');
                    return;
                  }
                }
              }
            } catch (_) {}

            if (currentPct < 90) {
              currentPct += Math.min(14, 90 - currentPct);
              modalProgressFill.style.width = currentPct + '%';
              modalProgressPercent.textContent = currentPct + '%';
              modalProgressStep.textContent = 'Printing pages on ' + targetPrinter + '...';
            }

            if (pollAttempts >= maxPollAttempts) {
              clearInterval(progressInterval);
              modalTitle.textContent = 'Still awaiting printer confirmation';
              modalMessage.textContent = 'Check your order on your phone or ask the attendant. Completion has not been confirmed.';
            }
          }, 2000);

          function finishJob(printer) {
            clearInterval(progressInterval);
            modalProgressFill.className = 'kiosk-progress-fill completed';
            modalProgressFill.style.width = '100%';
            modalProgressPercent.textContent = '100%';
            modalProgressStep.textContent = 'Print Job Finished';

            modalIconWrap.className = 'modal-icon-wrap success';
            modalSpinner.style.display = 'none';
            modalCheckIcon.style.display = 'block';
            modalTitle.textContent = 'Printing Completed!';
            modalMessage.textContent = 'Please collect your printed document from ' + printer + '.';
            modalCountdown.style.display = 'inline-block';

            let secondsLeft = 3;
            modalCountdown.textContent = `Reloading kiosk in ${secondsLeft}s...`;
            const countdownInterval = setInterval(() => {
              secondsLeft -= 1;
              if (secondsLeft > 0) {
                modalCountdown.textContent = `Reloading kiosk in ${secondsLeft}s...`;
              } else {
                clearInterval(countdownInterval);
                window.location.reload();
              }
            }, 1000);
          }

        } else {
          const errCode = data.error || 'INVALID_OTP';
          let errTitle = 'Invalid OTP';
          let errMsg = data.message || 'Incorrect OTP code. Please check your phone.';

          if (errCode === 'OTP_EXPIRED') {
            errTitle = 'OTP Expired';
            errMsg = 'OTP has expired. Please check your order status on your phone.';
          } else if (errCode === 'ORDER_ALREADY_COMPLETED' || errCode === 'ALREADY_PRINTED') {
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
            errMsg = 'Maximum OTP attempts exceeded. Please generate a new OTP.';
          } else if (!data.message) {
            errMsg = 'Invalid OTP code. Please verify the code on your phone and try again.';
          }

          modalIconWrap.className = 'modal-icon-wrap error';
          modalSpinner.style.display = 'none';
          if (modalErrorIcon) modalErrorIcon.style.display = 'block';
          modalTitle.textContent = errTitle;
          modalMessage.textContent = errMsg;
          modalProgressContainer.style.display = 'none';

          setTimeout(() => {
            statusModal.style.display = 'none';
            isSubmitting = false;
            showAlert(errTitle, errMsg, true);
            showErrorSlots();
            currentOtp = "";
            updateDisplay();
          }, 1200);
        }
      } catch (err) {
        modalIconWrap.className = 'modal-icon-wrap error';
        modalSpinner.style.display = 'none';
        const modalErrorIcon = document.getElementById('modalErrorIcon');
        if (modalErrorIcon) modalErrorIcon.style.display = 'block';
        modalTitle.textContent = 'Connection Error';
        modalMessage.textContent = 'Local print station cannot communicate with service.';
        modalProgressContainer.style.display = 'none';

        setTimeout(() => {
          statusModal.style.display = 'none';
          isSubmitting = false;
          showAlert('Connection Error', 'Local print station cannot communicate with service.', true);
          showErrorSlots();
          currentOtp = "";
          updateDisplay();
        }, 1200);
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
      } catch (e) {}

      // Refresh the configured station QR without changing an identical image
      try {
        const qrRes = await fetch('/kiosk/qr-status');
        if (qrRes.ok) {
          const qrData = await qrRes.json();
          const qrImg = document.getElementById('kioskQrImg');
          const qrUrl = document.getElementById('kioskQrUrlText');
          const tunnelBadge = document.getElementById('kioskTunnelBadge');
          if (qrImg && qrData.qr_data_uri && qrImg.src !== qrData.qr_data_uri) qrImg.src = qrData.qr_data_uri;
          if (qrUrl && qrData.target_url) qrUrl.textContent = qrData.target_url;
          if (tunnelBadge) tunnelBadge.style.display = qrData.is_tunneled ? 'inline-flex' : 'none';
        }
      } catch (e) {}
    }

    // Run check immediately on load:
    checkPrinterHealth();

    // Wait until the previous check finishes; slow CUPS/backend calls cannot pile up.
    async function pollStationHealth() {
      await checkPrinterHealth();
      setTimeout(pollStationHealth, 5000);
    }
    setTimeout(pollStationHealth, 5000);

    updateDisplay();
  </script>
</body>
</html>
"""

SMART_GATEWAY_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <link rel="icon" href="/static/achuppori-logo.png">
  <title>Achuppori</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&family=JetBrains+Mono:wght@600;700&display=swap" rel="stylesheet">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, sans-serif;
      background: #090d16;
      color: #f8fafc;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      width: 100%;
      max-width: 440px;
      background: #0f172a;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 24px;
      padding: 32px 24px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.05);
      text-align: center;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 5px 12px;
      border-radius: 20px;
      background: rgba(16, 185, 129, 0.12);
      border: 1px solid rgba(16, 185, 129, 0.3);
      color: #34d399;
      font-size: 0.78rem;
      font-weight: 700;
      letter-spacing: 0.3px;
      margin-bottom: 20px;
    }
    .badge-dot {
      width: 6px;
      height: 6px;
      background: #10b981;
      border-radius: 50%;
      box-shadow: 0 0 8px #10b981;
    }
    .icon-wrapper {
      width: 64px;
      height: 64px;
      margin: 0 auto 20px;
      background: linear-gradient(135deg, #3b82f6, #1d4ed8);
      border-radius: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 10px 25px -5px rgba(37, 99, 235, 0.4);
    }
    .icon-wrapper svg {
      width: 32px;
      height: 32px;
      fill: #ffffff;
    }
    h1 {
      font-size: 1.45rem;
      font-weight: 800;
      letter-spacing: -0.4px;
      margin-bottom: 8px;
      color: #ffffff;
    }
    p.subtitle {
      font-size: 0.88rem;
      color: #94a3b8;
      line-height: 1.5;
      margin-bottom: 24px;
    }
    .specs-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 10px;
      margin-bottom: 24px;
      text-align: left;
    }
    .spec-item {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 14px;
      padding: 12px 14px;
    }
    .spec-label {
      font-size: 0.72rem;
      color: #64748b;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      margin-bottom: 4px;
    }
    .spec-val {
      font-size: 0.85rem;
      color: #f1f5f9;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 5px;
    }
    .btn-primary {
      width: 100%;
      padding: 15px;
      background: linear-gradient(135deg, #2563eb, #1d4ed8);
      color: #ffffff;
      border: none;
      border-radius: 14px;
      font-size: 1rem;
      font-weight: 700;
      text-decoration: none;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      box-shadow: 0 10px 20px -3px rgba(37, 99, 235, 0.35);
      transition: transform 0.15s ease, box-shadow 0.15s ease;
      cursor: pointer;
    }
    .btn-primary:active {
      transform: scale(0.98);
    }
    .footer-note {
      margin-top: 18px;
      font-size: 0.75rem;
      color: #475569;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="badge">
      <span class="badge-dot"></span>
      <span>Station Online & Ready</span>
    </div>

    <div class="icon-wrapper">
        <img src="/static/achuppori-logo.png" alt="Achuppori" style="width:100%;height:100%;object-fit:contain;border-radius:inherit">
    </div>

    <h1>Achuppori</h1>
    <p class="subtitle">Upload documents from your phone, complete checkout, and collect printed pages with your 6-digit PIN.</p>

    <div class="specs-grid">
      <div class="spec-item">
        <div class="spec-label">Print Station</div>
        <div class="spec-val">Kiosk Unit 1 & 2</div>
      </div>
      <div class="spec-item">
        <div class="spec-label">Supported Files</div>
        <div class="spec-val">PDF · PNG · JPG</div>
      </div>
      <div class="spec-item">
        <div class="spec-label">Speed</div>
        <div class="spec-val">~2.5s / Page</div>
      </div>
      <div class="spec-item">
        <div class="spec-label">Security</div>
        <div class="spec-val">256-Bit SSL PIN</div>
      </div>
    </div>

    <a href="{{ web_url }}/" class="btn-primary" id="openWebBtn">
      <span>Upload Documents</span>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="5" y1="12" x2="19" y2="12"></line><polyline points="12 5 19 12 12 19"></polyline></svg>
    </a>

    <div class="footer-note">
      Secure Self-Service Kiosk Network · Instant Release
    </div>
  </div>

  <script>
    // Automatically transition to web upload workflow
    setTimeout(() => {
      window.location.href = "{{ web_url }}/";
    }, 400);
  </script>
</body>
</html>
"""


@kiosk_bp.route("/kiosk", methods=["GET"])
def render_kiosk():
    web_url = get_web_url()
    qr_target = get_customer_url()
    qr_data_uri = generate_qr_base64(qr_target)

    return render_template_string(
        KIOSK_HTML,
        printer_name=config.PRINTER_NAME,
        agent_id=config.AGENT_ID,
        web_url=web_url,
        qr_data_uri=qr_data_uri,
        is_tunneled=False
    )

@kiosk_bp.route("/kiosk/qr-status", methods=["GET"])
def get_qr_status():
    """Live QR code status polling endpoint for kiosk display screen."""
    target_url = get_customer_url()
    qr_data_uri = generate_qr_base64(target_url)
    return jsonify({
        "is_tunneled": False,
        "target_url": target_url,
        "qr_data_uri": qr_data_uri,
    })

@kiosk_bp.route("/kiosk/open", methods=["GET"])
def smart_gateway():
    """Smart gateway: opens installed app if present, or redirects to web app."""
    web_url = get_customer_url()
    return render_template_string(SMART_GATEWAY_HTML, web_url=web_url)


@kiosk_bp.route("/", methods=["GET"])
def index():
    return redirect(url_for("kiosk.render_kiosk"))
