// src/screens/CompletedScreen.jsx
// Session end — all stores are reset, user can start again.
import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import Screen        from '../components/layout/Screen';
import PrimaryButton from '../components/buttons/PrimaryButton';
import useDocumentStore      from '../store/documentStore';
import useConfigStore        from '../store/configStore';
import useOrderStore         from '../store/orderStore';
import usePaymentStore       from '../store/paymentStore';
import useOTPStore           from '../store/otpStore';
import usePrintStatusStore   from '../store/printStatusStore';
import { Routes }            from '../constants/routes';
import { useTheme }          from '../theme';

export default function CompletedScreen() {
  const navigation = useNavigation();
  const { colors, typography, spacing } = useTheme();

  // Collect reset functions
  const resetDocs    = useDocumentStore((s) => s.reset);
  const resetConfig  = useConfigStore((s) => s.reset);
  const resetOrder   = useOrderStore((s) => s.reset);
  const resetPayment = usePaymentStore((s) => s.reset);
  const resetOTP     = useOTPStore((s) => s.reset);
  const resetPrint   = usePrintStatusStore((s) => s.reset);

  const resetAll = () => {
    resetDocs();
    resetConfig();
    resetOrder();
    resetPayment();
    resetOTP();
    resetPrint();
  };

  const handlePrintAgain = () => {
    resetAll();
    navigation.replace(Routes.HOME);
  };

  return (
    <Screen scrollable={false}>
      <View style={[styles.container, { padding: spacing.xl }]}>
        <Text style={{ fontSize: 80, textAlign: 'center' }}>🎉</Text>

        <Text style={[typography.headlineMedium, { color: colors.success, textAlign: 'center', marginTop: spacing.lg }]}>
          Printing Complete!
        </Text>

        <Text style={[typography.bodyLarge, { color: colors.onSurfaceVariant, textAlign: 'center', marginTop: spacing.sm, marginBottom: spacing.xl }]}>
          Your documents have been printed.{'\n'}You can collect them from the printer tray.
        </Text>

        <Text style={[typography.bodySmall, { color: colors.outline, textAlign: 'center', marginBottom: spacing.xl }]}>
          Thank you for using PrintKiosk!
        </Text>

        <PrimaryButton
          label="Print Again"
          onPress={handlePrintAgain}
        />
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
