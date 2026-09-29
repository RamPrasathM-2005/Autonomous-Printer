// src/components/layout/SectionHeader.jsx
import React from 'react';
import { Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{ title: string, style?: object }} props
 */
export default function SectionHeader({ title, style }) {
  const { colors, typography, spacing } = useTheme();
  return (
    <Text style={[
      typography.labelLarge,
      styles.text,
      { color: colors.primary, marginBottom: spacing.sm, letterSpacing: 0.8 },
      style,
    ]}>
      {title.toUpperCase()}
    </Text>
  );
}

const styles = StyleSheet.create({
  text: { marginTop: 8 },
});
