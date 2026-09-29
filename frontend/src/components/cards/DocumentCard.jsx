// src/components/cards/DocumentCard.jsx
import React from 'react';
import { View, Text, TouchableOpacity, Image, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';
import { formatFileSize, truncateFileName } from '../../utils/format';

/**
 * @param {{
 *   document: { documentId, fileName, pageCount, fileSizeBytes, thumbnailUrl, status },
 *   onEdit: (id: string) => void,
 *   onDelete: (id: string) => void,
 *   isDeleting?: boolean,
 * }} props
 */
export default function DocumentCard({ document, onEdit, onDelete, isDeleting = false }) {
  const { colors, typography, spacing, radius, elevation } = useTheme();

  const iconForType = (name) => {
    const ext = name?.split('.').pop()?.toLowerCase();
    const map = { pdf: '📄', docx: '📝', pptx: '📊', png: '🖼', jpg: '🖼', jpeg: '🖼' };
    return map[ext] || '📎';
  };

  return (
    <View style={[
      styles.card,
      elevation.low,
      {
        backgroundColor: colors.surface,
        borderRadius:    radius.md,
        padding:         spacing.md,
        marginBottom:    spacing.sm,
        borderWidth:     1,
        borderColor:     colors.outlineVariant,
      },
    ]}>
      {/* Left: icon/thumbnail */}
      <View style={styles.thumb}>
        {document.thumbnailUrl ? (
          <Image source={{ uri: document.thumbnailUrl }} style={styles.thumbImg} />
        ) : (
          <Text style={{ fontSize: 36 }}>{iconForType(document.fileName)}</Text>
        )}
      </View>

      {/* Centre: meta */}
      <View style={styles.meta}>
        <Text style={[typography.titleSmall, { color: colors.onSurface }]} numberOfLines={1}>
          {truncateFileName(document.fileName)}
        </Text>
        <Text style={[typography.bodySmall, { color: colors.onSurfaceVariant, marginTop: 2 }]}>
          {document.pageCount} page{document.pageCount !== 1 ? 's' : ''} · {formatFileSize(document.fileSizeBytes)}
        </Text>
      </View>

      {/* Right: actions */}
      <View style={styles.actions}>
        <TouchableOpacity
          onPress={() => onEdit(document.documentId)}
          accessibilityLabel="Edit configuration"
          style={[styles.iconBtn, { backgroundColor: colors.primaryContainer, borderRadius: radius.sm }]}
        >
          <Text>✏️</Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={() => onDelete(document.documentId)}
          disabled={isDeleting}
          accessibilityLabel="Delete document"
          style={[styles.iconBtn, { backgroundColor: colors.errorContainer, borderRadius: radius.sm, opacity: isDeleting ? 0.5 : 1 }]}
        >
          <Text>🗑</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  card:    { flexDirection: 'row', alignItems: 'center' },
  thumb:   { width: 50, height: 50, alignItems: 'center', justifyContent: 'center', marginRight: 12 },
  thumbImg:{ width: 50, height: 50, borderRadius: 6 },
  meta:    { flex: 1 },
  actions: { gap: 8 },
  iconBtn: { padding: 8 },
});
