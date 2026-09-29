// App.jsx — Root entry point
import React from 'react';
import { StyleSheet, View } from 'react-native';
import { NavigationContainer } from '@react-navigation/native';
import { SafeAreaProvider }    from 'react-native-safe-area-context';
import RootNavigator           from './src/navigation/RootNavigator';
import { SnackbarHost }        from './src/components/feedback/Snackbar';

export default function App() {
  return (
    <SafeAreaProvider>
      <NavigationContainer>
        {/* Root navigator — all 11 screens wired here */}
        <RootNavigator />

        {/* Global Snackbar — renders above everything */}
        <SnackbarHost />
      </NavigationContainer>
    </SafeAreaProvider>
  );
}
