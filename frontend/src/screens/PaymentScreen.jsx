// src/screens/PaymentScreen.jsx
import React, { useState, useEffect } from 'react';
import { View, Alert } from 'react-native';
import { useNavigation, useRoute } from '@react-navigation/native';
import RazorpayCheckout  from 'react-native-razorpay';
import Screen            from '../components/layout/Screen';
import Header            from '../components/layout/Header';
import PrimaryButton     from '../components/buttons/PrimaryButton';
import PriceCard         from '../components/cards/PriceCard';
import Loading           from '../components/feedback/Loading';
import useOrderStore     from '../store/orderStore';
import usePaymentStore   from '../store/paymentStore';
import { paymentsApi }   from '../services/api/payments';
import { Routes }        from '../constants/routes';
import { useTheme }      from '../theme';
import { formatCurrency } from '../utils/format';

export default function PaymentScreen() {
  const navigation = useNavigation();
  const route      = useRoute();
  const { colors, typography, spacing } = useTheme();

  const { orderId } = route.params;
  const order       = useOrderStore((s) => s.orderDetails);
  const setPaymentInitiated = usePaymentStore((s) => s.setPaymentInitiated);

  const [loading,   setLoading]   = useState(false);
  const [preparing, setPreparing] = useState(false);

  const handlePay = async () => {
    setPreparing(true);
    try {
      // 1. Create Razorpay order on backend — backend returns key + amount
      const payData = await paymentsApi.create(orderId);
      setPaymentInitiated(payData.razorpayOrderId);

      // 2. Open Razorpay checkout sheet
      await RazorpayCheckout.open({
        description:  'Document Printing Service',
        image:        '',                      // kiosk logo URL if available
        currency:     payData.currency,
        key:          payData.keyId,
        amount:       payData.amount,
        name:         'PrintKiosk',
        order_id:     payData.razorpayOrderId,
        prefill:      { name: '', email: '', contact: '' },
        theme:        { color: colors.primary },
      });

      // 3. Razorpay returned success callback — navigate to polling screen.
      //    We do NOT trust this callback. Backend confirms payment.
      navigation.replace(Routes.PAYMENT_SUCCESS, { orderId });
    } catch (err) {
      if (err.code === 2)  { /* User cancelled — do nothing */ return; }
      Alert.alert('Payment failed', err.description || 'Please try again.');
    } finally {
      setPreparing(false);
    }
  };

  if (!order) return null;

  return (
    <View style={{ flex: 1 }}>
      <Header title="Payment" />
      {preparing ? (
        <Loading fullscreen message="Opening payment..." />
      ) : (
        <Screen>
          <PriceCard
            subtotal={order.subtotal}
            serviceFee={order.serviceFee}
            total={order.total}
          />
          <View style={{ height: spacing.xl }} />
          <PrimaryButton
            label={`Pay Securely — ${formatCurrency(order.total)}`}
            onPress={handlePay}
            loading={loading}
          />
        </Screen>
      )}
    </View>
  );
}
