// src/components/status/StatusStep.jsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   label: string,
 *   status: 'completed' | 'active' | 'pending',
 *   isLast?: boolean,
 * }} props
 */
export default function StatusStep({ label, status, isLast = false }) {
  const { colors, typography, spacing } = useTheme();

  const iconMap = { completed: '✅', active: '🔄', pending: '⏳' };
  const colorMap = {
    completed: colors.success,
    active:    colors.primary,
    pending:   colors.outline,
  };

  return (
    <View style={styles.row}>
      <View style={styles.iconCol}>
        <Text style={{ fontSize: 20 }}>{iconMap[status]}</Text>
        {!isLast && (
          <View style={[styles.line, { backgroundColor: status === 'pending' ? colors.outlineVariant : colors.primary }]} />
        )}
      </View>
      <Text style={[
        typography.bodyMedium,
        { color: colorMap[status], marginLeft: spacing.sm, marginBottom: spacing.md },
      ]}>
        {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row:     { flexDirection: 'row', alignItems: 'flex-start' },
  iconCol: { alignItems: 'center', width: 32 },
  line:    { width: 2, flex: 1, marginTop: 4, minHeight: 20 },
});
