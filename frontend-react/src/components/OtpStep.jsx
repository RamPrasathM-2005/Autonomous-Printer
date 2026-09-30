import React, { useState, useEffect } from 'react';
import { Copy, Check, Clock, RotateCcw, MapPin, Printer } from 'lucide-react';

export default function OtpStep({ finalData, onReset }) {
  const { order, otp } = finalData;
  const [copied, setCopied] = useState(false);
  const [secondsLeft, setSecondsLeft] = useState(() => {
    const rawExp = order?.expires_at || order?.expiresAt;
    if (rawExp) {
      const expMs = new Date(rawExp.replace(' ', 'T')).getTime();
      const diff = Math.floor((expMs - Date.now()) / 1000);
      if (diff > 0) return diff;
    }
    return 86400; // 24 hours / 1 day
  });

  useEffect(() => {
    const timer = setInterval(() => {
      setSecondsLeft((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const formatCountdown = (secs) => {
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = secs % 60;
    if (h > 0) {
      return `${h}h ${m < 10 ? '0' : ''}${m}m ${s < 10 ? '0' : ''}${s}s`;
    }
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(otp);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const otpDigits = (otp || '------').split('');

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto', textAlign: 'center' }}>
      <h2 style={{ fontSize: '1.65rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px', marginBottom: '0.35rem' }}>
        Your Kiosk Release Code
      </h2>
      <p style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', maxWidth: '480px', margin: '0 auto' }}>
        Enter this 6-digit code on the kiosk touchscreen terminal at the printer machine to release your document.
      </p>

      {/* Large 6-Digit Display Card - Matches Flutter OtpReleaseScreen */}
      <div className="otp-display-card">
        <div style={{ color: 'var(--text-muted)', fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '1.2px', fontWeight: 800 }}>
          6-DIGIT RELEASE CODE
        </div>

        {/* 6 Digit Boxes */}
        <div className="otp-box-row">
          {otpDigits.map((digit, idx) => (
            <div key={idx} className="otp-digit-box">
              {digit}
            </div>
          ))}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
          <button
            onClick={handleCopy}
            className="btn-secondary"
            style={{ borderRadius: '12px', padding: '0.45rem 1rem', fontSize: '0.82rem' }}
          >
            {copied ? (
              <>
                <Check size={15} color="#10b981" />
                <span style={{ color: '#10b981' }}>Copied to Clipboard</span>
              </>
            ) : (
              <>
                <Copy size={15} />
                <span>Copy Code</span>
              </>
            )}
          </button>

          <div className="countdown-badge">
            <Clock size={14} />
            <span>Expires in {formatCountdown(secondsLeft)}</span>
          </div>
        </div>
      </div>

      {/* Physical Kiosk Walk-Up Guidance Card */}
      <div className="card-white" style={{ textAlign: 'left', marginBottom: '1.5rem', background: '#f8fafc', border: '1.5px solid #e2e8f0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem', marginBottom: '0.75rem' }}>
          <MapPin size={20} color="var(--primary)" />
          <h4 style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)' }}>
            How to Collect Your Print at the Station:
          </h4>
        </div>
        <ol style={{ paddingLeft: '1.25rem', color: 'var(--text-secondary)', fontSize: '0.85rem', lineHeight: 1.6 }}>
          <li>Go physically to the Ubuntu printer station.</li>
          <li>The machine screen is running the dedicated <strong>Autonomous Printer Kiosk</strong>.</li>
          <li>Enter your <strong>{otp}</strong> code on the kiosk numeric keypad.</li>
          <li>Tap <strong>PRINT</strong> to collect your document from the printer output tray.</li>
        </ol>
      </div>

      <button
        onClick={onReset}
        className="btn-primary"
        style={{ padding: '0.85rem' }}
      >
        <RotateCcw size={16} />
        <span>Start New Print Order</span>
      </button>
    </div>
  );
}
