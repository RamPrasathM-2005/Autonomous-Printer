import React, { useState, useEffect } from 'react';
import { Terminal, Delete, CheckCircle2, AlertCircle, Loader2, Printer, Sparkles, RefreshCw } from 'lucide-react';
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
    <div style={{ maxWidth: '640px', margin: '0 auto', textAlign: 'center' }}>
      <div style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.6rem',
        padding: '0.4rem 1.1rem',
        borderRadius: 'var(--radius-full)',
        background: 'rgba(99, 102, 241, 0.15)',
        color: '#a5b4fc',
        fontWeight: 700,
        fontSize: '0.85rem',
        marginBottom: '1rem'
      }}>
        <Terminal size={16} /> Campus Print Station Kiosk
      </div>

      <h1 style={{ fontSize: '2.4rem', fontWeight: 800, marginBottom: '0.4rem' }}>
        Release Print Job
      </h1>
      <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem', marginBottom: '2rem' }}>
        Enter your 6-digit OTP passcode below to physically print your document.
      </p>

      {/* Hardware Status Tile */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        background: 'var(--bg-secondary)',
        border: '1px solid var(--border-subtle)',
        borderRadius: 'var(--radius-md)',
        padding: '0.9rem 1.4rem',
        marginBottom: '2rem'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', textAlign: 'left' }}>
          <Printer size={20} color="#34d399" />
          <div>
            <div style={{ fontSize: '0.9rem', fontWeight: 700 }}>
              {stationInfo?.printer_name || 'HP_LaserJet_400_M401dn_F36EC0'}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
              Status: <span style={{ color: '#34d399', fontWeight: 600 }}>{stationInfo?.printer_state || 'READY'}</span> • Paper: {stationInfo?.paper_state || 'AVAILABLE'}
            </div>
          </div>
        </div>
        <button
          onClick={fetchStatus}
          style={{ background: 'transparent', border: 'none', color: 'var(--text-dim)', cursor: 'pointer' }}
          title="Refresh hardware status"
        >
          <RefreshCw size={16} />
        </button>
      </div>

      {releaseResult ? (
        <div className="glass-panel" style={{ padding: '2.5rem', textAlign: 'center' }}>
          <div style={{
            width: '64px',
            height: '64px',
            borderRadius: '50%',
            background: 'var(--success)',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 1.25rem auto'
          }}>
            <CheckCircle2 size={34} />
          </div>
          <h2 style={{ fontSize: '1.8rem', fontWeight: 800, marginBottom: '0.5rem', color: '#34d399' }}>
            Job Released Successfully!
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '1rem', marginBottom: '1.5rem' }}>
            {releaseResult.message || 'Document has been sent to the physical printer tray.'}
          </p>
          <button
            className="btn-primary"
            onClick={() => {
              setReleaseResult(null);
              setPin('');
            }}
          >
            Release Another Job
          </button>
        </div>
      ) : (
        <div className="glass-panel" style={{ padding: '2rem' }}>
          {/* OTP Digits Display */}
          <div className="otp-display-box">
            {[0, 1, 2, 3, 4, 5].map((idx) => {
              const char = pin[idx] || '';
              return (
                <div key={idx} className={`otp-digit ${char ? 'filled' : ''}`}>
                  {char}
                </div>
              );
            })}
          </div>

          {error && (
            <div style={{
              background: 'rgba(239, 68, 68, 0.12)',
              border: '1px solid rgba(239, 68, 68, 0.3)',
              color: '#f87171',
              padding: '0.75rem',
              borderRadius: 'var(--radius-md)',
              margin: '1rem 0',
              fontSize: '0.9rem',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '0.5rem'
            }}>
              <AlertCircle size={16} />
              <span>{error}</span>
            </div>
          )}

          {/* Touchscreen 0-9 Keypad */}
          <div className="keypad-grid">
            {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((num) => (
              <button
                key={num}
                type="button"
                className="keypad-btn"
                onClick={() => handleKeyPress(num.toString())}
                disabled={loading}
              >
                {num}
              </button>
            ))}
            <button
              type="button"
              className="keypad-btn"
              onClick={handleClear}
              disabled={loading}
              style={{ fontSize: '0.9rem', color: 'var(--text-muted)' }}
            >
              CLEAR
            </button>
            <button
              type="button"
              className="keypad-btn"
              onClick={() => handleKeyPress('0')}
              disabled={loading}
            >
              0
            </button>
            <button
              type="button"
              className="keypad-btn"
              onClick={handleBackspace}
              disabled={loading}
            >
              <Delete size={22} style={{ display: 'inline', verticalAlign: 'middle' }} />
            </button>
          </div>

          <div style={{ marginTop: '1.5rem' }}>
            <button
              className="btn-primary"
              onClick={() => submitOtp()}
              disabled={pin.length !== 6 || loading}
            >
              {loading ? (
                <>
                  <Loader2 size={20} style={{ animation: 'spin 1s linear infinite' }} />
                  <span>Verifying Passcode...</span>
                </>
              ) : (
                <span>PRINT DOCUMENT</span>
              )}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
