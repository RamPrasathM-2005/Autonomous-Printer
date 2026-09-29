// src/components/buttons/SecondaryButton.jsx
import React from 'react';
import { TouchableOpacity, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   label: string,
 *   onPress: () => void,
 *   disabled?: boolean,
 *   danger?: boolean,
 *   fullWidth?: boolean,
 *   style?: object,
 * }} props
 */
export default function SecondaryButton({
  label,
  onPress,
  disabled  = false,
  danger    = false,
  fullWidth = true,
  style,
}) {
  const { colors, typography, spacing, radius } = useTheme();
  const borderColor = danger ? colors.error : colors.primary;
  const textColor   = danger ? colors.error : colors.primary;

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled}
      accessibilityLabel={label}
      accessibilityRole="button"
      style={[
        styles.button,
        {
          borderColor,
          borderRadius:    radius.md,
          paddingVertical: spacing.md,
          paddingHorizontal: spacing.xl,
          alignSelf: fullWidth ? 'stretch' : 'auto',
          opacity: disabled ? 0.5 : 1,
        },
        style,
      ]}
    >
      <Text style={[typography.labelLarge, { color: textColor, textAlign: 'center' }]}>
        {label}
      </Text>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  button: { alignItems: 'center', justifyContent: 'center', borderWidth: 1.5 },
});
