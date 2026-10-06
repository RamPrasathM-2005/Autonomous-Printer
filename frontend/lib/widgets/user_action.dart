import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/order.dart';
import '../models/user_profile.dart';
import '../services/customer_auth_service.dart';
import '../screens/otp_release_screen.dart';
import '../screens/payment_screen.dart';
import 'invoice_preview_dialog.dart';
import 'auth_dialog.dart';

class UserAction extends StatelessWidget {
  const UserAction({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = CustomerAuthService();
    return ValueListenableBuilder<UserProfile?>(
      valueListenable: auth.userNotifier,
      builder: (context, user, _) {
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Account',
              child: IconButton(
                onPressed: () => AuthDialog.show(context),
                icon: const Icon(
                  Icons.person_outline_rounded,
                  size: 20,
                  color: AppTheme.textPrimary,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: user.displayName,
            child: InkWell(
              onTap: () => _showProfileDialog(context, user),
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context, UserProfile user) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _UserProfileModal(user: user),
    );
  }
}

class _UserProfileModal extends StatefulWidget {
  final UserProfile user;

  const _UserProfileModal({required this.user});

  @override
  State<_UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<_UserProfileModal> {
  final CustomerAuthService _auth = CustomerAuthService();
  bool _isEditing = false;
  bool _isBusy = false;
  String? _error;

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late String _department;
  List<Map<String, dynamic>> _dbDepartments = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName ?? '');
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _department = widget.user.department ?? '';
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await _auth.getDepartments();
      if (!mounted) return;
      setState(() {
        _dbDepartments = depts;
        if (_department.isEmpty && _dbDepartments.isNotEmpty) {
          _department = _dbDepartments.first['name'] as String? ?? '';
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      await _auth.updateProfile(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        department: _department,
      );
      if (!mounted) return;
      setState(() => _isEditing = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('ApiError: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showOrderHistory() {
    Navigator.of(context).pop();
    showDialog<void>(
      context: context,
      builder: (ctx) => const _OrderHistoryDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser ?? widget.user;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Account Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.border),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.dangerBorder),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(fontSize: 12, color: AppTheme.danger),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (!_isEditing) ...[
                      // View Mode
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.primary,
                            child: Text(
                              user.initials,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (user.rollNumber != null && user.rollNumber!.isNotEmpty)
                                  Text(
                                    'Roll No: ${user.rollNumber}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      _detailRow(Icons.email_outlined, 'Email', user.email ?? 'Not provided'),
                      const SizedBox(height: 10),
                      _detailRow(
                        Icons.account_balance_outlined,
                        'Department',
                        user.department ?? 'Not selected',
                      ),
                      const SizedBox(height: 20),

                      // Order history button
                      OutlinedButton.icon(
                        onPressed: _showOrderHistory,
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('My Print Orders'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Edit and Logout buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit Details'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                await _auth.logout();
                                nav.pop();
                              },
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('Sign out'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF1F5F9),
                                foregroundColor: AppTheme.danger,
                                minimumSize: const Size(0, 42),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Edit Mode
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          prefixIcon: Icon(Icons.email_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _dbDepartments.any((d) => d['name'] == _department)
                            ? _department
                            : (_dbDepartments.isNotEmpty ? _dbDepartments.first['name'] as String? : null),
                        decoration: const InputDecoration(
                          labelText: 'Department',
                          prefixIcon: Icon(Icons.account_balance_outlined, size: 18),
                        ),
                        items: _dbDepartments.map((dept) {
                          final name = dept['name'] as String? ?? '';
                          final code = dept['code'] as String? ?? '';
                          final label = code.isNotEmpty ? '$name ($code)' : name;
                          return DropdownMenuItem(
                            value: name,
                            child: Text(label, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _department = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isBusy ? null : () => setState(() => _isEditing = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isBusy ? null : _handleSave,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                              ),
                              child: _isBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _OrderHistoryDialog extends StatefulWidget {
  const _OrderHistoryDialog();

  @override
  State<_OrderHistoryDialog> createState() => _OrderHistoryDialogState();
}

class _OrderHistoryDialogState extends State<_OrderHistoryDialog> {
  final CustomerAuthService _auth = CustomerAuthService();
  bool _isLoading = true;
  String? _error;
  List<PrintOrder> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _auth.fetchMyOrders();
      if (!mounted) return;
      setState(() => _orders = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('ApiError: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Print Order History',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.border),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _orders.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text(
                                    'No past print orders found.',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _orders.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (ctx, idx) {
                                  final order = _orders[idx];
                                  final isWaitingOtp = order.isWaitingOtp || order.status.toUpperCase() == 'PAID' || order.status.toUpperCase() == 'JOB_QUEUED';
                                  final isUnpaid = order.status.toUpperCase() == 'CREATED';
                                  final isCompleted = order.isCompleted;

                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isWaitingOtp ? const Color(0xFFF8FAFC) : AppTheme.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isWaitingOtp ? const Color(0xFFBFDBFE) : AppTheme.border,
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
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _statusBg(order.status),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                order.statusLabel,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: _statusColor(order.status),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${order.totalPages} pages · ${order.copies} copy · ${order.formattedAmount}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (order.releaseCode != null && order.releaseCode!.isNotEmpty && isWaitingOtp) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(5),
                                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                                ),
                                                child: Text(
                                                  'Code: ${order.releaseCode}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.primary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            const Spacer(),
                                            if (isWaitingOtp) ...[
                                              FilledButton.icon(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => OtpReleaseScreen(orderId: order.id, order: order),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(Icons.qr_code_rounded, size: 13),
                                                label: const Text('Release Code'),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: AppTheme.primary,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ] else if (isUnpaid) ...[
                                              FilledButton.icon(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => PaymentScreen(order: order),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(Icons.payment_rounded, size: 13),
                                                label: const Text('Pay'),
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: AppTheme.primary,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ] else if (isCompleted) ...[
                                              OutlinedButton.icon(
                                                onPressed: () => InvoicePreviewDialog.show(context, order: order),
                                                icon: const Icon(Icons.receipt_long_rounded, size: 13),
                                                label: const Text('Invoice'),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
        ),
      ),
    );
  }

  Color _statusBg(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppTheme.successSurface;
      case 'CANCELLED':
      case 'REFUNDED':
        return const Color(0xFFF1F5F9);
      case 'WAITING_FOR_OTP':
      case 'PAID':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return AppTheme.success;
      case 'CANCELLED':
      case 'REFUNDED':
        return AppTheme.textSecondary;
      case 'WAITING_FOR_OTP':
      case 'PAID':
        return AppTheme.primary;
      default:
        return AppTheme.warning;
    }
  }
}
