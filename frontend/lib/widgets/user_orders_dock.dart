import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/order.dart';
import '../models/user_profile.dart';
import '../services/customer_auth_service.dart';
import '../screens/otp_release_screen.dart';
import '../screens/payment_screen.dart';
import '../screens/print_progress_screen.dart';
import '../services/api_error.dart';
import 'invoice_preview_dialog.dart';

class UserOrdersDock extends StatefulWidget {
  const UserOrdersDock({super.key, this.auth});

  final CustomerAuthService? auth;

  @override
  State<UserOrdersDock> createState() => _UserOrdersDockState();
}

class _UserOrdersDockState extends State<UserOrdersDock>
    with WidgetsBindingObserver {
  late final CustomerAuthService _auth = widget.auth ?? CustomerAuthService();
  final ValueNotifier<int> _revision = ValueNotifier(0);
  int _accountVersion = 0;
  String? _error;
  List<PrintOrder> _orders = [];
  bool _isLoading = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth.userNotifier.addListener(_accountChanged);
    _loadOrders();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _auth.userNotifier.removeListener(_accountChanged);
    _revision.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _auth.isLoggedIn) {
      _loadOrders();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && _auth.isLoggedIn) {
        _loadOrders(quiet: true);
      }
    });
  }

  void _accountChanged() {
    _accountVersion++;
    setState(() {
      _orders = [];
      _error = null;
      _isLoading = false;
    });
    _revision.value++;
    _loadOrders();
  }

  Future<void> _loadOrders({bool quiet = false}) async {
    if (!mounted || !_auth.isLoggedIn || _isLoading) return;
    final version = _accountVersion;
    setState(() {
      _isLoading = true;
      if (!quiet) _error = null;
    });
    _revision.value++;
    try {
      final list = await _auth.fetchMyOrders();
      if (!mounted || version != _accountVersion) return;
      setState(() {
        _orders = list;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || version != _accountVersion) return;
      setState(() {
        _isLoading = false;
        _error = userError(
          error,
          fallback: 'Unable to load your orders. Refresh to retry.',
        );
      });
    }
    _revision.value++;
  }

  void _openOrdersSheet() {
    _loadOrders(quiet: true);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: _revision,
        builder: (_, revision, child) => _OrdersSheetContent(
          orders: _orders,
          isLoading: _isLoading,
          error: _error,
          onRefresh: () async => _loadOrders(),
          onResumeOtp: (order) {
            Navigator.of(ctx).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    OtpReleaseScreen(orderId: order.id, order: order),
              ),
            ).then((_) => _loadOrders());
          },
          onResumePayment: (order) {
            Navigator.of(ctx).pop();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PaymentScreen(order: order)),
            ).then((_) => _loadOrders());
          },
          onViewProgress: (order) {
            Navigator.of(ctx).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PrintProgressScreen(
                  orderId: order.id,
                  otp: '',
                  printServerId: order.printServerId,
                ),
              ),
            ).then((_) => _loadOrders());
          },
          onViewInvoice: (order) {
            InvoicePreviewDialog.show(context, order: order);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: _auth.userNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return const SizedBox.shrink();
        }

        final activeOrders = _orders.where((order) => order.isPending).toList();
        final hasActive = activeOrders.isNotEmpty;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openOrdersSheet,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: hasActive
                          ? const Color(0xFFF0F7FF)
                          : AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasActive
                            ? const Color(0xFFBFDBFE)
                            : AppTheme.border,
                        width: hasActive ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: hasActive
                                ? AppTheme.primary
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            hasActive
                                ? Icons.receipt_long_rounded
                                : Icons.shopping_bag_outlined,
                            size: 18,
                            color: hasActive
                                ? Colors.white
                                : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      'Your Orders',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (_orders.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${_orders.length}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _error != null
                                    ? 'Unable to load orders · Tap to retry'
                                    : _isLoading && _orders.isEmpty
                                    ? 'Loading orders…'
                                    : hasActive
                                    ? '${activeOrders.length} pending · View your orders'
                                    : (_orders.isEmpty
                                          ? 'No pending orders'
                                          : 'View print history and receipts'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: hasActive
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                  fontWeight: hasActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (hasActive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View Orders',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 20,
                            color: AppTheme.textMuted,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrdersSheetContent extends StatefulWidget {
  final List<PrintOrder> orders;
  final bool isLoading;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<PrintOrder> onResumeOtp;
  final ValueChanged<PrintOrder> onResumePayment;
  final ValueChanged<PrintOrder> onViewInvoice;
  final ValueChanged<PrintOrder> onViewProgress;

  const _OrdersSheetContent({
    required this.orders,
    required this.isLoading,
    this.error,
    required this.onRefresh,
    required this.onResumeOtp,
    required this.onResumePayment,
    required this.onViewInvoice,
    required this.onViewProgress,
  });

  @override
  State<_OrdersSheetContent> createState() => _OrdersSheetContentState();
}

class _OrdersSheetContentState extends State<_OrdersSheetContent> {
  bool _showPending = true;
  List<PrintOrder> get orders =>
      widget.orders.where((order) => order.isPending == _showPending).toList();
  bool get isLoading => widget.isLoading;
  VoidCallback get onRefresh => widget.onRefresh;
  ValueChanged<PrintOrder> get onResumeOtp => widget.onResumeOtp;
  ValueChanged<PrintOrder> get onResumePayment => widget.onResumePayment;
  ValueChanged<PrintOrder> get onViewInvoice => widget.onViewInvoice;

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[dt.month - 1];
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$month ${dt.day}, $hour:$minute $period';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
        maxWidth: 600,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Your Print Orders',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Refresh',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    'Pending (${widget.orders.where((o) => o.isPending).length})',
                  ),
                  selected: _showPending,
                  onSelected: (_) => setState(() => _showPending = true),
                ),
                ChoiceChip(
                  label: Text(
                    'History (${widget.orders.where((o) => !o.isPending).length})',
                  ),
                  selected: !_showPending,
                  onSelected: (_) => setState(() => _showPending = false),
                ),
              ],
            ),
          ),
          if (widget.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                widget.error!,
                style: const TextStyle(color: AppTheme.danger),
              ),
            ),
          // Body
          Expanded(
            child: isLoading && orders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 40,
                            color: AppTheme.textMuted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            _showPending
                                ? 'No pending orders'
                                : 'No order history yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Each order keeps its own payment and print status.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (ctx, idx) {
                      final order = orders[idx];
                      final isWaitingOtp =
                          order.isWaitingOtp ||
                          order.status.toUpperCase() == 'PAID' ||
                          order.status.toUpperCase() == 'JOB_QUEUED';
                      final isUnpaid = order.isPendingPayment;
                      final isCompleted = order.isCompleted;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isWaitingOtp
                              ? const Color(0xFFF8FAFC)
                              : AppTheme.surfaceWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isWaitingOtp
                                ? const Color(0xFFBFDBFE)
                                : AppTheme.border,
                            width: isWaitingOtp ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    order.id,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                _statusBadge(order.status),
                              ],
                            ),
                            if (order.printSettings.items.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                order.printSettings.items
                                    .map((item) => item.filename)
                                    .join(', '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  '${order.totalPages} ${order.totalPages == 1 ? 'page' : 'pages'} · ${order.copies} ${order.copies == 1 ? 'copy' : 'copies'} · ${order.formattedAmount}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  _formatDate(order.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              children: [
                                if (order.releaseCode != null &&
                                    order.releaseCode!.isNotEmpty &&
                                    isWaitingOtp) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFBFDBFE),
                                      ),
                                    ),
                                    child: Text(
                                      'Code: ${order.releaseCode}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primary,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (isWaitingOtp) ...[
                                  FilledButton.icon(
                                    key: ValueKey('release-${order.id}'),
                                    onPressed: () => onResumeOtp(order),
                                    icon: const Icon(
                                      Icons.qr_code_rounded,
                                      size: 14,
                                    ),
                                    label: const Text('Release Code'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ] else if (isUnpaid) ...[
                                  FilledButton.icon(
                                    key: ValueKey('payment-${order.id}'),
                                    onPressed: () => onResumePayment(order),
                                    icon: const Icon(
                                      Icons.payment_rounded,
                                      size: 14,
                                    ),
                                    label: const Text('Complete Payment'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ] else if (order.isPrinting ||
                                    order.status.toUpperCase() ==
                                        'RELEASED') ...[
                                  FilledButton.icon(
                                    key: ValueKey('progress-${order.id}'),
                                    onPressed: () =>
                                        widget.onViewProgress(order),
                                    icon: const Icon(
                                      Icons.print_rounded,
                                      size: 14,
                                    ),
                                    label: const Text('View progress'),
                                  ),
                                ] else if (isCompleted) ...[
                                  OutlinedButton.icon(
                                    onPressed: () => onViewInvoice(order),
                                    icon: const Icon(
                                      Icons.receipt_long_rounded,
                                      size: 14,
                                    ),
                                    label: const Text('Invoice'),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toUpperCase()) {
      case 'WAITING_FOR_OTP':
      case 'PAID':
      case 'JOB_QUEUED':
        bg = const Color(0xFFEFF6FF);
        fg = AppTheme.primary;
        label = 'Ready to Print';
        break;
      case 'WAITING_FOR_PAYMENT':
      case 'CREATED':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        label = 'Awaiting Payment';
        break;
      case 'RELEASED':
      case 'PRINTING':
        bg = const Color(0xFFEFF6FF);
        fg = AppTheme.primary;
        label = status.toUpperCase() == 'PRINTING'
            ? 'Printing'
            : 'Queued for printing';
        break;
      case 'COMPLETED':
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
        label = 'Printed';
        break;
      case 'REFUNDED':
        bg = const Color(0xFFF1F5F9);
        fg = AppTheme.textSecondary;
        label = 'Refunded';
        break;
      case 'CANCELLED':
        bg = const Color(0xFFF1F5F9);
        fg = AppTheme.textSecondary;
        label = 'Cancelled';
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = AppTheme.textSecondary;
        label = status;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
