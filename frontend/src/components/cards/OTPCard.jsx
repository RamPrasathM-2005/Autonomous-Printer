// src/components/cards/OTPCard.jsx
import React from 'react';
import { View, Text, StyleSheet, Clipboard, TouchableOpacity } from 'react-native';
import { useTheme } from '../../theme';
import CountdownTimer from '../status/CountdownTimer';

/**
 * @param {{ otp: string, expiresAt: string, onExpired: () => void }} props
 */
export default function OTPCard({ otp, expiresAt, onExpired }) {
  const { colors, typography, spacing, radius, elevation } = useTheme();
  const digits = String(otp).split('');

  const copyToClipboard = () => {
    Clipboard.setString(otp);
  };

  return (
    <View style={[
      styles.card,
      elevation.medium,
      {
        backgroundColor: colors.primaryContainer,
        borderRadius:    radius.lg,
        padding:         spacing.xl,
        alignItems:      'center',
        marginBottom:    spacing.lg,
      },
    ]}>
      <Text style={[typography.labelLarge, { color: colors.onPrimaryContainer, marginBottom: spacing.sm }]}>
        Your OTP
      </Text>

      {/* OTP digits */}
      <TouchableOpacity onLongPress={copyToClipboard} style={styles.digitsRow}>
        {digits.map((digit, i) => (
          <View key={i} style={[styles.digitBox, { backgroundColor: colors.surface, borderRadius: radius.sm }]}>
            <Text style={[typography.headlineMedium, { color: colors.primary }]}>
              {digit}
            </Text>
          </View>
        ))}
      </TouchableOpacity>

      <Text style={[typography.bodySmall, { color: colors.onPrimaryContainer, marginTop: spacing.sm }]}>
        Long press to copy
      </Text>

      <Text style={[typography.labelMedium, { color: colors.onPrimaryContainer, marginTop: spacing.md }]}>
        Expires in
      </Text>
      <CountdownTimer expiresAt={expiresAt} onExpired={onExpired} />
    </View>
  );
}

const styles = StyleSheet.create({
  card:       {},
  digitsRow:  { flexDirection: 'row', gap: 8, marginTop: 4 },
  digitBox:   { width: 44, height: 56, alignItems: 'center', justifyContent: 'center' },
});
