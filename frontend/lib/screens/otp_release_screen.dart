import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/order.dart';
import '../services/api_service.dart';
import '../widgets/otp_display.dart';
import '../widgets/status_badge.dart';
import 'station_terminal_screen.dart';

class OtpReleaseScreen extends StatefulWidget {
  final String orderId;

  const OtpReleaseScreen({super.key, required this.orderId});

  @override
  State<OtpReleaseScreen> createState() => _OtpReleaseScreenState();
}

class _OtpReleaseScreenState extends State<OtpReleaseScreen> {
  final ApiService _apiService = ApiService();
  OrderOtp? _otpData;
  PrintOrder? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchOtpAndOrder();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _pollOrderStatus();
    });
  }

  Future<void> _fetchOtpAndOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _apiService.getOrder(widget.orderId);
      OrderOtp? otp;
      if (order.status.toUpperCase() == 'WAITING_FOR_OTP') {
        otp = await _apiService.getOrderOtp(widget.orderId);
      }

      setState(() {
        _order = order;
        _otpData = otp;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _pollOrderStatus() async {
    try {
      final order = await _apiService.getOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
        });
      }
      if (order.status.toUpperCase() == 'COMPLETED' || order.status.toUpperCase() == 'FAILED') {
        _pollingTimer?.cancel();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Release OTP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchOtpAndOrder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ORDER STATUS',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white54),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.orderId,
                              style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white),
                            ),
                          ],
                        ),
                        if (_order != null) StatusBadge(status: _order!.status, fontSize: 13),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // OTP Display Card
                  if (_otpData != null)
                    OtpDisplayCard(
                      otp: _otpData!.otp,
                      expiresAt: _otpData!.expiresAt,
                    )
                  else if (_order != null && _order!.status.toUpperCase() == 'COMPLETED')
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.success.withOpacity(0.4)),
                      ),
                      child: Column(
                        children: const [
                          Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 54),
                          SizedBox(height: 12),
                          Text(
                            'Print Completed!',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Your document has been printed successfully. Please collect your papers from the tray.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _errorMessage ?? 'Waiting for print job processing...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // How to release steps
                  const Text(
                    'How to Collect Your Print',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  _stepItem(
                    number: '1',
                    title: 'Go to Station',
                    desc: 'Walk up to printing station ${_order?.printServerId ?? ""}.',
                  ),
                  _stepItem(
                    number: '2',
                    title: 'Enter 6-Digit OTP',
                    desc: 'Type this OTP code into the kiosk touchscreen keypad.',
                  ),
                  _stepItem(
                    number: '3',
                    title: 'Pick Up Paper',
                    desc: 'The CUPS printer automatically releases and prints your job.',
                  ),

                  const SizedBox(height: 24),

                  // Simulator action button
                  if (_otpData != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => StationTerminalScreen(initialOtp: _otpData!.otp),
                          ),
                        );
                      },
                      icon: const Icon(Icons.touch_app_rounded, color: AppTheme.secondary),
                      label: const Text(
                        'Test Release in Station Kiosk Simulator',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.secondary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _stepItem({required String number, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primaryLight),
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight, fontSize: 13),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
