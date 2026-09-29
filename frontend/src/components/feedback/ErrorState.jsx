// src/components/feedback/ErrorState.jsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';
import { getErrorMessage } from '../../utils/errorMessages';
import PrimaryButton from '../buttons/PrimaryButton';

/**
 * @param {{ code: string, onRetry?: () => void }} props
 */
export default function ErrorState({ code, onRetry }) {
  const { colors, typography, spacing } = useTheme();
  return (
    <View style={[styles.container, { padding: spacing.xl }]}>
      <Text style={{ fontSize: 48, textAlign: 'center' }}>⚠️</Text>
      <Text style={[typography.headlineSmall, { color: colors.error, textAlign: 'center', marginTop: spacing.md }]}>
        Something went wrong
      </Text>
      <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, textAlign: 'center', marginTop: spacing.sm, marginBottom: spacing.lg }]}>
        {getErrorMessage(code)}
      </Text>
      {onRetry && <PrimaryButton label="Retry" onPress={onRetry} fullWidth={false} />}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
