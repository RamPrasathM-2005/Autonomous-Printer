// src/hooks/usePaymentSuccessPoller.js
// Polls GET /api/orders/:id/status every 2s until job is created or timeout.
import { useEffect, useRef, useState } from 'react';
import { ordersApi } from '../services/api/orders';

const POLL_INTERVAL_MS = 2000;
const MAX_ATTEMPTS     = 15; // 30 seconds total

/**
 * @param {string|null} orderId
 * @param {{ onSuccess: (jobId: string) => void, onTimeout: () => void, onError: () => void }} callbacks
 */
export function usePaymentSuccessPoller(orderId, { onSuccess, onTimeout, onError }) {
  const [attempts, setAttempts] = useState(0);
  const intervalRef = useRef(null);

  useEffect(() => {
    if (!orderId) return;

    intervalRef.current = setInterval(async () => {
      try {
        const data = await ordersApi.getStatus(orderId);
        setAttempts((a) => a + 1);

        if (data.jobStatus !== 'PENDING' && data.jobId) {
          clearInterval(intervalRef.current);
          onSuccess(data.jobId);
          return;
        }

        if (attempts >= MAX_ATTEMPTS) {
          clearInterval(intervalRef.current);
          onTimeout();
        }
      } catch {
        clearInterval(intervalRef.current);
        onError();
      }
    }, POLL_INTERVAL_MS);

    return () => clearInterval(intervalRef.current);
  }, [orderId]); // eslint-disable-line react-hooks/exhaustive-deps

  return { attempts };
}
