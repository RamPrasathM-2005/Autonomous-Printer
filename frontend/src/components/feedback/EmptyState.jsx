// src/components/feedback/EmptyState.jsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';
import PrimaryButton from '../buttons/PrimaryButton';

/**
 * @param {{
 *   title: string,
 *   description: string,
 *   actionLabel?: string,
 *   onAction?: () => void,
 * }} props
 */
export default function EmptyState({ title, description, actionLabel, onAction }) {
  const { colors, typography, spacing } = useTheme();
  return (
    <View style={[styles.container, { padding: spacing.xl }]}>
      <Text style={[typography.headlineSmall, { color: colors.onSurface, textAlign: 'center', marginBottom: spacing.sm }]}>
        {title}
      </Text>
      <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, textAlign: 'center', marginBottom: spacing.lg }]}>
        {description}
      </Text>
      {actionLabel && onAction && (
        <PrimaryButton label={actionLabel} onPress={onAction} fullWidth={false} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
