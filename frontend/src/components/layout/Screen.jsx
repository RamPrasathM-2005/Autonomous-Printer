// src/components/layout/Screen.jsx
// Base wrapper for every screen — handles safe area, scroll, offline banner.
import React from 'react';
import {
  View, ScrollView, StyleSheet, StatusBar, Text,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTheme } from '../../theme';
import { useNetworkStatus } from '../../hooks/useNetworkStatus';

/**
 * @param {{
 *   children: React.ReactNode,
 *   scrollable?: boolean,
 *   style?: object,
 *   contentStyle?: object,
 *   testID?: string,
 * }} props
 */
export default function Screen({
  children,
  scrollable = true,
  style,
  contentStyle,
  testID,
}) {
  const { colors, spacing } = useTheme();
  const { isOnline }        = useNetworkStatus();

  const containerStyle = [styles.container, { backgroundColor: colors.background }, style];
  const content        = (
    <View style={[styles.content, contentStyle]}>{children}</View>
  );

  return (
    <SafeAreaView style={containerStyle} testID={testID}>
      <StatusBar
        barStyle="dark-content"
        backgroundColor={colors.background}
      />
      {!isOnline && (
        <View style={[styles.offlineBanner, { backgroundColor: colors.errorContainer }]}>
          <Text style={[styles.offlineText, { color: colors.onErrorContainer }]}>
            No internet connection
          </Text>
        </View>
      )}
      {scrollable ? (
        <ScrollView
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
          contentContainerStyle={[styles.scroll, { padding: spacing.md }]}
        >
          {content}
        </ScrollView>
      ) : (
        <View style={[styles.noScroll, { padding: spacing.md }]}>{content}</View>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container:    { flex: 1 },
  content:      { flex: 1 },
  scroll:       { flexGrow: 1 },
  noScroll:     { flex: 1 },
  offlineBanner:{ paddingVertical: 6, paddingHorizontal: 16, alignItems: 'center' },
  offlineText:  { fontSize: 13, fontWeight: '500' },
});
