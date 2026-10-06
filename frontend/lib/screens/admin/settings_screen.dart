import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';
import 'admin_shell.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _successMessage;

  // Controllers
  final _rateCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _uploadMbCtrl = TextEditingController();
  final _otpTtlCtrl = TextEditingController();
  final _otpAttemptsCtrl = TextEditingController();
  final _printRetriesCtrl = TextEditingController();
  final _heartbeatTimeoutCtrl = TextEditingController();

  Map<String, dynamic>? _settingsData;
  Map<String, dynamic>? _dbStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _feeCtrl.dispose();
    _uploadMbCtrl.dispose();
    _otpTtlCtrl.dispose();
    _otpAttemptsCtrl.dispose();
    _printRetriesCtrl.dispose();
    _heartbeatTimeoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final data = await AdminApiService.getSettings();
      Map<String, dynamic>? dbStatus;
      try {
        dbStatus = await AdminApiService.getDatabaseStatus();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _settingsData = data;
          _dbStatus = dbStatus;
          _rateCtrl.text = (data['per_page_rate'] ?? 2.0).toString();
          _feeCtrl.text = (data['base_fee'] ?? 0.0).toString();
          _uploadMbCtrl.text = (data['max_upload_mb'] ?? 50).toString();
          _otpTtlCtrl.text = (data['otp_ttl_minutes'] ?? 1440).toString();
          _otpAttemptsCtrl.text = (data['max_otp_attempts'] ?? 5).toString();
          _printRetriesCtrl.text = (data['max_print_retries'] ?? 2).toString();
          _heartbeatTimeoutCtrl.text = (data['heartbeat_timeout_seconds'] ?? 45).toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final rate = double.tryParse(_rateCtrl.text.trim());
      final fee = double.tryParse(_feeCtrl.text.trim());
      final uploadMb = int.tryParse(_uploadMbCtrl.text.trim());
      final otpTtl = int.tryParse(_otpTtlCtrl.text.trim());
      final otpAttempts = int.tryParse(_otpAttemptsCtrl.text.trim());
      final retries = int.tryParse(_printRetriesCtrl.text.trim());
      final hbTimeout = int.tryParse(_heartbeatTimeoutCtrl.text.trim());

      if (rate == null || rate < 0) throw Exception('Please enter a valid per-page rate.');
      if (fee == null || fee < 0) throw Exception('Please enter a valid base fee.');
      if (uploadMb == null || uploadMb <= 0) throw Exception('Max upload MB must be greater than zero.');
      if (otpTtl == null || otpTtl <= 0) throw Exception('OTP TTL must be greater than zero.');
      if (otpAttempts == null || otpAttempts <= 0) throw Exception('Max OTP attempts must be greater than zero.');
      if (retries == null || retries < 0) throw Exception('Print retries cannot be negative.');
      if (hbTimeout == null || hbTimeout < 5) throw Exception('Heartbeat timeout must be at least 5 seconds.');

      final updated = await AdminApiService.updateSettings({
        'per_page_rate': rate,
        'base_fee': fee,
        'max_upload_mb': uploadMb,
        'otp_ttl_minutes': otpTtl,
        'max_otp_attempts': otpAttempts,
        'max_print_retries': retries,
        'heartbeat_timeout_seconds': hbTimeout,
      });

      if (mounted) {
        setState(() {
          _settingsData = updated;
          _isSaving = false;
          _successMessage = 'System settings updated and applied successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentSection: AdminNavSection.settings,
      title: 'Platform Settings',
      onRefresh: _loadSettings,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_successMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_successMessage!,
                            style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

              // Card 1: Print Pricing Configuration
              _buildSectionCard(
                icon: Icons.payments_outlined,
                title: 'Print Pricing Rules',
                description: 'Set default page rates and service fees applied to user print orders.',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Standard Page Rate (₹)',
                            hintText: '2.00',
                            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _feeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Base Convenience Fee (₹)',
                            hintText: '0.00',
                            prefixIcon: const Icon(Icons.receipt_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card 2: Document & Storage Rules
              _buildSectionCard(
                icon: Icons.cloud_upload_outlined,
                title: 'Upload & Storage Limitations',
                description: 'Configure maximum permissible document file sizes allowed on the kiosk.',
                children: [
                  TextField(
                    controller: _uploadMbCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Maximum Upload Size (MB)',
                      hintText: '50',
                      prefixIcon: const Icon(Icons.file_present_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card 3: Security & OTP Lifecycles
              _buildSectionCard(
                icon: Icons.lock_clock_outlined,
                title: 'Security & Verification Timers',
                description: 'Manage expiration windows for pickup codes and OTP validation attempts.',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _otpTtlCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Pickup Code Validity (Minutes)',
                            hintText: '1440',
                            prefixIcon: const Icon(Icons.timer_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _otpAttemptsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max Verification Attempts',
                            hintText: '5',
                            prefixIcon: const Icon(Icons.security, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _printRetriesCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Max Automated Print Retries',
                            hintText: '2',
                            prefixIcon: const Icon(Icons.replay_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _heartbeatTimeoutCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Station Heartbeat Timeout (Seconds)',
                            hintText: '45',
                            prefixIcon: const Icon(Icons.wifi_tethering_outlined, size: 18),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Card 4: Administrator Profile & Mailer Status
              if (_settingsData != null)
                _buildSectionCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Administrator Identity & Mailer',
                  description: 'Active platform credentials and student mailer status.',
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow('Active Administrator Email', _settingsData!['current_admin_email'] ?? 'admin@printplatform.local'),
                          const Divider(height: 16),
                          _buildDetailRow('Email OTP Provider', '${_settingsData!['email_provider']} (${_settingsData!['smtp_host']})'),
                          const Divider(height: 16),
                          _buildDetailRow('Sender Address', _settingsData!['smtp_user'] ?? 'achupporihelpdesk@gmail.com'),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),

              // Card 5: Production Database Health & Schema Status
              if (_dbStatus != null)
                _buildSectionCard(
                  icon: Icons.storage_rounded,
                  title: 'Production Database Health & Telemetry',
                  description: 'Live MySQL connection parameters and database storage metrics.',
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Connection Status', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Text('${_dbStatus!['status']} (${_dbStatus!['latency_ms']} ms)',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),
                          _buildDetailRow('Database Target', _dbStatus!['database_url_masked'] ?? '127.0.0.1:3306/printer'),
                          const Divider(height: 18),
                          _buildDetailRow('Runtime Environment', (_dbStatus!['environment'] ?? 'production').toString().toUpperCase()),
                          const Divider(height: 18),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceAround,
                            children: [
                              _buildStatBadge('Departments', '${_dbStatus!['total_departments']}'),
                              _buildStatBadge('Users', '${_dbStatus!['total_users']}'),
                              _buildStatBadge('Printers', '${_dbStatus!['total_printers']}'),
                              _buildStatBadge('Print Jobs', '${_dbStatus!['total_print_jobs']}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 28),

              // Save Button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 20),
                  label: Text(_isSaving ? 'Applying Settings...' : 'Save Configuration',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(description, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildStatBadge(String label, String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(count, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
