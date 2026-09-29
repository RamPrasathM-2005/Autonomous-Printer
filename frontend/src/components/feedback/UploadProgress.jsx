// src/components/feedback/UploadProgress.jsx
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   fileName: string,
 *   progress: number,      // 0-100
 *   status: 'uploading' | 'success' | 'error',
 *   errorMessage?: string,
 *   onRetry?: () => void,
 * }} props
 */
export default function UploadProgress({ fileName, progress, status, errorMessage, onRetry }) {
  const { colors, typography, spacing, radius } = useTheme();

  const trackColor  = status === 'error' ? colors.errorContainer : colors.primaryContainer;
  const fillColor   = status === 'error' ? colors.error : colors.primary;
  const fillPercent = Math.min(100, Math.max(0, progress));

  return (
    <View style={[styles.container, { backgroundColor: colors.surfaceVariant, borderRadius: radius.md, padding: spacing.sm }]}>
      <Text style={[typography.bodySmall, { color: colors.onSurface, marginBottom: spacing.xs }]} numberOfLines={1}>
        {fileName}
      </Text>

      <View style={[styles.track, { backgroundColor: trackColor, borderRadius: radius.full }]}>
        <View style={[styles.fill, { width: `${fillPercent}%`, backgroundColor: fillColor, borderRadius: radius.full }]} />
      </View>

      <View style={styles.row}>
        <Text style={[typography.labelSmall, { color: status === 'error' ? colors.error : colors.onSurfaceVariant }]}>
          {status === 'error' ? (errorMessage || 'Upload failed') : status === 'success' ? 'Done' : `${fillPercent}%`}
        </Text>
        {status === 'error' && onRetry && (
          <TouchableOpacity onPress={onRetry}>
            <Text style={[typography.labelSmall, { color: colors.primary }]}>Retry</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {},
  track:     { height: 6, overflow: 'hidden', marginVertical: 4 },
  fill:      { height: '100%' },
  row:       { flexDirection: 'row', justifyContent: 'space-between' },
});
