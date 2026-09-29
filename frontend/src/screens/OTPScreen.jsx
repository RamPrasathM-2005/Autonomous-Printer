// src/screens/OTPScreen.jsx
import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Alert } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import Screen       from '../components/layout/Screen';
import OTPCard      from '../components/cards/OTPCard';
import Loading      from '../components/feedback/Loading';
import ErrorState   from '../components/feedback/ErrorState';
import { otpApi }   from '../services/api/otp';
import useOTPStore  from '../store/otpStore';
import usePrintStatusStore from '../store/printStatusStore';
import { ordersApi }from '../services/api/orders';
import { Routes }   from '../constants/routes';
import { useTheme } from '../theme';

// Poll OTP endpoint until OTP_VERIFIED status arrives, then auto-navigate
const OTP_POLL_MS = 3000;

export default function OTPScreen() {
  const navigation = useNavigation();
  const route      = useRoute();
  const { colors, typography, spacing } = useTheme();

  const { orderId } = route.params;
  const jobId       = usePrintStatusStore((s) => s.jobId);

  const storedOTP   = useOTPStore((s) => s.otp);
  const storedExp   = useOTPStore((s) => s.expiresAt);
  const setOTP      = useOTPStore((s) => s.setOTP);

  const [loading, setLoading]   = useState(!storedOTP);
  const [error, setError]       = useState(null);

  // Fetch OTP on mount if not already in store
  useEffect(() => {
    if (storedOTP) return;

    let mounted = true;
    otpApi.getOTP(orderId)
      .then((data) => {
        if (!mounted) return;
        setOTP(data.otp, data.expiresAt);
        setLoading(false);
      })
      .catch((err) => {
        if (!mounted) return;
        setError(err.code || 'OTP_NOT_FOUND');
        setLoading(false);
      });

    return () => { mounted = false; };
  }, [orderId]);

  // Poll order status waiting for OTP_VERIFIED
  useEffect(() => {
    const interval = setInterval(async () => {
      try {
        const status = await ordersApi.getStatus(orderId);
        if (status.jobStatus === 'OTP_VERIFIED' || status.jobStatus === 'PRINTING') {
          clearInterval(interval);
          navigation.replace(Routes.PRINT_STATUS, { orderId, jobId: status.jobId || jobId });
        }
      } catch { /* ignore transient errors */ }
    }, OTP_POLL_MS);

    return () => clearInterval(interval);
  }, [orderId, jobId]);

  const handleOTPExpired = () => {
    Alert.alert('OTP Expired', 'Your OTP has expired. Please contact support.', [
      { text: 'OK', onPress: () => navigation.navigate(Routes.HOME) },
    ]);
  };

  if (loading) return <Loading fullscreen message="Fetching your OTP..." />;
  if (error)   return <ErrorState code={error} />;

  return (
    <View style={{ flex: 1 }}>
      <Screen scrollable={false}>
        <View style={[styles.top, { padding: spacing.lg }]}>
          <Text style={[typography.headlineSmall, { color: colors.onSurface, marginBottom: spacing.sm, textAlign: 'center' }]}>
            Show this OTP at the printer
          </Text>
          <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, textAlign: 'center', marginBottom: spacing.xl }]}>
            Enter this code on the kiosk touchscreen to start printing.
          </Text>
        </View>

        <OTPCard
          otp={storedOTP}
          expiresAt={storedExp}
          onExpired={handleOTPExpired}
        />

        <Text style={[typography.bodySmall, { color: colors.onSurfaceVariant, textAlign: 'center', marginTop: spacing.md }]}>
          Waiting for you to enter the OTP at the printer...
        </Text>
      </Screen>
    </View>
  );
}

const styles = StyleSheet.create({
  top: {},
});
