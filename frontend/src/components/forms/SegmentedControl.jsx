// src/components/forms/SegmentedControl.jsx
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   options: Array<{ label: string, value: string }>,
 *   selected: string,
 *   onSelect: (value: string) => void,
 *   label?: string,
 * }} props
 */
export default function SegmentedControl({ options, selected, onSelect, label }) {
  const { colors, typography, spacing, radius } = useTheme();

  return (
    <View style={styles.wrapper}>
      {label && (
        <Text style={[typography.labelMedium, { color: colors.onSurfaceVariant, marginBottom: spacing.xs }]}>
          {label}
        </Text>
      )}
      <View style={[styles.row, { backgroundColor: colors.surfaceVariant, borderRadius: radius.sm, padding: 3 }]}>
        {options.map((opt) => {
          const isActive = opt.value === selected;
          return (
            <TouchableOpacity
              key={opt.value}
              onPress={() => onSelect(opt.value)}
              accessibilityLabel={opt.label}
              style={[
                styles.segment,
                { borderRadius: radius.xs - 1 },
                isActive && { backgroundColor: colors.surface },
              ]}
            >
              <Text style={[typography.labelMedium, { color: isActive ? colors.primary : colors.onSurfaceVariant }]}>
                {opt.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: { marginBottom: 12 },
  row:     { flexDirection: 'row' },
  segment: { flex: 1, alignItems: 'center', paddingVertical: 8 },
});
