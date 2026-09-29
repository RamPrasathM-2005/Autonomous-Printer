// src/components/status/ProgressBar.jsx
import React, { useEffect } from 'react';
import { View, StyleSheet } from 'react-native';
import Animated, { useSharedValue, useAnimatedStyle, withTiming } from 'react-native-reanimated';
import { useTheme } from '../../theme';

/**
 * @param {{ progress: number, color?: string, height?: number }} props
 */
export default function ProgressBar({ progress, color, height = 8 }) {
  const { colors, radius } = useTheme();
  const fillColor           = color || colors.primary;
  const animWidth           = useSharedValue(0);

  useEffect(() => {
    animWidth.value = withTiming(Math.min(100, Math.max(0, progress)), { duration: 400 });
  }, [progress]);

  const animStyle = useAnimatedStyle(() => ({
    width: `${animWidth.value}%`,
  }));

  return (
    <View style={[styles.track, { height, backgroundColor: colors.surfaceVariant, borderRadius: radius.full }]}>
      <Animated.View style={[styles.fill, { height, backgroundColor: fillColor, borderRadius: radius.full }, animStyle]} />
    </View>
  );
}

const styles = StyleSheet.create({
  track: { overflow: 'hidden', width: '100%' },
  fill:  {},
});
