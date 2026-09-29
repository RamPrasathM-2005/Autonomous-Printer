// src/hooks/usePrintStatusPoller.js
// Polls GET /api/printer/job-status/:jobId every 3s.
// Stops when job is COMPLETED or FAILED.
import { useEffect, useRef } from 'react';
import { printerApi } from '../services/api/printer';
import usePrintStatusStore from '../store/printStatusStore';

const POLL_INTERVAL_MS    = 3000;
const MAX_POLL_FAILURES   = 5;

/**
 * @param {string|null} jobId
 * @param {{ onCompleted: () => void, onFailed: () => void }} callbacks
 */
export function usePrintStatusPoller(jobId, { onCompleted, onFailed }) {
  const updateStatus  = usePrintStatusStore((s) => s.updateStatus);
  const intervalRef   = useRef(null);
  const failureCount  = useRef(0);

  useEffect(() => {
    if (!jobId) return;

    intervalRef.current = setInterval(async () => {
      try {
        const data = await printerApi.getJobStatus(jobId);
        failureCount.current = 0;

        updateStatus(data.jobStatus, data.progress ?? 0, data.queuePosition ?? null);

        if (data.jobStatus === 'COMPLETED') {
          clearInterval(intervalRef.current);
          onCompleted();
        } else if (data.jobStatus === 'FAILED') {
          clearInterval(intervalRef.current);
          onFailed();
        }
      } catch {
        failureCount.current += 1;
        if (failureCount.current >= MAX_POLL_FAILURES) {
          clearInterval(intervalRef.current);
          // Don't call onFailed — connection loss is different from job failure
        }
      }
    }, POLL_INTERVAL_MS);

    return () => clearInterval(intervalRef.current);
  }, [jobId]); // eslint-disable-line react-hooks/exhaustive-deps
}
