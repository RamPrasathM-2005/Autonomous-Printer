import React, { useState, useEffect } from 'react';
import { Copy, Check, Clock, RotateCcw, MapPin, Printer, CheckCircle2, AlertTriangle } from 'lucide-react';
import { api } from '../api';

export default function OtpStep({ finalData, onReset }) {
  const { order, otp } = finalData;
  const [copied, setCopied] = useState(false);
  const [orderStatus, setOrderStatus] = useState(order?.status || 'WAITING_FOR_OTP');
  const [isOutOfPaper, setIsOutOfPaper] = useState(false);
  const [statusMessage, setStatusMessage] = useState(null);

  useEffect(() => {
    const orderId = order?.id || order?.order_id;
    if (!orderId) return;

    const poll = async () => {
      try {
        const liveOrder = await api.getOrder(orderId);
        if (liveOrder) {
          setOrderStatus(liveOrder.status);
          const outOfPaper = (liveOrder.error_code === 'OUT_OF_PAPER') ||
            (liveOrder.error_message && liveOrder.error_message.toLowerCase().includes('paper'));
          setIsOutOfPaper(outOfPaper);
          if (liveOrder.error_message) {
            setStatusMessage(liveOrder.error_message);
          }
        }
      } catch (_) {}
    };

    const interval = setInterval(poll, 2500);
    return () => clearInterval(interval);
  }, [order]);

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
    <div style={{ maxWidth: '640px', margin: '0 auto', textAlign: 'center' }}>
      
      {/* Top Banner based on status */}
      {isOutOfPaper ? (
        <div style={{
          background: 'var(--warning-surface)',
          border: '1.5px solid rgba(245, 158, 11, 0.4)',
          borderRadius: '20px',
          padding: '1.15rem 1.5rem',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.85rem',
          marginBottom: '1.5rem',
          animation: 'slideDown 0.25s ease-out',
          textAlign: 'left'
        }}>
          <div style={{
            width: '38px',
            height: '38px',
            borderRadius: '50%',
            background: 'var(--warning)',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0
          }}>
            <AlertTriangle size={20} strokeWidth={2.5} />
          </div>
          <div>
            <div style={{ fontWeight: 800, fontSize: '0.98rem', color: '#92400e' }}>
              Printer Out of Paper!
            </div>
            <div style={{ fontSize: '0.82rem', color: '#b45309' }}>
              Your document is stored in the printer queue. Please insert sheets into the printer paper tray to begin printing.
            </div>
          </div>
        </div>
      ) : orderStatus === 'COMPLETED' ? (
        <div style={{
          background: 'var(--success-surface)',
          border: '1.5px solid rgba(16, 185, 129, 0.35)',
          borderRadius: '20px',
          padding: '1.15rem 1.5rem',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.75rem',
          marginBottom: '1.5rem',
          animation: 'slideDown 0.25s ease-out'
        }}>
          <div style={{
            width: '36px',
            height: '36px',
            borderRadius: '50%',
            background: 'var(--success)',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <CheckCircle2 size={22} strokeWidth={2.5} />
          </div>
          <div style={{ textAlign: 'left' }}>
            <div style={{ fontWeight: 800, fontSize: '0.98rem', color: '#065f46' }}>
              Printing Completed Successfully!
            </div>
            <div style={{ fontSize: '0.8rem', color: '#047857' }}>
              Please collect your printed pages from the HP LaserJet tray.
            </div>
          </div>
        </div>
      ) : orderStatus === 'PRINTING' ? (
        <div style={{
          background: 'var(--primary-surface)',
          border: '1.5px solid rgba(37, 99, 235, 0.35)',
          borderRadius: '20px',
          padding: '1.15rem 1.5rem',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.75rem',
          marginBottom: '1.5rem',
          animation: 'slideDown 0.25s ease-out'
        }}>
          <div style={{
            width: '36px',
            height: '36px',
            borderRadius: '50%',
            background: 'var(--primary)',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <Printer size={20} strokeWidth={2.5} />
          </div>
          <div style={{ textAlign: 'left' }}>
            <div style={{ fontWeight: 800, fontSize: '0.98rem', color: '#1e40af' }}>
              Printing in Progress...
            </div>
            <div style={{ fontSize: '0.8rem', color: '#2563eb' }}>
              HP LaserJet 400 M401dn is actively printing your document.
            </div>
          </div>
        </div>
      ) : (
        <div style={{
          background: 'var(--success-surface)',
          border: '1.5px solid rgba(16, 185, 129, 0.35)',
          borderRadius: '20px',
          padding: '1.15rem 1.5rem',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.75rem',
          marginBottom: '1.5rem',
          animation: 'slideDown 0.25s ease-out'
        }}>
          <div style={{
            width: '36px',
            height: '36px',
            borderRadius: '50%',
            background: 'var(--success)',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <Check size={20} strokeWidth={3} />
          </div>
          <div style={{ textAlign: 'left' }}>
            <div style={{ fontWeight: 800, fontSize: '0.98rem', color: '#065f46' }}>
              Payment Confirmed!
            </div>
            <div style={{ fontSize: '0.8rem', color: '#047857' }}>
              Your print release code has been generated successfully.
            </div>
          </div>
        </div>
      )}

      <h2 style={{ fontSize: '1.65rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px', marginBottom: '0.35rem' }}>
        Your Kiosk Release Code
      </h2>
      <p style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', maxWidth: '480px', margin: '0 auto 1.5rem' }}>
        Enter this 6-digit code on the kiosk touchscreen terminal at the printer machine to release your document.
      </p>

      {/* Large 6-Digit Display Card - Matches Flutter OtpReleaseScreen exactly */}
      <div className="otp-display-card" style={{ marginBottom: '1.5rem' }}>
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
      <div className="card-white" style={{ textAlign: 'left', marginBottom: '1.5rem', background: '#f8fafc', border: '1.5px solid #e2e8f0', borderRadius: '20px', padding: '1.35rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.65rem', marginBottom: '0.75rem' }}>
          <div style={{
            width: '32px',
            height: '32px',
            borderRadius: '8px',
            background: 'var(--primary-surface)',
            color: 'var(--primary)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}>
            <MapPin size={18} />
          </div>
          <h4 style={{ fontSize: '0.98rem', fontWeight: 800, color: 'var(--text-primary)', margin: 0 }}>
            How to Collect Your Print at the Station:
          </h4>
        </div>
        <ol style={{ paddingLeft: '1.5rem', color: 'var(--text-secondary)', fontSize: '0.88rem', lineHeight: 1.7, margin: 0 }}>
          <li>Go physically to the Ubuntu printer station (<strong>HP LaserJet 400 M401dn</strong>).</li>
          <li>The machine screen is running the dedicated <strong>Autonomous Printer Kiosk</strong>.</li>
          <li>Enter your <strong>{otp}</strong> code on the kiosk numeric keypad.</li>
          <li>Tap <strong>PRINT DOCUMENT</strong> to collect your pages from the printer tray.</li>
        </ol>
      </div>

      <button
        onClick={onReset}
        className="btn-primary"
        style={{ padding: '0.85rem 2rem', borderRadius: '16px' }}
      >
        <RotateCcw size={16} />
        <span>Start New Print Order</span>
      </button>
    </div>
  );
}
