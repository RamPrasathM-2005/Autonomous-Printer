import '../models/order.dart';
import 'api_service.dart';
import 'session_store.dart';

enum RecoveryStage { none, unpaid, waitingOtp, printing, completed, terminated }

class OrderRecoveryResult {
  final RecoveryStage stage;
  final PrintOrder? order;
  final OrderOtp? otp;
  final String? selectedPrinter;
  final bool printerSelectionLocked;
  final bool canUploadNew;
  final bool isCompletedReceipt;

  /// True when the backend was unreachable (network/timeout).
  /// Callers must not silently treat this as "no active order" — show a warning.
  final bool networkError;

  const OrderRecoveryResult({
    required this.stage,
    this.order,
    this.otp,
    this.selectedPrinter,
    this.printerSelectionLocked = false,
    this.canUploadNew = true,
    this.isCompletedReceipt = false,
    this.networkError = false,
  });

  bool get hasActiveUnfinishedOrder =>
      stage == RecoveryStage.unpaid ||
      stage == RecoveryStage.waitingOtp ||
      stage == RecoveryStage.printing;
}

class OrderRecoveryService {
  static const String _kActiveOrderId = 'autonomous_printer_active_order_id';
  static const String _kLastCompletedOrderId =
      'autonomous_printer_last_completed_order_id';
  static const String _kActiveOrderStage =
      'autonomous_printer_active_order_stage';

  /// Tracks the last completed order that the user explicitly dismissed via
  /// "Print Another Document". Recovery will never resurface this order ID.
  static const String _kDismissedCompletedOrderId =
      'autonomous_printer_dismissed_completed_id';

  static final OrderRecoveryService _instance =
      OrderRecoveryService._internal();
  factory OrderRecoveryService() => _instance;
  OrderRecoveryService._internal();

  final ApiService _api = ApiService();

  String? get activeOrderId => readSessionValue(_kActiveOrderId);
  String? get lastCompletedOrderId => readSessionValue(_kLastCompletedOrderId);
  String? get activeOrderStage => readSessionValue(_kActiveOrderStage);
  String? get dismissedCompletedOrderId =>
      readSessionValue(_kDismissedCompletedOrderId);

  void setActiveOrder(String orderId, {String? stage}) {
    writeSessionValue(_kActiveOrderId, orderId);
    if (stage != null) {
      writeSessionValue(_kActiveOrderStage, stage);
    }
  }

  void updateActiveStage(String stage) {
    writeSessionValue(_kActiveOrderStage, stage);
  }

  void markCompleted(String orderId) {
    clearSessionValue(_kActiveOrderId);
    clearSessionValue(_kActiveOrderStage);
    writeSessionValue(_kLastCompletedOrderId, orderId);
  }

  void clearAll() {
    clearSessionValue(_kActiveOrderId);
    clearSessionValue(_kActiveOrderStage);
    clearSessionValue(_kLastCompletedOrderId);
  }

  /// Print Again: dismisses the completed order so recovery never re-shows
  /// OtpReleaseScreen for it, even if the backend still reports it as COMPLETED.
  void printAgain() {
    final completedId = lastCompletedOrderId ?? activeOrderId;
    if (completedId != null) {
      writeSessionValue(_kDismissedCompletedOrderId, completedId);
    }
    clearAll();
  }

  void clearActiveOrder() {
    clearSessionValue(_kActiveOrderId);
    clearSessionValue(_kActiveOrderStage);
  }

  /// Explicitly dismiss a completed order so it is never surfaced by recovery.
  void dismissCompletedOrder(String orderId) {
    writeSessionValue(_kDismissedCompletedOrderId, orderId);
  }

  /// Single source of truth backend check.
  /// Queries backend /api/orders/active using cached order IDs and customer session.
  ///
  /// Returns an [OrderRecoveryResult] with [networkError] set to true when the
  /// backend is unreachable. Callers must surface a warning instead of treating
  /// this as "no active order" — doing so risks hiding a paid order from the user.
  Future<OrderRecoveryResult> checkRecovery() async {
    try {
      final cachedActiveId = activeOrderId;
      final cachedCompletedId = lastCompletedOrderId;

      final data = await _api.checkActiveOrder(
        orderId: cachedActiveId ?? cachedCompletedId,
      );
      final hasActive = data['hasActiveOrder'] == true;
      final stageStr = (data['stage'] as String? ?? 'NONE').toUpperCase();
      final orderData = data['order'] as Map<String, dynamic>?;
      final PrintOrder? order = orderData != null
          ? PrintOrder.fromJson(orderData)
          : null;

      if (hasActive && order != null) {
        setActiveOrder(order.id, stage: stageStr);

        if (stageStr == 'UNPAID') {
          return OrderRecoveryResult(
            stage: RecoveryStage.unpaid,
            order: order,
            canUploadNew: true,
          );
        } else if (stageStr == 'WAITING_FOR_OTP') {
          final otpData = data['otp'] as Map<String, dynamic>?;
          final otp = otpData != null ? OrderOtp.fromJson(otpData) : null;
          final selectedPrinter = data['selectedPrinter'] as String?;
          final isLocked = data['printerSelectionLocked'] == true;

          return OrderRecoveryResult(
            stage: RecoveryStage.waitingOtp,
            order: order,
            otp: otp,
            selectedPrinter: selectedPrinter,
            printerSelectionLocked: isLocked,
            canUploadNew: true,
          );
        } else if (stageStr == 'PRINTING') {
          return OrderRecoveryResult(
            stage: RecoveryStage.printing,
            order: order,
            selectedPrinter: data['selectedPrinter'] as String?,
            canUploadNew: true,
          );
        }
      }

      // Completed receipt reload — only resurface if user hasn't dismissed it.
      if (stageStr == 'COMPLETED' && order != null) {
        final dismissed = dismissedCompletedOrderId;
        if (dismissed != null && dismissed == order.id) {
          // User already pressed "Print Another Document" for this order.
          // Never re-show OtpReleaseScreen for it.
          return const OrderRecoveryResult(
            stage: RecoveryStage.none,
            canUploadNew: true,
          );
        }
        markCompleted(order.id);
        return OrderRecoveryResult(
          stage: RecoveryStage.completed,
          order: order,
          selectedPrinter: data['selectedPrinter'] as String?,
          canUploadNew: true,
          isCompletedReceipt: true,
        );
      }

      if (stageStr == 'TERMINATED') {
        clearActiveOrder();
        return const OrderRecoveryResult(
          stage: RecoveryStage.terminated,
          canUploadNew: true,
        );
      }

      if (cachedActiveId != null) {
        clearActiveOrder();
      }

      return const OrderRecoveryResult(
        stage: RecoveryStage.none,
        canUploadNew: true,
      );
    } catch (_) {
      // Network or server error — do NOT treat this as "no active order".
      // Preserve any cached order ID so recovery can be retried on next load.
      // Set networkError: true so UploadScreen can warn the user.
      return const OrderRecoveryResult(
        stage: RecoveryStage.none,
        canUploadNew: true,
        networkError: true,
      );
    }
  }
}
