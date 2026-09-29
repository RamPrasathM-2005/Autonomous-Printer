// src/utils/pageRange.js
// Parses and validates print page range strings like "1-5, 8, 10-12"

/**
 * Validates a page range string against a document's page count.
 * @param {string} input - Page range string e.g. "1-5, 8, 10-12"
 * @param {number} maxPages - Total pages in the document
 * @returns {string|null} Error message, or null if valid
 */
export function validatePageRange(input, maxPages) {
  const trimmed = (input || '').trim();
  if (!trimmed) return 'Page range cannot be empty.';

  // Allow: "1", "1-5", "1,3,5-7", "1-3, 5, 7-9"
  const pattern = /^(\d+(-\d+)?)(,\s*\d+(-\d+)?)*$/;
  if (!pattern.test(trimmed)) {
    return 'Invalid format. Use examples: 1-5, 8, 10-12';
  }

  const parts = trimmed.split(',').map((r) => r.trim());
  for (const part of parts) {
    const range = part.split('-').map(Number);
    if (range[0] < 1) return `Page numbers must be 1 or greater.`;
    if (range[0] > maxPages) return `Page ${range[0]} exceeds document length (${maxPages} pages).`;
    if (range.length === 2) {
      if (range[1] < range[0]) return `Invalid range: ${range[0]}-${range[1]}. End must be ≥ start.`;
      if (range[1] > maxPages) return `Page ${range[1]} exceeds document length (${maxPages} pages).`;
    }
  }
  return null; // valid
}

/**
 * Parses a page range string into a sorted, deduplicated array of page numbers.
 * @param {string} input
 * @returns {number[]}
 */
export function parsePageRange(input) {
  const pages = new Set();
  const parts = input.split(',').map((r) => r.trim());
  for (const part of parts) {
    if (part.includes('-')) {
      const [start, end] = part.split('-').map(Number);
      for (let i = start; i <= end; i++) pages.add(i);
    } else {
      pages.add(Number(part));
    }
  }
  return Array.from(pages).sort((a, b) => a - b);
}
