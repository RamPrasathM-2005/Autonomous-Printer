import React, { useState } from 'react';
import { ArrowLeft, CreditCard, ShieldCheck, Loader2, QrCode, Lock, CheckCircle2 } from 'lucide-react';
import { api } from '../api';

export default function PaymentStep({ orderData, onBack, onNext }) {
  const { order, documents = [], configs = [], totalAmount, pagesToPrint, printSettings } = orderData;
  const [selectedMethod, setSelectedMethod] = useState('upi');
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
        documents,
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
    <div style={{ maxWidth: '720px', margin: '0 auto' }}>
      
      {/* Top Header & Back Navigation */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1.25rem' }}>
        <button
          onClick={onBack}
          className="btn-secondary"
          style={{ padding: '0.4rem 0.85rem', fontSize: '0.8rem', display: 'flex', alignItems: 'center', gap: '5px' }}
        >
          <ArrowLeft size={15} /> Back
        </button>
        <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-muted)' }}>
          Step 3 of 4
        </span>
      </div>

      <div style={{ marginBottom: '1.25rem' }}>
        <h2 style={{ fontSize: '1.45rem', fontWeight: 800, color: 'var(--text-primary)', letterSpacing: '-0.3px', margin: 0 }}>
          Review Invoice & Pay
        </h2>
        <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem', margin: '0.2rem 0 0 0' }}>
          Confirm details and proceed with instant digital payment.
        </p>
      </div>

      {/* High Trust Security Card - Matches Flutter exactly */}
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
          <div style={{ fontWeight: 800, fontSize: '0.88rem', color: '#065f46' }}>
            100% Encrypted Payment
          </div>
          <div style={{ fontSize: '0.78rem', color: '#047857', marginTop: '1px' }}>
            Instant 6-digit release OTP generated immediately after payment.
          </div>
        </div>
      </div>

      {/* Order Summary Invoice Card */}
      <div className="card-white" style={{ padding: '1.35rem', marginBottom: '1.25rem' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem', borderBottom: '1px solid var(--border)', paddingBottom: '0.75rem' }}>
          <span style={{ fontSize: '1rem', fontWeight: 800, color: 'var(--text-primary)' }}>
            Order Summary
          </span>
          <span style={{
            background: 'var(--surface-subtle)',
            padding: '3px 9px',
            borderRadius: '8px',
            fontSize: '0.75rem',
            fontFamily: 'JetBrains Mono, monospace',
            fontWeight: 700,
            color: 'var(--text-secondary)'
          }}>
            #{order.id}
          </span>
        </div>

        {/* Breakdown Items */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '0.65rem', marginBottom: '1.15rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
            <span style={{ color: 'var(--text-secondary)' }}>Pages to Print</span>
            <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>{pagesToPrint} pages</span>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
            <span style={{ color: 'var(--text-secondary)' }}>Color Format</span>
            <span style={{ fontWeight: 700, color: 'var(--text-primary)' }}>
              {printSettings.colour ? 'Full Color (₹5/pg)' : 'Black & White (₹2/pg)'}
            </span>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
            <span style={{ color: 'var(--text-secondary)' }}>Print Sides</span>
            <span style={{ fontWeight: 700, color: 'var(--text-primary)', textTransform: 'capitalize' }}>
              {printSettings.sides.replace('-', ' ')}
            </span>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
            <span style={{ color: 'var(--text-secondary)' }}>Service & Cloud Convenience Fee</span>
            <span style={{ fontWeight: 700, color: 'var(--success)' }}>FREE (₹0.00)</span>
          </div>
        </div>

        {/* Total Divider & Display */}
        <div style={{
          borderTop: '1px solid var(--border)',
          paddingTop: '0.85rem',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'baseline'
        }}>
          <div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-secondary)', fontWeight: 600 }}>Total Payable</div>
            <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>Includes all applicable taxes</div>
          </div>
          <div style={{ fontSize: '1.65rem', fontWeight: 900, color: 'var(--primary)', letterSpacing: '-0.5px' }}>
            ₹{totalAmount}
          </div>
        </div>
      </div>

      {/* Payment Methods Card */}
      <div className="card-white" style={{ padding: '1.25rem', marginBottom: '1.5rem' }}>
        <div style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--text-primary)', marginBottom: '0.85rem' }}>
          Select Payment Method
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
          {/* UPI Option */}
          <div
            onClick={() => setSelectedMethod('upi')}
            style={{
              padding: '0.9rem 1rem',
              borderRadius: '14px',
              border: `2px solid ${selectedMethod === 'upi' ? 'var(--primary)' : 'var(--border)'}`,
              background: selectedMethod === 'upi' ? 'var(--primary-surface)' : 'var(--surface-white)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              transition: 'all 0.15s ease'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
              <div style={{
                width: '36px',
                height: '36px',
                borderRadius: '10px',
                background: selectedMethod === 'upi' ? 'var(--primary)' : 'var(--surface-subtle)',
                color: selectedMethod === 'upi' ? 'white' : 'var(--text-secondary)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}>
                <QrCode size={18} />
              </div>
              <div>
                <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)' }}>
                  UPI Instant Payment &bull; QR Code
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                  Google Pay, PhonePe, Paytm, BHIM UPI
                </div>
              </div>
            </div>
            {selectedMethod === 'upi' && (
              <div style={{ width: '18px', height: '18px', borderRadius: '50%', background: 'var(--primary)', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <CheckCircle2 size={14} />
              </div>
            )}
          </div>

          {/* Card / Netbanking Option */}
          <div
            onClick={() => setSelectedMethod('card')}
            style={{
              padding: '0.9rem 1rem',
              borderRadius: '14px',
              border: `2px solid ${selectedMethod === 'card' ? 'var(--primary)' : 'var(--border)'}`,
              background: selectedMethod === 'card' ? 'var(--primary-surface)' : 'var(--surface-white)',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'space-between',
              transition: 'all 0.15s ease'
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
              <div style={{
                width: '36px',
                height: '36px',
                borderRadius: '10px',
                background: selectedMethod === 'card' ? 'var(--primary)' : 'var(--surface-subtle)',
                color: selectedMethod === 'card' ? 'white' : 'var(--text-secondary)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center'
              }}>
                <CreditCard size={18} />
              </div>
              <div>
                <div style={{ fontWeight: 800, fontSize: '0.9rem', color: 'var(--text-primary)' }}>
                  Debit / Credit Card &bull; Net Banking
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>
                  Visa, MasterCard, RuPay, All Major Banks
                </div>
              </div>
            </div>
            {selectedMethod === 'card' && (
              <div style={{ width: '18px', height: '18px', borderRadius: '50%', background: 'var(--primary)', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <CheckCircle2 size={14} />
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Pay Button */}
      <button
        onClick={handleSimulatePayment}
        disabled={processing}
        className="btn-primary"
        style={{
          width: '100%',
          padding: '1rem',
          borderRadius: '16px',
          fontSize: '1.05rem',
          letterSpacing: '0.2px'
        }}
      >
        {processing ? (
          <>
            <Loader2 size={20} className="animate-spin" />
            <span>Processing Secure Checkout...</span>
          </>
        ) : (
          <>
            <Lock size={18} />
            <span>Pay ₹{totalAmount} via Razorpay</span>
          </>
        )}
      </button>

    </div>
  );
}
