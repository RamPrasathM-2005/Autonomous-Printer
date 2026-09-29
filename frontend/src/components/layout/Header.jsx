// src/components/layout/Header.jsx
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useTheme } from '../../theme';

/**
 * @param {{
 *   title: string,
 *   showBack?: boolean,
 *   onBack?: () => void,
 *   right?: React.ReactNode,
 * }} props
 */
export default function Header({ title, showBack = true, onBack, right }) {
  const navigation        = useNavigation();
  const { colors, typography, spacing } = useTheme();

  const handleBack = () => {
    if (onBack) return onBack();
    if (navigation.canGoBack()) navigation.goBack();
  };

  return (
    <View style={[styles.container, {
      backgroundColor: colors.surface,
      paddingHorizontal: spacing.md,
      paddingVertical: spacing.sm,
      borderBottomColor: colors.outlineVariant,
    }]}>
      <View style={styles.left}>
        {showBack && (
          <TouchableOpacity
            onPress={handleBack}
            hitSlop={{ top: 12, bottom: 12, left: 12, right: 12 }}
            accessibilityLabel="Go back"
            style={styles.backButton}
          >
            <Text style={[styles.backIcon, { color: colors.primary }]}>‹</Text>
          </TouchableOpacity>
        )}
      </View>

      <Text
        style={[typography.titleMedium, styles.title, { color: colors.onSurface }]}
        numberOfLines={1}
      >
        {title}
      </Text>

      <View style={styles.right}>{right || null}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  container:  { flexDirection: 'row', alignItems: 'center', borderBottomWidth: 1 },
  left:       { width: 40, alignItems: 'flex-start' },
  right:      { width: 40, alignItems: 'flex-end' },
  title:      { flex: 1, textAlign: 'center' },
  backButton: { padding: 4 },
  backIcon:   { fontSize: 32, lineHeight: 36 },
});
