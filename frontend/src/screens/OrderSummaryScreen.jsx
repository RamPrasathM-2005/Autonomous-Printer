// src/screens/OrderSummaryScreen.jsx
import React, { useState, useCallback } from 'react';
import { View, Text, FlatList, Alert } from 'react-native';
import { useNavigation, useFocusEffect } from '@react-navigation/native';
import Screen        from '../components/layout/Screen';
import Header        from '../components/layout/Header';
import PrimaryButton from '../components/buttons/PrimaryButton';
import PriceCard     from '../components/cards/PriceCard';
import Loading       from '../components/feedback/Loading';
import ErrorState    from '../components/feedback/ErrorState';
import { ordersApi } from '../services/api/orders';
import useDocumentStore from '../store/documentStore';
import useConfigStore   from '../store/configStore';
import useOrderStore    from '../store/orderStore';
import { Routes }    from '../constants/routes';
import { useTheme }  from '../theme';
import { formatCurrency, truncateFileName } from '../utils/format';

export default function OrderSummaryScreen() {
  const navigation = useNavigation();
  const { colors, typography, spacing, radius } = useTheme();

  const documents  = useDocumentStore((s) => s.documents);
  const getConfig  = useConfigStore((s) => s.getConfiguration);
  const setOrder   = useOrderStore((s) => s.setOrder);
  const storedOrder = useOrderStore((s) => s.orderDetails);

  const [order, setLocalOrder]  = useState(storedOrder);
  const [loading, setLoading]   = useState(false);
  const [error, setError]       = useState(null);

  // Re-create order every time this screen is focused (config may have changed)
  useFocusEffect(
    useCallback(() => {
      createOrder();
    }, [])
  );

  const createOrder = async () => {
    setLoading(true);
    setError(null);
    try {
      const payload = {
        documents: documents.map((doc) => {
          const cfg = getConfig(doc.documentId);
          return {
            documentId:  doc.documentId,
            copies:      cfg?.copies     ?? 1,
            pageRange:   cfg?.pageMode === 'custom' ? cfg.customPageRange : null,
            colorMode:   cfg?.colorMode  ?? 'bw',
            printSide:   cfg?.printSide  ?? 'single',
            paperSize:   cfg?.paperSize  ?? 'A4',
            orientation: cfg?.orientation ?? 'portrait',
          };
        }),
      };
      const result = await ordersApi.create(payload);
      setOrder(result.orderId, result);
      setLocalOrder(result);
    } catch (err) {
      setError(err.code || 'ORDER_CREATION_FAILED');
    } finally {
      setLoading(false);
    }
  };

  if (loading) return <Loading fullscreen message="Calculating your order..." />;
  if (error)   return <ErrorState code={error} onRetry={createOrder} />;
  if (!order)  return null;

  return (
    <View style={{ flex: 1 }}>
      <Header title="Order Summary" />
      <Screen>
        <FlatList
          data={order.items}
          keyExtractor={(item) => item.documentId}
          scrollEnabled={false}
          renderItem={({ item }) => (
            <View style={[{
              backgroundColor: colors.surface,
              borderRadius: radius.md,
              padding: spacing.md,
              marginBottom: spacing.sm,
              borderWidth: 1,
              borderColor: colors.outlineVariant,
            }]}>
              <Text style={[typography.titleSmall, { color: colors.onSurface }]} numberOfLines={1}>
                {truncateFileName(item.fileName)}
              </Text>
              <Text style={[typography.bodySmall, { color: colors.onSurfaceVariant }]}>
                {item.pages} pages · {item.copies} cop{item.copies !== 1 ? 'ies' : 'y'}
              </Text>
              <Text style={[typography.bodyMedium, { color: colors.primary, marginTop: 4 }]}>
                {formatCurrency(item.totalPrice)}
              </Text>
            </View>
          )}
        />

        <PriceCard
          subtotal={order.subtotal}
          serviceFee={order.serviceFee}
          total={order.total}
        />

        <View style={{ height: spacing.xl }} />

        <PrimaryButton
          label={`Pay ${formatCurrency(order.total)}`}
          onPress={() => navigation.navigate(Routes.PAYMENT, { orderId: order.orderId })}
        />
      </Screen>
    </View>
  );
}
