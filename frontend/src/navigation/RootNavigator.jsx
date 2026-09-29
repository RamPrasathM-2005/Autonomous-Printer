// src/navigation/RootNavigator.jsx
import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Routes } from '../constants/routes';

// Screens
import SplashScreen       from '../screens/SplashScreen';
import HomeScreen         from '../screens/HomeScreen';
import UploadScreen       from '../screens/UploadScreen';
import UploadedDocumentsScreen  from '../screens/UploadedDocumentsScreen';
import PrintConfigurationScreen from '../screens/PrintConfigurationScreen';
import OrderSummaryScreen       from '../screens/OrderSummaryScreen';
import PaymentScreen      from '../screens/PaymentScreen';
import PaymentSuccessScreen     from '../screens/PaymentSuccessScreen';
import OTPScreen          from '../screens/OTPScreen';
import PrintStatusScreen  from '../screens/PrintStatusScreen';
import CompletedScreen    from '../screens/CompletedScreen';

const Stack = createNativeStackNavigator();

export default function RootNavigator() {
  return (
    <Stack.Navigator
      initialRouteName={Routes.SPLASH}
      screenOptions={{
        headerShown: false,     // All headers are custom (Header.jsx)
        animation: 'slide_from_right',
        gestureEnabled: false,  // Disable swipe-back — navigation is app-controlled
      }}
    >
      <Stack.Screen name={Routes.SPLASH}           component={SplashScreen} />
      <Stack.Screen name={Routes.HOME}             component={HomeScreen} />
      <Stack.Screen name={Routes.UPLOAD}           component={UploadScreen} />
      <Stack.Screen name={Routes.UPLOADED_DOCUMENTS}  component={UploadedDocumentsScreen} />
      <Stack.Screen name={Routes.PRINT_CONFIGURATION} component={PrintConfigurationScreen} />
      <Stack.Screen name={Routes.ORDER_SUMMARY}    component={OrderSummaryScreen} />
      <Stack.Screen name={Routes.PAYMENT}          component={PaymentScreen} />
      <Stack.Screen name={Routes.PAYMENT_SUCCESS}  component={PaymentSuccessScreen} />
      <Stack.Screen name={Routes.OTP}              component={OTPScreen} />
      <Stack.Screen name={Routes.PRINT_STATUS}     component={PrintStatusScreen} />
      <Stack.Screen name={Routes.COMPLETED}        component={CompletedScreen} />
    </Stack.Navigator>
  );
}
