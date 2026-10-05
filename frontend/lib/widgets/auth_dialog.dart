import 'dart:async';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/user_profile.dart';
import '../services/customer_auth_service.dart';

class AuthDialog extends StatefulWidget {
  final bool initialIsSignUp;
  final String? reason;

  const AuthDialog({
    super.key,
    this.initialIsSignUp = false,
    this.reason,
  });

  static Future<UserProfile?> show(
    BuildContext context, {
    bool initialIsSignUp = false,
    String? reason,
  }) {
    return showDialog<UserProfile?>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AuthDialog(
        initialIsSignUp: initialIsSignUp,
        reason: reason,
      ),
    );
  }

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final CustomerAuthService _auth = CustomerAuthService();

  late bool _isSignUp;

  // Controllers
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();

  String _selectedDepartment = 'Computer Science (CSE)';
  static const List<String> _departments = [
    'Computer Science (CSE)',
    'Electronics & Communication (ECE)',
    'Electrical & Electronics (EEE)',
    'Mechanical Engineering (MECH)',
    'Civil Engineering (CIVIL)',
    'Information Technology (IT)',
    'Artificial Intelligence & Data Science (AI&DS)',
    'Management Studies (MBA)',
  ];

  bool _isBusy = false;
  bool _otpSent = false;
  int _otpCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _infoDismissTimer;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _infoDismissTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  void _switchTab(bool isSignUp) {
    if (_isSignUp == isSignUp) return;
    _infoDismissTimer?.cancel();
    _otpController.clear();
    setState(() {
      _isSignUp = isSignUp;
      _error = null;
      _info = null;
      _otpSent = false;
    });
  }

  void _startCooldown() {
    _otpCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_otpCooldown > 1) {
          _otpCooldown--;
        } else {
          _otpCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _error = 'Enter a valid email address';
        _info = null;
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
      _info = null;
    });

    try {
      final purpose = _isSignUp ? 'signup' : 'login';
      await _auth.sendOtp(email, purpose: purpose);
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _otpSent = true;
        _info = 'Verification code sent to $email';
      });
      _startCooldown();

      // Automatically auto-dismiss floating notification after 4 seconds
      _infoDismissTimer?.cancel();
      _infoDismissTimer = Timer(const Duration(milliseconds: 4000), () {
        if (mounted) {
          setState(() => _info = null);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('ApiError: ', '');
        _info = null;
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpController.text.trim();

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit verification code');
      return;
    }

    setState(() {
      _isBusy = true;
      _error = null;
    });

    try {
      UserProfile user;
      if (_isSignUp) {
        final name = _nameController.text.trim();
        final roll = _rollController.text.trim();
        if (name.isEmpty) {
          setState(() {
            _error = 'Enter your full name';
            _isBusy = false;
          });
          return;
        }
        if (roll.isEmpty) {
          setState(() {
            _error = 'Enter your roll number';
            _isBusy = false;
          });
          return;
        }

        user = await _auth.studentSignup(
          fullName: name,
          rollNumber: roll,
          email: email,
          department: _selectedDepartment,
          otp: otp,
        );
      } else {
        user = await _auth.studentLogin(email: email, otp: otp);
      }

      if (!mounted) return;
      Navigator.of(context).pop(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('ApiError: ', ''));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  InputDecoration _googleStyleInputDecoration({
    required String label,
    Widget? prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppTheme.textSecondary,
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A56DB),
      ),
      prefixIcon: prefixIcon,
      suffix: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.danger, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header branding
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/achuppori-logo.png',
                          width: 42,
                          height: 42,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.print_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.asset(
                                'assets/images/achuppori-wordmark.png',
                                height: 26,
                                fit: BoxFit.contain,
                                alignment: Alignment.centerLeft,
                                semanticLabel: 'Achuppori',
                                errorBuilder: (context, error, stackTrace) => const Text(
                                  'Achuppori',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Campus Self-Service Printing',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          visualDensity: VisualDensity.compact,
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  const Divider(height: 1, color: AppTheme.border),


                  // Tabs: Sign in & Sign up in the same row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Slate 100
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchTab(false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: !_isSignUp ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: !_isSignUp ? const Color(0xFF93C5FD) : Colors.transparent,
                                    width: 1.2,
                                  ),
                                  boxShadow: !_isSignUp
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Sign in',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !_isSignUp ? FontWeight.w600 : FontWeight.w500,
                                    color: !_isSignUp ? const Color(0xFF1D4ED8) : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchTab(true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                decoration: BoxDecoration(
                                  color: _isSignUp ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: _isSignUp ? const Color(0xFF93C5FD) : Colors.transparent,
                                    width: 1.2,
                                  ),
                                  boxShadow: _isSignUp
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Sign up',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _isSignUp ? FontWeight.w600 : FontWeight.w500,
                                    color: _isSignUp ? const Color(0xFF1D4ED8) : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Form content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Error message
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerSurface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.dangerBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.danger, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Floating transient info notification (auto-dismisses in 3.5s)
                        if (_info != null) ...[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFBBF7D0)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _info!,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF15803D), fontWeight: FontWeight.w500),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _infoDismissTimer?.cancel();
                                    setState(() => _info = null);
                                  },
                                  child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF15803D)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Registration fields
                        if (_isSignUp) ...[
                          TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _googleStyleInputDecoration(
                              label: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _rollController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _googleStyleInputDecoration(
                              label: 'Roll Number',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDepartment,
                            decoration: _googleStyleInputDecoration(
                              label: 'Department',
                              prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                            ),
                            items: _departments.map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text(
                                  dept,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedDepartment = val);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Email Address with prominent Get OTP button
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: _googleStyleInputDecoration(
                            label: 'Email address',
                            prefixIcon: const Icon(Icons.email_outlined, size: 20),
                            suffix: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: OutlinedButton(
                                onPressed: (_isBusy || _otpCooldown > 0) ? null : _handleSendOtp,
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEFF6FF),
                                  foregroundColor: const Color(0xFF1D4ED8),
                                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  _otpCooldown > 0
                                      ? '${_otpCooldown}s'
                                      : (_otpSent ? 'Resend' : 'Get OTP'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // OTP Code
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          decoration: _googleStyleInputDecoration(
                            label: 'Verification code (OTP)',
                            prefixIcon: const Icon(Icons.pin_outlined, size: 20),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Button
                        SizedBox(
                          height: 46,
                          child: FilledButton(
                            onPressed: _isBusy ? null : _handleSubmit,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isBusy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _isSignUp ? 'Create account' : 'Sign in',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 16),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
