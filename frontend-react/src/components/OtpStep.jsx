import React, { useState, useEffect } from 'react';
import { Copy, Check, Clock, RotateCcw, MapPin, Printer, CheckCircle2, AlertTriangle } from 'lucide-react';
import { api } from '../api';

export default function OtpStep({ finalData, onReset }) {
  const { order, otp } = finalData;
  const [copied, setCopied] = useState(false);
  const [orderStatus, setOrderStatus] = useState(order?.status || 'WAITING_FOR_OTP');
  const [isOutOfPaper, setIsOutOfPaper] = useState(false);
  const [statusMessage, setStatusMessage] = useState(null);
  const [selectedPrinter, setSelectedPrinter] = useState(
    order?.print_settings?.cups_printer_name || order?.print_settings?.printer_name || null
  );
  const [printerUpdating, setPrinterUpdating] = useState(false);

  const handleSelectPrinter = async (printerName) => {
    setSelectedPrinter(printerName);
    const orderId = order?.id || order?.order_id;
    if (orderId) {
      setPrinterUpdating(true);
      try {
        await api.selectOrderPrinter(orderId, printerName);
      } catch (err) {
        console.error('Failed to update printer:', err);
      } finally {
        setPrinterUpdating(false);
      }
    }
  };

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
        Select your physical printer below to display your 6-digit release OTP code.
      </p>

      {/* Two-Printer Selection Card */}
      <div style={{
        background: 'var(--surface-card, #ffffff)',
        border: '1.5px solid var(--border-color, #e2e8f0)',
        borderRadius: '20px',
        padding: '1.25rem',
        marginBottom: '1.5rem',
        textAlign: 'left',
        boxShadow: 'var(--card-shadow, 0 4px 14px rgba(0,0,0,0.04))'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.35rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', fontWeight: 800, fontSize: '1rem', color: 'var(--text-primary)' }}>
            <Printer size={18} color="var(--primary, #2563eb)" />
            <span>Select Destination Printer</span>
          </div>
          {printerUpdating && (
            <span style={{ fontSize: '0.75rem', color: 'var(--primary, #2563eb)', fontWeight: 600 }}>Updating...</span>
          )}
        </div>
        <p style={{ margin: '0 0 1rem', fontSize: '0.8rem', color: 'var(--text-secondary)' }}>
          Two printers are connected to this station. Choose which printer will print your pages:
        </p>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '0.75rem' }}>
          {/* Printer 1 */}
          <div
            onClick={() => handleSelectPrinter('HP_LaserJet_400_M401dn_F36EC0')}
            style={{
              padding: '1rem',
              borderRadius: '14px',
              cursor: 'pointer',
              border: selectedPrinter === 'HP_LaserJet_400_M401dn_F36EC0'
                ? '2px solid #2563eb'
                : '1.5px solid #e2e8f0',
              background: selectedPrinter === 'HP_LaserJet_400_M401dn_F36EC0'
                ? '#eff6ff'
                : '#ffffff',
              transition: 'all 0.18s ease'
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
              <Printer size={20} color={selectedPrinter === 'HP_LaserJet_400_M401dn_F36EC0' ? '#2563eb' : '#64748b'} />
              {selectedPrinter === 'HP_LaserJet_400_M401dn_F36EC0' && (
                <CheckCircle2 size={18} color="#2563eb" />
              )}
            </div>
            <div style={{ fontWeight: 800, fontSize: '0.92rem', color: selectedPrinter === 'HP_LaserJet_400_M401dn_F36EC0' ? '#1e40af' : '#1e293b' }}>
              HP LaserJet 400
            </div>
            <div style={{ fontSize: '0.75rem', color: '#64748b', marginTop: '2px' }}>
              Duplex • B&W • Fast Output
            </div>
          </div>

          {/* Printer 2 */}
          <div
            onClick={() => handleSelectPrinter('Printer_2')}
            style={{
              padding: '1rem',
              borderRadius: '14px',
              cursor: 'pointer',
              border: selectedPrinter === 'Printer_2'
                ? '2px solid #2563eb'
                : '1.5px solid #e2e8f0',
              background: selectedPrinter === 'Printer_2'
                ? '#eff6ff'
                : '#ffffff',
              transition: 'all 0.18s ease'
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.5rem' }}>
              <Printer size={20} color={selectedPrinter === 'Printer_2' ? '#2563eb' : '#64748b'} />
              {selectedPrinter === 'Printer_2' && (
                <CheckCircle2 size={18} color="#2563eb" />
              )}
            </div>
            <div style={{ fontWeight: 800, fontSize: '0.92rem', color: selectedPrinter === 'Printer_2' ? '#1e40af' : '#1e293b' }}>
              Secondary Printer
            </div>
            <div style={{ fontSize: '0.75rem', color: '#64748b', marginTop: '2px' }}>
              Color / Tray 2 • High Res
            </div>
          </div>
        </div>
      </div>

      {/* Large 6-Digit Display Card - Revealed after printer selection */}
      {!selectedPrinter ? (
        <div style={{
          background: '#ffffff',
          borderRadius: '20px',
          border: '1.5px solid #e2e8f0',
          padding: '2rem 1.5rem',
          marginBottom: '1.5rem',
          textAlign: 'center'
        }}>
          <div style={{
            width: '48px',
            height: '48px',
            borderRadius: '50%',
            background: '#eff6ff',
            color: '#2563eb',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 0.75rem'
          }}>
            <Printer size={24} />
          </div>
          <div style={{ fontWeight: 800, fontSize: '1.05rem', color: '#1e293b' }}>
            Select a Destination Printer Above
          </div>
          <div style={{ fontSize: '0.82rem', color: '#64748b', marginTop: '0.25rem' }}>
            Please click one of the 2 printers above to route your print job and reveal your 6-digit release OTP code.
          </div>
        </div>
      ) : (
        <div className="otp-display-card" style={{ marginBottom: '1.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '0.5rem' }}>
            <span style={{
              background: '#ecfdf5',
              border: '1px solid rgba(16, 185, 129, 0.3)',
              color: '#065f46',
              padding: '0.25rem 0.75rem',
              borderRadius: '20px',
              fontSize: '0.75rem',
              fontWeight: 700,
              display: 'inline-flex',
              alignItems: 'center',
              gap: '0.35rem'
            }}>
              <CheckCircle2 size={13} color="#10b981" />
              Routed to: {selectedPrinter === 'Printer_2' ? 'Secondary Printer' : 'HP LaserJet 400'}
            </span>
          </div>

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
