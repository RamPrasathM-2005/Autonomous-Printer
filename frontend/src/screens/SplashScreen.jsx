// src/screens/SplashScreen.jsx
// Checks backend health + printer status → navigates to HomeScreen or shows error.
import React, { useEffect, useState } from 'react';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { healthApi }    from '../services/api/health';
import { printerApi }   from '../services/api/printer';
import useAppStore      from '../store/appStore';
import { Routes }       from '../constants/routes';
import { useTheme }     from '../theme';

export default function SplashScreen() {
  const navigation  = useNavigation();
  const { colors, typography, spacing } = useTheme();
  const [status, setStatus] = useState('Checking connection...');
  const [error, setError]   = useState(null);

  const setBackendStatus  = useAppStore((s) => s.setBackendStatus);
  const setPrinterStatus  = useAppStore((s) => s.setPrinterStatus);
  const setInitialized    = useAppStore((s) => s.setInitialized);

  useEffect(() => {
    let cancelled = false;

    async function initialize() {
      try {
        // 1. Health check
        setStatus('Connecting to server...');
        await healthApi.check();
        if (cancelled) return;
        setBackendStatus('online');

        // 2. Printer status
        setStatus('Checking printer...');
        const printer = await printerApi.getStatus();
        if (cancelled) return;
        setPrinterStatus(printer.status, printer.printerName, printer.paperStatus);

        // 3. Done
        setInitialized();
        setStatus('Ready!');
        setTimeout(() => {
          if (!cancelled) navigation.replace(Routes.HOME);
        }, 600);
      } catch (err) {
        if (cancelled) return;
        setBackendStatus('offline');
        setError(err.message || 'Could not connect. Please check your network.');
      }
    }

    initialize();
    return () => { cancelled = true; };
  }, []);

  return (
    <View style={[styles.container, { backgroundColor: colors.primary }]}>
      <Text style={[typography.displaySmall, { color: colors.onPrimary, marginBottom: spacing.sm }]}>
        🖨 PrintKiosk
      </Text>
      <Text style={[typography.titleMedium, { color: colors.primaryContainer, marginBottom: spacing.xl }]}>
        Self-Service Printing
      </Text>

      {error ? (
        <View style={[styles.errorBox, { backgroundColor: colors.errorContainer, borderRadius: 12, padding: spacing.md }]}>
          <Text style={[typography.bodyMedium, { color: colors.onErrorContainer, textAlign: 'center' }]}>{error}</Text>
          <Text style={[typography.labelMedium, { color: colors.onErrorContainer, marginTop: spacing.sm, textAlign: 'center' }]}>
            Please contact the desk or try again.
          </Text>
        </View>
      ) : (
        <>
          <ActivityIndicator color={colors.onPrimary} size="large" style={{ marginBottom: spacing.md }} />
          <Text style={[typography.bodyMedium, { color: colors.primaryContainer }]}>{status}</Text>
        </>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32 },
  errorBox:  { width: '100%', maxWidth: 320 },
});
