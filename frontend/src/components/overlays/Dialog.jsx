// src/components/overlays/Dialog.jsx
import React from 'react';
import { View, Text, Modal, TouchableOpacity, StyleSheet } from 'react-native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   visible: boolean,
 *   title: string,
 *   message: string,
 *   confirmLabel?: string,
 *   cancelLabel?: string,
 *   onConfirm: () => void,
 *   onCancel: () => void,
 *   dangerous?: boolean,
 * }} props
 */
export default function Dialog({
  visible,
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel  = 'Cancel',
  onConfirm,
  onCancel,
  dangerous    = false,
}) {
  const { colors, typography, spacing, radius } = useTheme();

  return (
    <Modal transparent visible={visible} animationType="fade" onRequestClose={onCancel}>
      <View style={[styles.overlay, { backgroundColor: colors.scrim }]}>
        <View style={[styles.dialog, {
          backgroundColor: colors.surface,
          borderRadius:    radius.lg,
          padding:         spacing.lg,
          margin:          spacing.xl,
        }]}>
          <Text style={[typography.headlineSmall, { color: colors.onSurface, marginBottom: spacing.sm }]}>
            {title}
          </Text>
          <Text style={[typography.bodyMedium, { color: colors.onSurfaceVariant, marginBottom: spacing.lg }]}>
            {message}
          </Text>
          <View style={styles.actions}>
            <TouchableOpacity onPress={onCancel} style={styles.btn}>
              <Text style={[typography.labelLarge, { color: colors.primary }]}>{cancelLabel}</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={onConfirm} style={styles.btn}>
              <Text style={[typography.labelLarge, { color: dangerous ? colors.error : colors.primary }]}>
                {confirmLabel}
              </Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  overlay: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  dialog:  { width: '100%' },
  actions: { flexDirection: 'row', justifyContent: 'flex-end', gap: 16 },
  btn:     { paddingVertical: 8, paddingHorizontal: 4 },
});
