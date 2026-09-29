// src/utils/retry.js
// Exponential backoff retry wrapper

/**
 * Retries an async function with exponential backoff.
 * @param {() => Promise<any>} fn - Async function to retry
 * @param {number} maxAttempts - Maximum number of attempts (default 3)
 * @param {number} baseDelayMs - Base delay in ms (doubles each attempt, default 1000)
 * @returns {Promise<any>}
 */
export async function withRetry(fn, maxAttempts = 3, baseDelayMs = 1000) {
  let lastError;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt === maxAttempts) break;
      // Exponential backoff: 1s, 2s, 4s ...
      const delay = baseDelayMs * Math.pow(2, attempt - 1);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
  throw lastError;
}
