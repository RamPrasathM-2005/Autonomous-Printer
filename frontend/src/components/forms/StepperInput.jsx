// src/components/forms/StepperInput.jsx
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{ value: number, min: number, max: number, onChange: (v: number) => void, label?: string }} props
 */
export default function StepperInput({ value, min = 1, max = 50, onChange, label }) {
  const { colors, typography, spacing, radius } = useTheme();

  const decrement = () => { if (value > min) onChange(value - 1); };
  const increment = () => { if (value < max) onChange(value + 1); };

  const btnStyle = (enabled) => ({
    backgroundColor: enabled ? colors.primaryContainer : colors.surfaceVariant,
    borderRadius: radius.sm,
    width: 36, height: 36,
    alignItems: 'center', justifyContent: 'center',
    opacity: enabled ? 1 : 0.4,
  });

  return (
    <View style={styles.wrapper}>
      {label && <Text style={[typography.labelMedium, { color: colors.onSurfaceVariant, marginBottom: spacing.xs }]}>{label}</Text>}
      <View style={styles.row}>
        <TouchableOpacity onPress={decrement} disabled={value <= min} style={btnStyle(value > min)}>
          <Text style={[typography.titleMedium, { color: colors.primary }]}>−</Text>
        </TouchableOpacity>
        <Text style={[typography.titleMedium, { color: colors.onSurface, minWidth: 40, textAlign: 'center' }]}>
          {value}
        </Text>
        <TouchableOpacity onPress={increment} disabled={value >= max} style={btnStyle(value < max)}>
          <Text style={[typography.titleMedium, { color: colors.primary }]}>+</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: { marginBottom: 8 },
  row:     { flexDirection: 'row', alignItems: 'center', gap: 16 },
});
