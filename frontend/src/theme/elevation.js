// src/theme/elevation.js
// Shadow tokens per MD3 elevation levels

import { Platform } from 'react-native';

const shadow = (level) => {
  if (Platform.OS === 'android') {
    return { elevation: level * 2 };
  }
  const shadowMap = {
    0: {},
    1: { shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.15, shadowRadius: 2 },
    2: { shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.15, shadowRadius: 4 },
    3: { shadowColor: '#000', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.15, shadowRadius: 8 },
    4: { shadowColor: '#000', shadowOffset: { width: 0, height: 6 }, shadowOpacity: 0.15, shadowRadius: 12 },
    5: { shadowColor: '#000', shadowOffset: { width: 0, height: 8 }, shadowOpacity: 0.15, shadowRadius: 16 },
  };
  return shadowMap[Math.min(level, 5)] || {};
};

export const elevation = {
  none:   shadow(0),
  low:    shadow(1),  // Cards at rest
  medium: shadow(2),  // Raised buttons
  high:   shadow(3),  // Bottom sheets, modals
  higher: shadow(4),  // Navigation drawers
  top:    shadow(5),  // FABs
};
