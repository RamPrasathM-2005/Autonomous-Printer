import os
import io
import socket
import base64
import subprocess
from pathlib import Path
from flask import Blueprint, render_template_string, redirect, url_for, send_file, request, jsonify, Response
import qrcode
from app.config import config

kiosk_bp = Blueprint("kiosk", __name__)

def get_station_ip() -> str:
    """Detect the local LAN IP of the Ubuntu station machine so mobile phones can connect."""
    override = os.getenv("KIOSK_HOST_IP")
    if override:
        return override
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def is_tunnel_alive() -> bool:
    """Checks whether cloudflared quick tunnel daemon is actively running."""
    try:
        res = subprocess.run(["pgrep", "-f", "cloudflared.*tunnel"], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False

def get_tunnel_url() -> str | None:
    """Returns active Cloudflare quick tunnel URL if cloudflared is running."""
    if not is_tunnel_alive():
        return None
    candidates = [
        Path(os.getcwd()) / "storage" / "tunnel_url.txt",
        Path(__file__).resolve().parent.parent.parent.parent / "storage" / "tunnel_url.txt",
        Path(__file__).resolve().parent.parent.parent / "storage" / "tunnel_url.txt",
    ]
    for p in candidates:
        if p.exists():
            try:
                url = p.read_text().strip()
                if url.startswith("http"):
                    return url
            except Exception:
                pass
    return None

def get_web_url() -> str:
    """Returns the URL of the customer web app (prefers active Cloudflare tunnel if available)."""
    override = os.getenv("KIOSK_WEB_URL")
    if override:
        return override
    tunnel = get_tunnel_url()
    if tunnel:
        return tunnel
    ip = get_station_ip()
    return f"http://{ip}:3000"

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
    img.save(buf, format="PNG")
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

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
      padding: 12px 28px;
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

    /* Header Download APK Button */
    .header-apk-btn {
      display: flex;
      align-items: center;
      gap: 7px;
      background: linear-gradient(135deg, #10b981 0%, #059669 100%);
      color: #ffffff;
      padding: 7px 14px;
      border-radius: 9999px;
      font-size: 0.78rem;
      font-weight: 700;
      text-decoration: none;
      box-shadow: 0 2px 10px rgba(16, 185, 129, 0.25);
      transition: all 0.15s ease;
      cursor: pointer;
    }

    .header-apk-btn:hover {
      background: linear-gradient(135deg, #059669 0%, #047857 100%);
      transform: translateY(-1px);
    }

    .header-apk-btn svg {
      width: 15px;
      height: 15px;
      fill: currentColor;
    }

    .apk-tag {
      background: rgba(255, 255, 255, 0.25);
      padding: 1px 5px;
      border-radius: 4px;
      font-size: 0.65rem;
      font-weight: 800;
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
      padding: 20px 24px;
    }

    .kiosk-grid {
      display: grid;
      grid-template-columns: 1fr 1.15fr;
      gap: 28px;
      width: 100%;
      align-items: stretch;
    }

    @media (max-width: 880px) {
      .kiosk-grid {
        grid-template-columns: 1fr;
      }
    }

    /* Left Card: QR Code & Mobile Info */
    .kiosk-card-left {
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 20px;
      padding: 26px 24px;
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
      font-size: 1.35rem;
      font-weight: 800;
      color: var(--text);
      margin-bottom: 6px;
    }

    .kiosk-card-left p {
      font-size: 0.85rem;
      color: var(--text-muted);
      max-width: 320px;
      line-height: 1.45;
      margin-bottom: 16px;
    }

    /* QR Code Display Frame */
    .qr-frame {
      background: #ffffff;
      padding: 14px;
      border-radius: 18px;
      box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08), 0 0 15px rgba(37, 99, 235, 0.08);
      border: 2px solid var(--border);
      margin-bottom: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      transition: transform 0.2s ease;
    }

    .qr-frame:hover {
      transform: scale(1.02);
    }

    .qr-frame img {
      width: 200px;
      height: 200px;
      display: block;
      image-rendering: pixelated;
    }

    .qr-url-pill {
      background: var(--surface-card);
      border: 1px solid var(--border);
      border-radius: 8px;
      padding: 6px 12px;
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.78rem;
      color: #0284c7;
      word-break: break-all;
      margin-bottom: 16px;
      max-width: 340px;
    }

    .kiosk-card-left .action-group {
      width: 100%;
      display: flex;
      flex-direction: column;
      gap: 12px;
      align-items: center;
    }

    .btn-download-kiosk {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
      width: 100%;
      max-width: 320px;
      background: linear-gradient(135deg, #10b981 0%, #059669 100%);
      color: #ffffff;
      padding: 11px 18px;
      border-radius: 12px;
      font-size: 0.88rem;
      font-weight: 700;
      text-decoration: none;
      box-shadow: 0 4px 14px rgba(16, 185, 129, 0.25);
      transition: all 0.15s ease;
    }

    .btn-download-kiosk:hover {
      background: linear-gradient(135deg, #059669 0%, #047857 100%);
      transform: translateY(-1px);
      box-shadow: 0 6px 18px rgba(16, 185, 129, 0.35);
    }

    .btn-download-kiosk svg {
      width: 18px;
      height: 18px;
      fill: currentColor;
    }

    /* 3 Simple Steps */
    .steps-list {
      display: flex;
      justify-content: space-between;
      width: 100%;
      max-width: 340px;
      margin-top: 14px;
      border-top: 1px solid var(--border);
      padding-top: 12px;
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
      padding: 26px 26px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.05), 0 1px 3px rgba(0, 0, 0, 0.05);
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      position: relative;
    }

    .card-title-group {
      text-align: center;
      margin-bottom: 18px;
    }

    .card-title-group h2 {
      font-size: 1.45rem;
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
      gap: 10px;
      margin-bottom: 18px;
    }

    .otp-slot {
      width: 50px;
      height: 60px;
      background: #f8fafc;
      border: 2px solid #cbd5e1;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-family: 'JetBrains Mono', monospace;
      font-size: 1.85rem;
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
      gap: 10px;
      margin-bottom: 16px;
    }

    .key-btn {
      background: var(--key-bg);
      border: 1.5px solid var(--border);
      border-radius: 12px;
      height: 56px;
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
      height: 56px;
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

    footer {
      width: 100%;
      text-align: center;
      padding: 12px 20px;
      font-size: 0.76rem;
      color: var(--text-dim);
      border-top: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.85);
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

    <div class="station-actions">
      <!-- Download APK in Header -->
      <a href="{{ apk_url }}" download="autonomous-printer.apk" class="header-apk-btn" id="headerApkBtn" title="Download Android Mobile App (.apk)">
        <svg viewBox="0 0 24 24">
          <path d="M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.551 0 .9996.4482.9996.9993.0001.5511-.4485.9997-.9996.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4482.9993.9993 0 .5511-.4482.9997-.9993.9997m11.4045-6.02l1.996-3.4572c.1147-.1994.0463-.4543-.1531-.569-.1998-.1147-.4547-.0463-.5694.1531l-2.0258 3.5088C15.426 8.1633 13.7667 7.76 12 7.76s-3.426.4033-5.1292 1.1971L4.845 5.4483c-.1147-.1994-.3696-.2678-.5694-.1531-.1994.1147-.2678.3696-.1531.569l1.996 3.4572C2.6889 11.1867 0 14.92 0 19.28h24c0-4.36-2.6889-8.0933-6.1185-9.9586"/>
        </svg>
        <span>Download App</span>
        <span class="apk-tag">.APK</span>
      </a>

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
          <div class="qr-badge-pill">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14H9V8h2v8zm4 0h-2V8h2v8z"/>
            </svg>
            1. SCAN FROM PHONE
          </div>
          <h2>Print from your Phone</h2>
          <p>Scan with your phone camera to open the Web App or Android App instantly.</p>
        </div>

        <!-- High-Contrast QR Code -->
        <div class="qr-frame">
          <img src="{{ qr_data_uri }}" alt="Scan QR Code to Print" id="kioskQrImg" />
        </div>

        <div class="qr-url-pill" id="kioskQrUrlText">
          {{ web_url }}
        </div>
        <div id="kioskTunnelBadge" style="display: {{ 'inline-flex' if is_tunneled else 'none' }}; align-items: center; justify-content: center; gap: 6px; margin: 8px auto 0; font-size: 0.75rem; font-weight: 700; color: #60a5fa; background: rgba(59, 130, 246, 0.15); border: 1px solid rgba(59, 130, 246, 0.35); padding: 4px 12px; border-radius: 20px; width: fit-content;">
          ⚡ Cloudflare Quick Tunnel Active
        </div>

        <!-- Direct Actions -->
        <div class="action-group">
          <a href="{{ apk_url }}" download="autonomous-printer.apk" class="btn-download-kiosk" id="kioskDownloadApkBtn">
            <svg viewBox="0 0 24 24">
              <path d="M5 20h14v-2H5v2zM19 9h-4V3H9v6H5l7 7 7-7z"/>
            </svg>
            <span>Download Mobile App (.apk)</span>
          </a>

          <div class="steps-list">
            <div class="step-micro">
              <span class="num">1</span>
              <span>Scan QR Code</span>
            </div>
            <div class="step-micro">
              <span class="num">2</span>
              <span>Upload & Pay</span>
            </div>
            <div class="step-micro">
              <span class="num">3</span>
              <span>Enter OTP Here</span>
            </div>
          </div>
        </div>
      </div>

      <!-- RIGHT COLUMN: 6-Digit Release Keypad -->
      <div class="kiosk-card-right">
        <div class="card-title-group">
          <div class="qr-badge-pill" style="background: rgba(16, 185, 129, 0.15); border-color: rgba(16, 185, 129, 0.35); color: #34d399;">
            2. INSTANT RELEASE
          </div>
          <h2>Enter your 6-digit OTP</h2>
          <p>Enter the release code from your phone to print immediately.</p>
        </div>

        <!-- Alert Banner for Errors or Notices -->
        <div class="alert-banner" id="alertBanner">
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
          <button class="key-btn action-btn backspace-btn" data-action="backspace">
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
      </div>
      <div class="modal-content">
        <h3 id="modalTitle">OTP Verified</h3>
        <p id="modalMessage">Sending document to physical printer...</p>
        <div class="countdown-pill" id="modalCountdown" style="display:none;">
          Resetting screen in 8s...
        </div>
      </div>
    </div>
  </div>

  <!-- Bottom Kiosk Footer -->
  <footer>
    Station ID: {{ agent_id }} &bull; Printer: {{ printer_name }} &bull; OTP Valid for 24 Hours &bull; Autonomous Self-Service
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
    }

    function hideAlert() {
      alertBanner.style.display = 'none';
      alertBanner.className = 'alert-banner';
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
          modalIconWrap.className = 'modal-icon-wrap success';
          modalSpinner.style.display = 'none';
          modalCheckIcon.style.display = 'block';
          modalTitle.textContent = 'Printing Started';
          modalMessage.textContent = 'Please collect your document from the printer.';
          modalCountdown.style.display = 'inline-block';

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
          statusModal.style.display = 'none';
          isSubmitting = false;

          const errCode = data.error || 'ERROR';
          let errTitle = 'Invalid OTP';
          let errMsg = 'Please check the OTP and try again.';

          if (errCode === 'OTP_EXPIRED') {
            errTitle = 'OTP Expired';
            errMsg = 'OTP has expired (valid 24h). Please request a new order.';
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
            errMsg = 'Maximum OTP attempts exceeded. Please generate a new OTP.';
          } else {
            errMsg = data.message || 'Please check the OTP and try again.';
          }

          showAlert(errTitle, errMsg, true);
          currentOtp = "";
          updateDisplay();
        }
      } catch (err) {
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

      // Poll active QR status (dynamically updates when Cloudflare tunnel is started)
      try {
        const qrRes = await fetch('/kiosk/qr-status');
        if (qrRes.ok) {
          const qrData = await qrRes.json();
          const qrImg = document.getElementById('kioskQrImg');
          const qrUrl = document.getElementById('kioskQrUrlText');
          const tunnelBadge = document.getElementById('kioskTunnelBadge');
          const dlBtn = document.getElementById('kioskDownloadApkBtn');
          if (qrImg && qrData.qr_data_uri) qrImg.src = qrData.qr_data_uri;
          if (qrUrl && qrData.target_url) qrUrl.textContent = qrData.target_url;
          if (tunnelBadge) tunnelBadge.style.display = qrData.is_tunneled ? 'inline-flex' : 'none';
          if (dlBtn && qrData.apk_url) dlBtn.href = qrData.apk_url;
        }
      } catch (e) {}
    }
    setInterval(checkPrinterHealth, 4000);

    updateDisplay();
  </script>
</body>
</html>
"""

SMART_GATEWAY_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Autonomous Printer - Connecting...</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0b0f19;
      color: #f8fafc;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      padding: 24px;
      text-align: center;
    }
    .card {
      background: #111827;
      border: 1px solid #1f2d44;
      border-radius: 20px;
      padding: 32px 24px;
      max-width: 420px;
      width: 100%;
      box-shadow: 0 10px 30px rgba(0,0,0,0.5);
    }
    .spinner {
      width: 44px;
      height: 44px;
      border: 4px solid rgba(255,255,255,0.2);
      border-top-color: #3b82f6;
      border-radius: 50%;
      animation: spin 0.8s linear infinite;
      margin: 0 auto 20px;
    }
    @keyframes spin { to { transform: rotate(360deg); } }
    h2 { font-size: 1.35rem; margin-bottom: 8px; }
    p { font-size: 0.88rem; color: #94a3b8; line-height: 1.5; margin-bottom: 24px; }
    .btn-group { display: flex; flex-direction: column; gap: 12px; }
    .btn {
      padding: 13px 20px;
      border-radius: 12px;
      font-size: 0.95rem;
      font-weight: 700;
      text-decoration: none;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 10px;
      transition: all 0.15s ease;
    }
    .btn-web { background: #2563eb; color: #ffffff; }
    .btn-apk { background: #10b981; color: #ffffff; }
  </style>
</head>
<body>
  <div class="card">
    <div class="spinner"></div>
    <h2>Connecting to Autonomous Printer</h2>
    <p>Opening Mobile App or Web App for seamless printing...</p>

    <div class="btn-group">
      <a href="{{ web_url }}/?scan=1" class="btn btn-web" id="webBtn">
        <span>Open Web App</span>
      </a>
      <a href="/downloads/autonomous-printer.apk" class="btn btn-apk" id="apkBtn">
        <span>Download Mobile App (.apk)</span>
      </a>
    </div>
  </div>

  <script>
    // Try launching the installed app via intent/scheme
    const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
    if (isMobile) {
      const iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = 'autonomousprinter://open';
      document.body.appendChild(iframe);
      setTimeout(() => {
        try { document.body.removeChild(iframe); } catch (_) {}
        // Fallback to web app after 600ms
        window.location.href = "{{ web_url }}/?scan=1";
      }, 700);
    } else {
      setTimeout(() => {
        window.location.href = "{{ web_url }}/?scan=1";
      }, 500);
    }
  </script>
</body>
</html>
"""

@kiosk_bp.route("/kiosk", methods=["GET"])
def render_kiosk():
    tunnel_url = get_tunnel_url()
    web_url = tunnel_url if tunnel_url else get_web_url()
    # QR code points directly to the active Cloudflare tunnel if available
    qr_target = tunnel_url if tunnel_url else f"http://{get_station_ip()}:{config.PORT}/kiosk/open"
    qr_data_uri = generate_qr_base64(qr_target)
    apk_url = f"{tunnel_url}/downloads/autonomous-printer.apk" if tunnel_url else f"http://{get_station_ip()}:{config.PORT}/downloads/autonomous-printer.apk"

    return render_template_string(
        KIOSK_HTML,
        printer_name=config.PRINTER_NAME,
        agent_id=config.AGENT_ID,
        web_url=web_url,
        qr_data_uri=qr_data_uri,
        apk_url=apk_url,
        is_tunneled=bool(tunnel_url)
    )

@kiosk_bp.route("/kiosk/qr-status", methods=["GET"])
def get_qr_status():
    """Live QR code status polling endpoint for kiosk display screen."""
    tunnel_url = get_tunnel_url()
    target_url = tunnel_url if tunnel_url else get_web_url()
    qr_data_uri = generate_qr_base64(target_url)
    apk_url = f"{tunnel_url}/downloads/autonomous-printer.apk" if tunnel_url else f"http://{get_station_ip()}:{config.PORT}/downloads/autonomous-printer.apk"
    return jsonify({
        "is_tunneled": bool(tunnel_url),
        "target_url": target_url,
        "qr_data_uri": qr_data_uri,
        "apk_url": apk_url,
    })

@kiosk_bp.route("/kiosk/open", methods=["GET"])
def smart_gateway():
    """Smart gateway: opens installed app if present, or redirects to web app."""
    web_url = get_web_url()
    return render_template_string(SMART_GATEWAY_HTML, web_url=web_url)

@kiosk_bp.route("/downloads/autonomous-printer.apk", methods=["GET"])
@kiosk_bp.route("/kiosk/download-apk", methods=["GET"])
def download_apk():
    """Serves the autonomous-printer.apk package."""
    candidates = [
        Path(os.getcwd()) / "downloads" / "autonomous-printer.apk",
        Path(__file__).parent.parent / "static" / "autonomous-printer.apk",
        Path(os.getcwd()) / "frontend-react" / "public" / "downloads" / "autonomous-printer.apk"
    ]
    for p in candidates:
        if p.exists():
            return send_file(
                str(p),
                mimetype="application/vnd.android.package-archive",
                as_attachment=True,
                download_name="autonomous-printer.apk"
            )
    return jsonify({"error": "APK not yet generated"}), 404

@kiosk_bp.route("/", methods=["GET"])
def index():
    return redirect(url_for("kiosk.render_kiosk"))
