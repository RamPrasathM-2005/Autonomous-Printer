// src/components/status/CountdownTimer.jsx
import React from 'react';
import { Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';
import { useCountdownTimer } from '../../hooks/useCountdownTimer';
import { formatCountdown } from '../../utils/format';

/**
 * @param {{ expiresAt: string, onExpired: () => void }} props
 */
export default function CountdownTimer({ expiresAt, onExpired }) {
  const { colors, typography } = useTheme();
  const { remaining }          = useCountdownTimer(expiresAt, onExpired);
  const isUrgent               = remaining < 60;

  return (
    <Text style={[
      typography.titleLarge,
      styles.text,
      { color: isUrgent ? colors.error : colors.primary },
    ]}>
      {formatCountdown(remaining)}
    </Text>
  );
}

const styles = StyleSheet.create({
  text: { fontVariant: ['tabular-nums'], textAlign: 'center' },
});
