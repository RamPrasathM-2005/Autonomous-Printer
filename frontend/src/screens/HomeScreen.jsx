// src/screens/HomeScreen.jsx
import React from 'react';
import { View, Text, StyleSheet, ScrollView } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import Screen             from '../components/layout/Screen';
import PrimaryButton      from '../components/buttons/PrimaryButton';
import PrinterStatusCard  from '../components/cards/PrinterStatusCard';
import useAppStore        from '../store/appStore';
import { Routes }         from '../constants/routes';
import { useTheme }       from '../theme';

export default function HomeScreen() {
  const navigation                = useNavigation();
  const { colors, typography, spacing } = useTheme();
  const printerStatus = useAppStore((s) => s.printerStatus);
  const printerName   = useAppStore((s) => s.printerName);
  const paperStatus   = useAppStore((s) => s.paperStatus);

  const isPrinterDown = printerStatus === 'offline' || paperStatus === 'empty';

  const INSTRUCTIONS = [
    { icon: '📁', text: 'Upload your files (PDF, DOCX, PPTX, PNG, JPG)' },
    { icon: '⚙️', text: 'Choose copies, color, paper size & print sides' },
    { icon: '💳', text: 'Review your order and pay securely' },
    { icon: '🔑', text: 'Show your OTP at the printer to collect' },
  ];

  return (
    <Screen scrollable testID="home-screen">
      {/* Header */}
      <View style={[styles.heroBox, { backgroundColor: colors.primaryContainer, borderRadius: 16, padding: spacing.lg, marginBottom: spacing.lg }]}>
        <Text style={[typography.headlineMedium, { color: colors.onPrimaryContainer }]}>
          Welcome 👋
        </Text>
        <Text style={[typography.bodyMedium, { color: colors.onPrimaryContainer, marginTop: 4 }]}>
          Print documents instantly from your phone.
        </Text>
      </View>

      {/* Printer status */}
      <PrinterStatusCard
        status={printerStatus}
        printerName={printerName}
        paperStatus={paperStatus}
      />

      {/* Instructions */}
      <Text style={[typography.titleSmall, { color: colors.onSurface, marginBottom: spacing.sm }]}>
        How it works
      </Text>
      {INSTRUCTIONS.map(({ icon, text }) => (
        <View key={text} style={[styles.instructionRow, { marginBottom: spacing.sm }]}>
          <Text style={{ fontSize: 20, marginRight: 10 }}>{icon}</Text>
          <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, flex: 1 }]}>{text}</Text>
        </View>
      ))}

      <View style={{ height: spacing.xl }} />

      <PrimaryButton
        label={isPrinterDown ? 'Printer Unavailable' : 'Upload Files'}
        disabled={isPrinterDown}
        onPress={() => navigation.navigate(Routes.UPLOAD)}
      />

      {isPrinterDown && (
        <Text style={[typography.bodySmall, { color: colors.error, textAlign: 'center', marginTop: spacing.sm }]}>
          {paperStatus === 'empty'
            ? 'Printer is out of paper. Please contact the desk.'
            : 'Printer is currently offline. Please try again later.'}
        </Text>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  heroBox:        {},
  instructionRow: { flexDirection: 'row', alignItems: 'flex-start' },
});
