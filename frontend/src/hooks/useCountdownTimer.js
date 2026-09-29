// src/hooks/useCountdownTimer.js
// Counts down from a target expiry time to zero, calling onExpired when done.
import { useState, useEffect, useRef } from 'react';
import { secondsUntil } from '../utils/format';

/**
 * @param {string} expiresAt - ISO8601 expiry timestamp
 * @param {() => void} onExpired - Called once when timer reaches zero
 * @returns {{ remaining: number, isExpired: boolean }}
 */
export function useCountdownTimer(expiresAt, onExpired) {
  const [remaining, setRemaining] = useState(() => secondsUntil(expiresAt));
  const onExpiredRef = useRef(onExpired);
  onExpiredRef.current = onExpired;

  useEffect(() => {
    if (!expiresAt) return;
    setRemaining(secondsUntil(expiresAt));

    const interval = setInterval(() => {
      setRemaining((prev) => {
        const next = Math.max(0, prev - 1);
        if (next === 0) {
          clearInterval(interval);
          onExpiredRef.current?.();
        }
        return next;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, [expiresAt]);

  return { remaining, isExpired: remaining === 0 };
}
