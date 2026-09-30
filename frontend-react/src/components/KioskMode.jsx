import React, { useState, useEffect } from 'react';
import { Terminal, Delete, CheckCircle2, AlertCircle, Loader2, Printer, RotateCcw } from 'lucide-react';
import confetti from 'canvas-confetti';
import { api } from '../api';

export default function KioskMode() {
  const [pin, setPin] = useState('');
  const [stationInfo, setStationInfo] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [releaseResult, setReleaseResult] = useState(null);

  const fetchStatus = async () => {
    const data = await api.getLocalStationStatus();
    setStationInfo(data);
  };

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 4000);
    return () => clearInterval(interval);
  }, []);

  const handleKeyPress = (num) => {
    if (pin.length < 6) {
      const nextPin = pin + num;
      setPin(nextPin);
      setError(null);
      if (nextPin.length === 6) {
        submitOtp(nextPin);
      }
    }
  };

  const handleBackspace = () => {
    setPin((prev) => prev.slice(0, -1));
    setError(null);
  };

  const handleClear = () => {
    setPin('');
    setError(null);
  };

  const submitOtp = async (codeToSubmit) => {
    const code = codeToSubmit || pin;
    if (code.length !== 6) return;

    setLoading(true);
    setError(null);

    try {
      const res = await api.releaseJobWithOtp(code);
      setReleaseResult(res);
      confetti({
        particleCount: 90,
        spread: 80,
        origin: { y: 0.6 }
      });
    } catch (err) {
      setError(err.message || 'Invalid or expired OTP. Please check your screen.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: '540px', margin: '0 auto', textAlign: 'center' }}>
      <div className="card-white" style={{ padding: '2rem 1.75rem', borderRadius: '24px' }}>
        {/* Header */}
        <div style={{ borderBottom: '1.5px dashed var(--border)', paddingBottom: '1rem', marginBottom: '1.25rem' }}>
          <div style={{ fontSize: '1.4rem', fontWeight: 800, letterSpacing: '1px', textTransform: 'uppercase', color: 'var(--text-primary)' }}>
            AUTONOMOUS PRINT
          </div>
          <div style={{ fontSize: '0.82rem', fontWeight: 700, letterSpacing: '2px', color: 'var(--primary)', textTransform: 'uppercase', marginTop: '2px' }}>
            PRINT STATION
          </div>
          <div style={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: '6px',
            fontSize: '0.75rem',
            fontWeight: 700,
            padding: '3px 10px',
            borderRadius: '9999px',
            background: 'var(--success-surface)',
            color: '#059669',
            border: '1px solid rgba(16, 185, 129, 0.3)',
            marginTop: '8px'
          }}>
            <span className="pulsing-dot" />
            <span>{stationInfo?.printer_name || 'HP_LaserJet_400_M401dn_F36EC0'}</span>
            <span style={{ opacity: 0.6 }}>(READY)</span>
          </div>
        </div>

        <div style={{ fontSize: '1.05rem', fontWeight: 700, color: 'var(--text-primary)', marginBottom: '1rem' }}>
          Enter your 6-digit OTP
        </div>

        {/* 6 Digit Display */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', marginBottom: '1.25rem' }}>
          {[0, 1, 2, 3, 4, 5].map((idx) => {
            const digit = pin[idx] || '';
            const isActive = pin.length === idx;
            return (
              <div
                key={idx}
                style={{
                  width: '46px',
                  height: '56px',
                  borderRadius: '12px',
                  background: '#f8fafc',
                  border: `2px solid ${digit ? 'var(--primary)' : (isActive ? 'var(--primary-light)' : 'var(--border)')}`,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  fontSize: '1.6rem',
                  fontWeight: 800,
                  color: 'var(--primary)',
                  boxShadow: digit ? '0 0 10px rgba(79, 70, 229, 0.2)' : 'none',
                  transition: 'all 0.15s ease'
                }}
              >
                {digit}
              </div>
            );
          })}
        </div>

        {/* Keypad */}
        <div className="kiosk-grid-keypad">
          {['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((n) => (
            <button key={n} type="button" className="kiosk-num-key" onClick={() => handleKeyPress(n)}>
              {n}
            </button>
          ))}
          <button type="button" className="kiosk-num-key kiosk-action-key" onClick={handleClear}>
            CLEAR
          </button>
          <button type="button" className="kiosk-num-key" onClick={() => handleKeyPress('0')}>
            0
          </button>
          <button type="button" className="kiosk-num-key kiosk-action-key" onClick={handleBackspace}>
            ⌫
          </button>
        </div>

        {/* Print Button */}
        <button
          className="btn-primary"
          style={{
            background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
            boxShadow: '0 4px 14px rgba(16, 185, 129, 0.35)',
            fontSize: '1.1rem',
            padding: '1rem',
            letterSpacing: '1px'
          }}
          disabled={pin.length !== 6 || loading}
          onClick={() => submitOtp()}
        >
          {loading ? (
            <>
              <Loader2 size={20} className="animate-spin" style={{ animation: 'spin 1s linear infinite' }} />
              <span>Verifying OTP...</span>
            </>
          ) : (
            <span>PRINT</span>
          )}
        </button>

        <div style={{ fontSize: '0.8rem', color: 'var(--text-secondary)', marginTop: '1rem' }}>
          Enter the OTP received after completing payment.
        </div>

        {/* Error notification */}
        {error && (
          <div style={{
            background: 'var(--danger-surface)',
            border: '1px solid rgba(239, 68, 68, 0.3)',
            color: 'var(--danger)',
            padding: '0.85rem',
            borderRadius: '12px',
            marginTop: '1rem',
            fontSize: '0.85rem',
            fontWeight: 600
          }}>
            {error}
          </div>
        )}

        {/* Success notification */}
        {releaseResult && (
          <div style={{
            background: 'var(--success-surface)',
            border: '1px solid rgba(16, 185, 129, 0.4)',
            color: '#065f46',
            padding: '1rem',
            borderRadius: '14px',
            marginTop: '1rem',
            fontSize: '0.88rem',
            fontWeight: 600
          }}>
            <CheckCircle2 size={22} color="#10b981" style={{ margin: '0 auto 0.25rem auto' }} />
            <div>OTP Verified & Printing Started</div>
            <div style={{ fontSize: '0.8rem', opacity: 0.85, marginTop: '2px' }}>
              Please collect your document from the printer output tray.
            </div>
          </div>
        )}
      </div>

      <style>{`
        @keyframes spin {
          from { transform: rotate(0deg); }
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
