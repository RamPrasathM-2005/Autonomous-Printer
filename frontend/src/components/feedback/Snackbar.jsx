// src/components/feedback/Snackbar.jsx
// Global Snackbar — mount <SnackbarHost /> once in App.jsx, use useSnackbar() anywhere.
import React, { useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Animated } from 'react-native';
import { useTheme } from '../../theme';
import { useSnackbar } from '../../hooks/useSnackbar';

const AUTO_DISMISS_MS = 4000;

/**
 * Mount once at the root of your app.
 */
export function SnackbarHost() {
  const { visible, message, action, hide } = useSnackbar();
  const { colors, typography, spacing, radius } = useTheme();
  const opacity = React.useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (visible) {
      Animated.timing(opacity, { toValue: 1, duration: 200, useNativeDriver: true }).start();
      const timer = setTimeout(hide, AUTO_DISMISS_MS);
      return () => clearTimeout(timer);
    } else {
      Animated.timing(opacity, { toValue: 0, duration: 200, useNativeDriver: true }).start();
    }
  }, [visible]);

  if (!visible && opacity._value === 0) return null;

  return (
    <Animated.View
      style={[
        styles.container,
        {
          backgroundColor: colors.onSurface,
          borderRadius: radius.sm,
          padding: spacing.md,
          marginHorizontal: spacing.md,
          marginBottom: spacing.lg,
          opacity,
        },
      ]}
    >
      <Text style={[typography.bodyMedium, { color: colors.surface, flex: 1 }]}>
        {message}
      </Text>
      {action && (
        <TouchableOpacity onPress={() => { action.onPress(); hide(); }} style={{ marginLeft: spacing.sm }}>
          <Text style={[typography.labelLarge, { color: colors.primary }]}>
            {action.label}
          </Text>
        </TouchableOpacity>
      )}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position:       'absolute',
    bottom:          0,
    left:            0,
    right:           0,
    flexDirection:  'row',
    alignItems:     'center',
  },
});
