// src/screens/PrintStatusScreen.jsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import Screen          from '../components/layout/Screen';
import ProgressBar     from '../components/status/ProgressBar';
import StatusTimeline  from '../components/status/StatusTimeline';
import StatusBadge     from '../components/status/StatusBadge';
import { usePrintStatusPoller } from '../hooks/usePrintStatusPoller';
import usePrintStatusStore from '../store/printStatusStore';
import { Routes }      from '../constants/routes';
import { useTheme }    from '../theme';

// Timeline steps in order
function buildSteps(currentStatus) {
  const ORDER = ['JOB_QUEUED', 'WAITING_FOR_OTP', 'OTP_VERIFIED', 'PRINTING', 'COMPLETED'];
  const currentIdx = ORDER.indexOf(currentStatus);
  return [
    { label: 'Job queued',      status: currentIdx > 0 ? 'completed' : currentIdx === 0 ? 'active' : 'pending' },
    { label: 'OTP requested',   status: currentIdx > 1 ? 'completed' : currentIdx === 1 ? 'active' : 'pending' },
    { label: 'OTP verified',    status: currentIdx > 2 ? 'completed' : currentIdx === 2 ? 'active' : 'pending' },
    { label: 'Printing',        status: currentIdx > 3 ? 'completed' : currentIdx === 3 ? 'active' : 'pending' },
    { label: 'Completed',       status: currentIdx >= 4 ? 'completed' : 'pending' },
  ];
}

export default function PrintStatusScreen() {
  const navigation = useNavigation();
  const route      = useRoute();
  const { colors, typography, spacing } = useTheme();

  const { orderId, jobId } = route.params;
  const status    = usePrintStatusStore((s) => s.status);
  const progress  = usePrintStatusStore((s) => s.progress);
  const queue     = usePrintStatusStore((s) => s.queuePosition);

  usePrintStatusPoller(jobId, {
    onCompleted: () => navigation.replace(Routes.COMPLETED, { orderId }),
    onFailed:    () => { /* Show failed badge — no auto navigate */ },
  });

  const steps = buildSteps(status || 'JOB_QUEUED');

  return (
    <View style={{ flex: 1 }}>
      <Screen scrollable={false}>
        <View style={[styles.center, { padding: spacing.lg }]}>
          <Text style={{ fontSize: 56, textAlign: 'center' }}>🖨</Text>
          <Text style={[typography.headlineMedium, { color: colors.onSurface, textAlign: 'center', marginVertical: spacing.sm }]}>
            Print Status
          </Text>

          <StatusBadge status={status || 'JOB_QUEUED'} />

          {queue !== null && status === 'JOB_QUEUED' && (
            <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, marginTop: spacing.sm }]}>
              Position in queue: {queue}
            </Text>
          )}

          {status === 'PRINTING' && (
            <View style={{ width: '100%', marginTop: spacing.lg }}>
              <Text style={[typography.labelMedium, { color: colors.onSurfaceVariant, marginBottom: spacing.xs }]}>
                Printing... {progress}%
              </Text>
              <ProgressBar progress={progress} />
            </View>
          )}

          {status === 'FAILED' && (
            <View style={[styles.failBox, { backgroundColor: colors.errorContainer, borderRadius: 12, padding: spacing.md, marginTop: spacing.lg }]}>
              <Text style={[typography.bodyMedium, { color: colors.onErrorContainer, textAlign: 'center' }]}>
                Print job failed. A refund will be processed automatically.
              </Text>
            </View>
          )}
        </View>

        <View style={{ paddingHorizontal: spacing.md }}>
          <StatusTimeline steps={steps} />
        </View>
      </Screen>
    </View>
  );
}

const styles = StyleSheet.create({
  center:  { alignItems: 'center' },
  failBox: {},
});
