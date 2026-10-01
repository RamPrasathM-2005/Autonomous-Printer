// API Service for Autonomous Print Hub
const BASE_URL = '/api';

export const api = {
  // 1. Health check
  async checkHealth() {
    try {
      const res = await fetch('/health');
      return res.ok;
    } catch {
      return false;
    }
  },

  // 2. Fetch available print servers / stations
  async getPrintServers() {
    try {
      const res = await fetch(`${BASE_URL}/print-servers`);
      if (!res.ok) throw new Error('Failed to load stations');
      return await res.json();
    } catch (e) {
      console.warn('Using default station fallback:', e);
      return [{
        id: 'PRINT-SERVER-001',
        name: 'Autonomous Station 1',
        location: 'Main Lab Hub',
        status: 'ONLINE',
        printer_state: 'READY',
        paper_state: 'AVAILABLE'
      }];
    }
  },

  // 3. Upload document (PDF, PNG, JPG)
  async uploadDocument(file) {
    const formData = new FormData();
    formData.append('file', file);

    const res = await fetch(`${BASE_URL}/documents/upload`, {
      method: 'POST',
      body: formData,
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || `Upload failed (${res.status})`);
    }

    return await res.json();
  },

  // 4. Create print order
  async createOrder({ documentId, printServerId, printSettings, items }) {
    const payload = {
      document_id: documentId,
      print_server_id: printServerId || 'PRINT-SERVER-001',
      print_settings: printSettings,
    };
    if (items && items.length > 0) {
      payload.items = items;
    }

    const res = await fetch(`${BASE_URL}/orders`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || `Order creation failed (${res.status})`);
    }

    return await res.json();
  },

  // 5. Payment Initiation
  async createPayment(orderId) {
    const res = await fetch(`${BASE_URL}/payments/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ orderId }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || 'Payment initiation failed');
    }

    return await res.json();
  },

  // 6. Payment Verification (Transitions order to WAITING_FOR_OTP and generates OTP)
  async verifyPayment({ orderId, razorpayOrderId, razorpayPaymentId, razorpaySignature }) {
    const res = await fetch(`${BASE_URL}/payments/verify`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        orderId,
        razorpayOrderId: razorpayOrderId || `order_sim_${Date.now()}`,
        razorpayPaymentId: razorpayPaymentId || `pay_sim_${Date.now()}`,
        razorpaySignature: razorpaySignature || 'simulated_signature'
      }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || 'Payment verification failed');
    }

    return await res.json();
  },

  // 7. Get OTP for Order
  async getOrderOtp(orderId) {
    const res = await fetch(`${BASE_URL}/orders/${orderId}/otp`);
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || 'OTP not ready yet');
    }
    return await res.json();
  },

  // 8. Release Print Job via OTP (Kiosk release endpoint)
  async releaseJobWithOtp(otp) {
    const res = await fetch(`${BASE_URL}/agent/release-kiosk`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ otp: otp.trim() }),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || 'Invalid or expired OTP');
    }

    return await res.json();
  },

  // 9. Get Live Order Status
  async getOrder(orderId) {
    const res = await fetch(`${BASE_URL}/orders/${orderId}`);
    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || 'Failed to fetch order');
    }
    return await res.json();
  },

  // 9. Local Agent Telemetry
  async getLocalStationStatus() {
    try {
      const res = await fetch('/local/status');
      if (res.ok) return await res.json();
    } catch {}
    return {
      printer_name: 'HP_LaserJet_400_M401dn_F36EC0',
      printer_state: 'READY',
      paper_state: 'AVAILABLE',
      active_jobs_count: 0
    };
  }
};
