// src/constants/print.js
// Allowed print configuration values — mirrors what the backend accepts

export const PAPER_SIZES = [
  { label: 'A4',     value: 'A4' },
  { label: 'A3',     value: 'A3' },
  { label: 'Letter', value: 'Letter' },
];

export const COLOR_MODES = [
  { label: 'B & W', value: 'bw' },
  { label: 'Color', value: 'color' },
];

export const PRINT_SIDES = [
  { label: 'Single', value: 'single' },
  { label: 'Double', value: 'double' },
];

export const ORIENTATIONS = [
  { label: 'Portrait',  value: 'portrait' },
  { label: 'Landscape', value: 'landscape' },
];

export const COPIES_MIN = 1;
export const COPIES_MAX = 50;

// Default config applied when user first opens configuration for a document
export const DEFAULT_PRINT_CONFIG = {
  copies:          1,
  pageMode:        'all',       // 'all' | 'custom'
  customPageRange: null,
  colorMode:       'bw',
  printSide:       'single',
  paperSize:       'A4',
  orientation:     'portrait',
};
