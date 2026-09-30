import React, { useState } from 'react';
import { ArrowLeft, CreditCard, ShieldCheck, Loader2 } from 'lucide-react';
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
          Review Invoice & Pay
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
          Confirm details and proceed with instant digital payment.
        </p>
      </div>

      {/* High Trust Security Card - Matches Flutter */}
      <div style={{
        padding: '0.9rem 1.25rem',
        borderRadius: '16px',
        background: 'var(--success-surface)',
        border: '1px solid rgba(16, 185, 129, 0.3)',
        display: 'flex',
        alignItems: 'center',
        gap: '0.85rem',
        marginBottom: '1.25rem'
      }}>
        <ShieldCheck size={24} color="#059669" />
        <div>
          <div style={{ fontWeight: 700, fontSize: '0.88rem', color: '#065f46' }}>
            100% Encrypted Payment
          </div>
          <div style={{ fontSize: '0.78rem', color: '#047857', marginTop: '1px' }}>
            Instant 6-digit release OTP generated immediately after payment.
          </div>
        </div>
      </div>

      {/* Order Summary Invoice Card - Matches Flutter */}
      <div className="card-white">
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem' }}>
          <h3 style={{ fontSize: '1rem', fontWeight: 700, color: 'var(--text-primary)' }}>
            Invoice Summary
          </h3>
          <span style={{
            background: 'var(--primary-surface)',
            color: 'var(--primary)',
            padding: '3px 8px',
            borderRadius: '6px',
            fontSize: '0.75rem',
            fontWeight: 700
          }}>
            Order #{order.id}
          </span>
        </div>

        <div className="summary-row">
          <span>Document</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>
            {document.originalFilename || document.original_filename || 'document.pdf'}
          </span>
        </div>
        <div className="summary-row">
          <span>Pages / Sheets</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>
            {pagesToPrint} pages × {printSettings.copies} copies = {pagesToPrint * printSettings.copies} sheets
          </span>
        </div>
        <div className="summary-row">
          <span>Print Format</span>
          <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>
            {printSettings.colour ? 'Full Color' : 'Grayscale'} • {printSettings.sides === 'two-sided-long-edge' ? 'Duplex' : 'Single-Sided'} • {printSettings.paperSize || 'A4'}
          </span>
        </div>
        <div className="summary-total">
          <span>Total Payable Amount</span>
          <span className="price-tag">₹{totalAmount}</span>
        </div>
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
            <span>Processing Instant Payment...</span>
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
