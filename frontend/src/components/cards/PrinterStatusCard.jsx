// src/components/cards/PrinterStatusCard.jsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';
import StatusBadge from '../status/StatusBadge';

/**
 * @param {{ status: string, printerName: string|null, paperStatus: string }} props
 */
export default function PrinterStatusCard({ status, printerName, paperStatus }) {
  const { colors, typography, spacing, radius, elevation } = useTheme();

  const paperLabel = {
    ok:      '🟢 Paper OK',
    low:     '🟡 Paper Low',
    empty:   '🔴 Paper Empty',
    unknown: '❓ Paper Unknown',
  }[paperStatus] || '❓';

  return (
    <View style={[
      styles.card,
      elevation.low,
      {
        backgroundColor: colors.surface,
        borderRadius:    radius.md,
        padding:         spacing.md,
        borderWidth:     1,
        borderColor:     colors.outlineVariant,
        marginBottom:    spacing.md,
      },
    ]}>
      <View style={styles.row}>
        <Text style={{ fontSize: 24 }}>🖨</Text>
        <View style={{ flex: 1, marginLeft: spacing.sm }}>
          <Text style={[typography.titleSmall, { color: colors.onSurface }]}>
            {printerName || 'Printer'}
          </Text>
          <Text style={[typography.bodySmall, { color: colors.onSurfaceVariant }]}>
            {paperLabel}
          </Text>
        </View>
        <StatusBadge status={status} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {},
  row:  { flexDirection: 'row', alignItems: 'center' },
});
