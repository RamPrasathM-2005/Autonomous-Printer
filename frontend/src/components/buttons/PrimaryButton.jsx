// src/components/buttons/PrimaryButton.jsx
import React from 'react';
import {
  TouchableOpacity, Text, ActivityIndicator, StyleSheet, View,
} from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   label: string,
 *   onPress: () => void,
 *   loading?: boolean,
 *   disabled?: boolean,
 *   fullWidth?: boolean,
 *   style?: object,
 * }} props
 */
export default function PrimaryButton({
  label,
  onPress,
  loading  = false,
  disabled = false,
  fullWidth = true,
  style,
}) {
  const { colors, typography, spacing, radius, elevation } = useTheme();
  const isDisabled = disabled || loading;

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={isDisabled}
      accessibilityLabel={label}
      accessibilityRole="button"
      style={[
        styles.button,
        elevation.medium,
        {
          backgroundColor: isDisabled ? colors.surfaceVariant : colors.primary,
          borderRadius:    radius.md,
          paddingVertical: spacing.md,
          paddingHorizontal: spacing.xl,
          alignSelf: fullWidth ? 'stretch' : 'auto',
          opacity: isDisabled ? 0.55 : 1,
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={colors.onPrimary} size="small" />
      ) : (
        <Text style={[typography.labelLarge, { color: isDisabled ? colors.onSurfaceVariant : colors.onPrimary, textAlign: 'center' }]}>
          {label}
        </Text>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: { alignItems: 'center', justifyContent: 'center' },
});
