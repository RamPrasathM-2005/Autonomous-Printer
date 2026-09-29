// src/components/status/StatusBadge.jsx
import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

const STATUS_CONFIG = {
  online:          { bg: '#C8F5D8', text: '#1B7A47', label: 'Online' },
  offline:         { bg: '#F9DEDC', text: '#B3261E', label: 'Offline' },
  busy:            { bg: '#FFDEA0', text: '#7A5100', label: 'Busy' },
  unknown:         { bg: '#E7E0EC', text: '#49454F', label: 'Unknown' },
  JOB_QUEUED:      { bg: '#E8DEF8', text: '#625B71', label: 'Queued' },
  WAITING_FOR_OTP: { bg: '#FFDEA0', text: '#7A5100', label: 'Waiting for OTP' },
  OTP_VERIFIED:    { bg: '#C8F5D8', text: '#1B7A47', label: 'OTP Verified' },
  PRINTING:        { bg: '#EADDFF', text: '#6750A4', label: 'Printing' },
  COMPLETED:       { bg: '#C8F5D8', text: '#1B7A47', label: 'Completed' },
  FAILED:          { bg: '#F9DEDC', text: '#B3261E', label: 'Failed' },
};

/**
 * @param {{ status: string, customLabel?: string }} props
 */
export default function StatusBadge({ status, customLabel }) {
  const { typography, radius } = useTheme();
  const config = STATUS_CONFIG[status] || STATUS_CONFIG.unknown;

  return (
    <View style={[styles.badge, { backgroundColor: config.bg, borderRadius: radius.full }]}>
      <Text style={[typography.labelSmall, { color: config.text }]}>
        {customLabel || config.label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: { paddingHorizontal: 10, paddingVertical: 4, alignSelf: 'flex-start' },
});
