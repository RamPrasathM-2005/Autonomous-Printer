// src/components/feedback/Loading.jsx
import React from 'react';
import { ActivityIndicator, View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   fullscreen?: boolean,
 *   size?: 'small' | 'large',
 *   message?: string,
 * }} props
 */
export default function Loading({ fullscreen = false, size = 'large', message }) {
  const { colors, typography, spacing } = useTheme();
  return (
    <View style={[styles.container, fullscreen && styles.fullscreen, { padding: spacing.xl }]}>
      <ActivityIndicator size={size} color={colors.primary} />
      {!!message && (
        <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, marginTop: spacing.sm, textAlign: 'center' }]}>
          {message}
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container:  { alignItems: 'center', justifyContent: 'center' },
  fullscreen: { flex: 1 },
});
