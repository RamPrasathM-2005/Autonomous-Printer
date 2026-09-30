import React, { useState, useEffect } from 'react';
import { KeyRound, Copy, Check, Printer, ArrowRight, RotateCcw, AlertCircle, CheckCircle2, Loader2, Clock } from 'lucide-react';
import confetti from 'canvas-confetti';
import { api } from '../api';

export default function OtpStep({ finalData, onReset }) {
  const { order, otp } = finalData;
  const [copied, setCopied] = useState(false);
  const [releasing, setReleasing] = useState(false);
  const [printSuccess, setPrintSuccess] = useState(false);
  const [error, setError] = useState(null);
  const [secondsLeft, setSecondsLeft] = useState(900); // 15 mins

  useEffect(() => {
    const timer = setInterval(() => {
      setSecondsLeft((prev) => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const formatCountdown = (secs) => {
    const m = Math.floor(secs / 60);
    const s = secs % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(otp);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleDirectRelease = async () => {
    setReleasing(true);
    setError(null);
    try {
      await api.releaseJobWithOtp(otp);
      setPrintSuccess(true);
      confetti({
        particleCount: 100,
        spread: 90,
        origin: { y: 0.5 }
      });
    } catch (err) {
      setError(err.message || 'Failed to release print job');
    } finally {
      setReleasing(false);
    }
  };

  const otpDigits = (otp || '------').split('');

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto', textAlign: 'center' }}>
      <div style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.45rem',
        padding: '0.35rem 0.95rem',
        borderRadius: '9999px',
        background: 'var(--success-surface)',
        color: '#059669',
        fontWeight: 700,
        fontSize: '0.8rem',
        marginBottom: '0.85rem'
      }}>
        <CheckCircle2 size={16} /> Payment Confirmed
      </div>

      <h2 style={{ fontSize: '1.75rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px', marginBottom: '0.35rem' }}>
        Your Kiosk Release Code
      </h2>
      <p style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', maxWidth: '480px', margin: '0 auto' }}>
        Enter this 6-digit code on the Ubuntu printer station terminal, or click Auto Release below.
      </p>

      {/* Big 6-Digit Display Card - Exactly matches Flutter */}
      <div className="otp-display-card">
        <div style={{ color: 'var(--text-muted)', fontSize: '0.78rem', textTransform: 'uppercase', letterSpacing: '1.2px', fontWeight: 700 }}>
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
                <span>Copy Passcode</span>
              </>
            )}
          </button>

          <div className="countdown-badge">
            <Clock size={14} />
            <span>Valid for: {formatCountdown(secondsLeft)}</span>
          </div>
        </div>
      </div>

      {/* Printer Destination Card */}
      <div className="card-white" style={{ textAlign: 'left', marginBottom: '1.25rem' }}>
        <div className="summary-row">
          <span>Active Printer Queue</span>
          <span style={{ fontWeight: 700, color: 'var(--primary)' }}>HP_LaserJet_400_M401dn_F36EC0</span>
        </div>
        <div className="summary-row">
          <span>Order ID</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{order?.id || 'ORD-NEW'}</span>
        </div>
        <div className="summary-row">
          <span>Kiosk URL</span>
          <span style={{ fontWeight: 600, color: 'var(--text-secondary)' }}>http://127.0.0.1:5001/kiosk</span>
        </div>
      </div>

      {error && (
        <div style={{
          background: 'var(--danger-surface)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: 'var(--danger)',
          padding: '0.85rem',
          borderRadius: '12px',
          marginBottom: '1.25rem',
          fontSize: '0.85rem'
        }}>
          {error}
        </div>
      )}

      {printSuccess ? (
        <div style={{
          background: 'var(--success-surface)',
          border: '1px solid rgba(16, 185, 129, 0.4)',
          borderRadius: '18px',
          padding: '1.5rem',
          marginBottom: '1.5rem',
          color: '#065f46'
        }}>
          <CheckCircle2 size={36} color="#10b981" style={{ margin: '0 auto 0.5rem auto' }} />
          <h3 style={{ fontSize: '1.2rem', fontWeight: 800, color: '#065f46', marginBottom: '0.25rem' }}>
            Printing Dispatched!
          </h3>
          <p style={{ fontSize: '0.85rem' }}>
            Job submitted to HP_LaserJet_400_M401dn_F36EC0 via CUPS. Please collect your document from the printer output tray.
          </p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', marginBottom: '1.5rem' }}>
          <button
            className="btn-primary"
            onClick={handleDirectRelease}
            disabled={releasing}
          >
            {releasing ? (
              <>
                <Loader2 size={18} className="animate-spin" style={{ animation: 'spin 1s linear infinite' }} />
                <span>Releasing Job to HP LaserJet...</span>
              </>
            ) : (
              <>
                <Printer size={18} />
                <span>Release to Physical Printer Now</span>
              </>
            )}
          </button>
        </div>
      )}

      <button
        onClick={onReset}
        className="btn-secondary"
        style={{ width: '100%', padding: '0.75rem' }}
      >
        <RotateCcw size={16} />
        <span>Start New Print Order</span>
      </button>

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
