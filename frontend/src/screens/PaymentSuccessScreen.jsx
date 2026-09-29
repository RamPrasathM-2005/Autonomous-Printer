// src/screens/PaymentSuccessScreen.jsx
// Polls backend for job creation. Razorpay callback is NOT trusted here.
import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import Loading              from '../components/feedback/Loading';
import SecondaryButton      from '../components/buttons/SecondaryButton';
import { usePaymentSuccessPoller } from '../hooks/usePaymentSuccessPoller';
import usePrintStatusStore  from '../store/printStatusStore';
import { Routes }           from '../constants/routes';
import { useTheme }         from '../theme';

export default function PaymentSuccessScreen() {
  const navigation  = useNavigation();
  const route       = useRoute();
  const { colors, typography, spacing } = useTheme();

  const { orderId } = route.params;
  const setJob      = usePrintStatusStore((s) => s.setJob);

  usePaymentSuccessPoller(orderId, {
    onSuccess: (jobId) => {
      setJob(jobId);
      navigation.replace(Routes.OTP, { orderId });
    },
    onTimeout: () => {
      // Job creation is delayed — navigate anyway, OTP screen will handle it
      navigation.replace(Routes.OTP, { orderId });
    },
    onError: () => {
      // Network issue — let user retry from OTP screen
      navigation.replace(Routes.OTP, { orderId });
    },
  });

  return (
    <View style={[styles.container, { backgroundColor: colors.surface, padding: spacing.xl }]}>
      <Text style={{ fontSize: 72, textAlign: 'center' }}>✅</Text>
      <Text style={[typography.headlineMedium, { color: colors.success, textAlign: 'center', marginTop: spacing.md }]}>
        Payment Successful
      </Text>
      <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, textAlign: 'center', marginTop: spacing.sm }]}>
        Confirming your print job...
      </Text>
      <Loading message="Please wait" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center' },
});
