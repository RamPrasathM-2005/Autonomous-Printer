import React, { useState } from 'react';
import { ArrowLeft, CreditCard, ShieldCheck, CheckCircle2, Loader2, AlertCircle } from 'lucide-react';
import { api } from '../api';

export default function PaymentStep({ orderData, onBack, onNext }) {
  const { order, document, totalAmount, pagesToPrint, printSettings } = orderData;
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState(null);

  const handleSimulatePayment = async () => {
    setProcessing(true);
    setError(null);

    try {
      // 1. Create payment order
      const payOrder = await api.createPayment(order.id);
      
      // 2. Verify payment (generates release OTP)
      const verifyData = await api.verifyPayment({
        orderId: order.id,
        razorpayOrderId: payOrder.razorpayOrderId || `rzp_${order.id}`,
        razorpayPaymentId: `pay_demo_${Date.now()}`,
        razorpaySignature: 'demo_valid_signature_hash',
      });

      onNext({
        order,
        document,
        otp: verifyData.otp,
        expiresAt: verifyData.expires_at || verifyData.expiresAt,
      });
    } catch (err) {
      setError(err.message || 'Payment processing failed. Please retry.');
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div>
      <div style={{ marginBottom: '1.25rem' }}>
        <button
          onClick={onBack}
          className="btn-secondary"
          style={{ padding: '0.4rem 0.85rem', fontSize: '0.8rem', marginBottom: '0.4rem' }}
        >
          <ArrowLeft size={15} /> Back
        </button>
        <h2 style={{ fontSize: '1.5rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px' }}>
          Payment & Release
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
          Complete payment to receive your 6-digit physical print release OTP.
        </p>
      </div>

      {/* Order Summary Card */}
      <div className="card-white">
        <h3 style={{ fontSize: '1rem', fontWeight: 700, marginBottom: '0.85rem', color: 'var(--text-primary)' }}>
          Order Summary
        </h3>
        <div className="summary-row">
          <span>Order ID</span>
          <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>{order.id}</span>
        </div>
        <div className="summary-row">
          <span>Document</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>
            {document.originalFilename || document.original_filename || 'document.pdf'}
          </span>
        </div>
        <div className="summary-row">
          <span>Print Settings</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>
            {printSettings.copies} copies • {printSettings.colour ? 'Color' : 'Grayscale'} • {printSettings.sides === 'two-sided-long-edge' ? 'Duplex' : 'Single'}
          </span>
        </div>
        <div className="summary-row">
          <span>Print Station Queue</span>
          <span style={{ fontWeight: 700, color: 'var(--primary)' }}>HP_LaserJet_400_M401dn_F36EC0</span>
        </div>
        <div className="summary-total">
          <span>Total Payable Amount</span>
          <span className="price-tag">₹{totalAmount}</span>
        </div>
      </div>

      {/* Payment Method Card */}
      <div className="card-white" style={{ background: 'var(--primary-surface)', border: '1px solid rgba(79, 70, 229, 0.2)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', marginBottom: '0.5rem' }}>
          <ShieldCheck size={22} color="var(--primary)" />
          <span style={{ fontWeight: 700, color: 'var(--text-primary)', fontSize: '0.95rem' }}>
            Instant Touchless Pay
          </span>
        </div>
        <p style={{ fontSize: '0.82rem', color: 'var(--text-secondary)', lineHeight: 1.5 }}>
          Supports UPI, Google Pay, PhonePe, Cards, or NetBanking. Once payment is confirmed, an instant 6-digit OTP will be issued to release your print at the machine.
        </p>
      </div>

      {error && (
        <div style={{
          background: 'var(--danger-surface)',
          border: '1px solid rgba(239, 68, 68, 0.3)',
          color: 'var(--danger)',
          padding: '0.85rem 1.25rem',
          borderRadius: '14px',
          marginBottom: '1.25rem',
          fontSize: '0.88rem'
        }}>
          {error}
        </div>
      )}

      <button
        className="btn-primary"
        onClick={handleSimulatePayment}
        disabled={processing}
      >
        {processing ? (
          <>
            <Loader2 size={18} className="animate-spin" style={{ animation: 'spin 1s linear infinite' }} />
            <span>Processing Payment...</span>
          </>
        ) : (
          <>
            <CreditCard size={18} />
            <span>Pay ₹{totalAmount} & Get Release OTP</span>
          </>
        )}
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
