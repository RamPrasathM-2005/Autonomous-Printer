import React, { useState } from 'react';
import { KeyRound, Copy, Check, Printer, ArrowRight, RotateCcw, AlertCircle, CheckCircle2, Loader2 } from 'lucide-react';
import confetti from 'canvas-confetti';
import { api } from '../api';

export default function OtpStep({ finalData, onReset }) {
  const { order, otp } = finalData;
  const [copied, setCopied] = useState(false);
  const [releasing, setReleasing] = useState(false);
  const [printSuccess, setPrintSuccess] = useState(false);
  const [error, setError] = useState(null);

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

  return (
    <div style={{ maxWidth: '650px', margin: '0 auto', textAlign: 'center' }}>
      <div style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '0.5rem',
        padding: '0.4rem 1rem',
        borderRadius: 'var(--radius-full)',
        background: 'rgba(16, 185, 129, 0.12)',
        color: '#34d399',
        fontWeight: 700,
        fontSize: '0.85rem',
        marginBottom: '1rem'
      }}>
        <CheckCircle2 size={16} /> Order Paid & Ready for Release
      </div>

      <h1 style={{ fontSize: '2.4rem', fontWeight: 800, marginBottom: '0.5rem' }}>
        Your Secure Print OTP
      </h1>
      <p style={{ color: 'var(--text-muted)', fontSize: '1rem', maxWidth: '500px', margin: '0 auto' }}>
        Enter this 6-digit code at any campus print terminal, or release it directly to the active hardware printer below.
      </p>

      {/* Big OTP Card */}
      <div className="otp-card">
        <div style={{ color: 'var(--text-muted)', fontSize: '0.85rem', textTransform: 'uppercase', letterSpacing: '0.1em' }}>
          One-Time Passcode
        </div>
        <div className="otp-code">
          {otp.split('').join(' ')}
        </div>
        <div>
          <button
            onClick={handleCopy}
            className="btn-secondary"
            style={{ borderRadius: 'var(--radius-full)', padding: '0.5rem 1.25rem' }}
          >
            {copied ? (
              <>
                <Check size={16} color="#10b981" />
                <span style={{ color: '#10b981' }}>Copied to Clipboard</span>
              </>
            ) : (
              <>
                <Copy size={16} />
                <span>Copy Passcode</span>
              </>
            )}
          </button>
        </div>
      </div>

      {error && (
        <div style={{
          background: 'rgba(239, 68, 68, 0.1)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: '#f87171',
          padding: '0.9rem',
          borderRadius: 'var(--radius-md)',
          marginBottom: '1.5rem',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.5rem'
        }}>
          <AlertCircle size={18} />
          <span>{error}</span>
        </div>
      )}

      {printSuccess ? (
        <div style={{
          background: 'rgba(16, 185, 129, 0.12)',
          border: '1px solid rgba(16, 185, 129, 0.3)',
          borderRadius: 'var(--radius-lg)',
          padding: '2rem',
          marginBottom: '2rem'
        }}>
          <div style={{
            width: '64px',
            height: '64px',
            borderRadius: '50%',
            background: 'var(--success)',
            color: 'white',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 1rem auto'
          }}>
            <Printer size={32} />
          </div>
          <h2 style={{ fontSize: '1.6rem', fontWeight: 800, marginBottom: '0.5rem', color: '#34d399' }}>
            Document Sent to Printer!
          </h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem' }}>
            Job submitted to <strong>HP_LaserJet_400_M401dn_F36EC0</strong>. Paper will feed and print automatically.
          </p>
        </div>
      ) : (
        <div style={{ marginBottom: '2rem' }}>
          <button
            className="btn-primary"
            onClick={handleDirectRelease}
            disabled={releasing}
            style={{
              padding: '1.1rem 2rem',
              fontSize: '1.1rem',
              background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
              boxShadow: '0 4px 20px rgba(16, 185, 129, 0.35)'
            }}
          >
            {releasing ? (
              <>
                <Loader2 size={22} style={{ animation: 'spin 1s linear infinite' }} />
                <span>Releasing Job to HP Printer...</span>
              </>
            ) : (
              <>
                <Printer size={22} />
                <span>Release & Print to Hardware Now</span>
              </>
            )}
          </button>
        </div>
      )}

      <div>
        <button
          onClick={onReset}
          className="btn-secondary"
          style={{ padding: '0.75rem 1.5rem' }}
        >
          <RotateCcw size={16} />
          <span>Print Another Document</span>
        </button>
      </div>
    </div>
  );
}
