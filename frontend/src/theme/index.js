// src/theme/index.js
// Unified theme export — import { useTheme } from '../theme' in any component

import { useColorScheme } from 'react-native';
import { lightColors, darkColors } from './colors';
import { typography } from './typography';
import { spacing, radius } from './spacing';
import { elevation } from './elevation';

/**
 * Returns theme tokens for current color scheme.
 * @returns {{ colors, typography, spacing, radius, elevation }}
 */
export function useTheme() {
  const scheme = useColorScheme();
  const colors = scheme === 'dark' ? darkColors : lightColors;
  return { colors, typography, spacing, radius, elevation };
}

// Named re-exports for direct import when no hook is needed
export { lightColors, darkColors, typography, spacing, radius, elevation };
