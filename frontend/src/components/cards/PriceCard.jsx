// src/components/cards/PriceCard.jsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';
import { formatCurrency } from '../../utils/format';

/**
 * @param {{ subtotal: number, serviceFee: number, total: number, currency?: string }} props
 */
export default function PriceCard({ subtotal, serviceFee, total }) {
  const { colors, typography, spacing, radius } = useTheme();

  const Row = ({ label, value, bold }) => (
    <View style={styles.row}>
      <Text style={[bold ? typography.titleSmall : typography.bodyMedium, { color: colors.onSurface }]}>{label}</Text>
      <Text style={[bold ? typography.titleSmall : typography.bodyMedium, { color: bold ? colors.primary : colors.onSurface }]}>
        {formatCurrency(value)}
      </Text>
    </View>
  );

  return (
    <View style={[styles.card, {
      backgroundColor: colors.surface,
      borderRadius:    radius.md,
      padding:         spacing.md,
      borderWidth:     1,
      borderColor:     colors.outlineVariant,
    }]}>
      <Row label="Subtotal"    value={subtotal}   bold={false} />
      <Row label="Service Fee" value={serviceFee} bold={false} />
      <View style={[styles.divider, { backgroundColor: colors.outlineVariant }]} />
      <Row label="TOTAL"       value={total}      bold />
    </View>
  );
}

const styles = StyleSheet.create({
  card:    {},
  row:     { flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4 },
  divider: { height: 1, marginVertical: 8 },
});
