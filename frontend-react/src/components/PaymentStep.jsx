import React, { useState } from 'react';
import { ArrowLeft, CreditCard, ShieldCheck, CheckCircle2, Loader2, Sparkles } from 'lucide-react';
import confetti from 'canvas-confetti';
import { api } from '../api';

export default function PaymentStep({ orderData, onBack, onNext }) {
  const { order, document, totalAmount, pagesToPrint, printSettings } = orderData;
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState(null);

  const handlePay = async () => {
    setProcessing(true);
    setError(null);

    try {
      // 1. Initialize payment order with backend
      const initResp = await api.createPayment(order.id);

      // 2. Simulate Razorpay verification (or live gateway)
      await api.verifyPayment({
        orderId: order.id,
        razorpayOrderId: initResp.razorpayOrderId || `order_sim_${Date.now()}`,
        razorpayPaymentId: `pay_sim_${Date.now()}`,
        razorpaySignature: 'simulated_signature'
      });

      // 3. Fetch newly generated OTP for order
      const otpResp = await api.getOrderOtp(order.id);

      // Trigger confetti celebration!
      confetti({
        particleCount: 80,
        spread: 70,
        origin: { y: 0.6 }
      });

      onNext({
        order,
        document,
        otp: otpResp.otp,
        expiresAt: otpResp.expiresAt
      });
    } catch (err) {
      setError(err.message || 'Payment processing failed');
    } finally {
      setProcessing(false);
    }
  };

  return (
    <div style={{ maxWidth: '600px', margin: '0 auto' }}>
      <button
        onClick={onBack}
        className="btn-secondary"
        style={{ padding: '0.4rem 0.9rem', fontSize: '0.85rem', marginBottom: '1.5rem' }}
      >
        <ArrowLeft size={16} /> Back to Options
      </button>

      <div className="glass-panel" style={{ padding: '2.5rem' }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <div style={{
            width: '60px',
            height: '60px',
            borderRadius: '50%',
            background: 'rgba(99, 102, 241, 0.15)',
            color: '#818cf8',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            margin: '0 auto 1rem auto'
          }}>
            <CreditCard size={30} />
          </div>
          <h2 style={{ fontSize: '1.8rem', fontWeight: 800 }}>Complete Your Payment</h2>
          <p style={{ color: 'var(--text-muted)', fontSize: '0.9rem', marginTop: '0.3rem' }}>
            Instant digital checkout. An OTP release code will be generated upon confirmation.
          </p>
        </div>

        {error && (
          <div style={{
            background: 'rgba(239, 68, 68, 0.1)',
            border: '1px solid rgba(239, 68, 68, 0.3)',
            color: '#f87171',
            padding: '0.85rem 1.25rem',
            borderRadius: 'var(--radius-md)',
            marginBottom: '1.5rem'
          }}>
            {error}
          </div>
        )}

        <div style={{
          background: 'var(--bg-secondary)',
          border: '1px solid var(--border-subtle)',
          borderRadius: 'var(--radius-md)',
          padding: '1.25rem',
          marginBottom: '2rem'
        }}>
          <div className="summary-row">
            <span>Order Reference</span>
            <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--text-main)' }}>{order.id}</span>
          </div>
          <div className="summary-row">
            <span>Document</span>
            <span style={{ color: 'var(--text-main)', fontWeight: 600 }}>
              {document.originalFilename || document.original_filename}
            </span>
          </div>
          <div className="summary-row">
            <span>Copies & Configuration</span>
            <span style={{ color: 'var(--text-main)' }}>
              {printSettings.copies} copies • {printSettings.colour ? 'Color' : 'B&W'} • {printSettings.paperSize}
            </span>
          </div>
          <div className="summary-total" style={{ margin: '1rem 0 0 0', padding: '0.75rem 0 0 0' }}>
            <span style={{ fontWeight: 700 }}>Total Amount</span>
            <span style={{ fontSize: '1.75rem', fontWeight: 800, color: '#34d399' }}>₹{totalAmount}</span>
          </div>
        </div>

        <button
          className="btn-primary"
          onClick={handlePay}
          disabled={processing}
          style={{ padding: '1rem 2rem', fontSize: '1.1rem' }}
        >
          {processing ? (
            <>
              <Loader2 size={22} style={{ animation: 'spin 1s linear infinite' }} />
              <span>Verifying & Generating OTP...</span>
            </>
          ) : (
            <>
              <Sparkles size={20} />
              <span>Pay & Generate OTP (₹{totalAmount})</span>
            </>
          )}
        </button>

        <div style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          gap: '0.5rem',
          marginTop: '1.25rem',
          color: 'var(--text-dim)',
          fontSize: '0.8rem'
        }}>
          <ShieldCheck size={16} />
          <span>256-Bit Encrypted Secure Transaction</span>
        </div>
      </div>
    </div>
  );
}
