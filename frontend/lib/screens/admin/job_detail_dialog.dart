import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/admin_api_service.dart';

class JobDetailDialog extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic>? initialData;

  const JobDetailDialog({
    super.key,
    required this.jobId,
    this.initialData,
  });

  @override
  State<JobDetailDialog> createState() => _JobDetailDialogState();
}

class _JobDetailDialogState extends State<JobDetailDialog> {
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _job;

  @override
  void initState() {
    super.initState();
    _job = widget.initialData;
    if (_job == null) {
      _loadJob();
    }
  }

  Future<void> _loadJob() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await AdminApiService.getPrintJobDetail(widget.jobId);
      if (mounted) {
        setState(() {
          _job = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color text;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'COMPLETED':
        bg = AppTheme.successSurface;
        text = AppTheme.success;
        icon = Icons.check_circle_outline;
        break;
      case 'FAILED':
      case 'FINAL_FAILED':
        bg = AppTheme.dangerSurface;
        text = AppTheme.danger;
        icon = Icons.error_outline;
        break;
      case 'CANCELLED':
        bg = AppTheme.warningSurface;
        text = AppTheme.warning;
        icon = Icons.cancel_outlined;
        break;
      case 'PRINTING':
        bg = AppTheme.primarySurface;
        text = AppTheme.primary;
        icon = Icons.sync_rounded;
        break;
      case 'QUEUED':
      default:
        bg = AppTheme.surfaceSubtle;
        text = AppTheme.textSecondary;
        icon = Icons.hourglass_empty_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2),
                    SizedBox(height: 16),
                    Text('Loading print job audit records...'),
                  ],
                ),
              )
            : _errorMessage != null
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
                        const SizedBox(height: 16),
                        Text('Unable to load job details', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadJob, child: const Text('Retry')),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Dialog Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppTheme.border)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.print_outlined, size: 22, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _job?['document_name'] ?? 'Print Job Details',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Job ID: ${_job?['id'] ?? widget.jobId}  •  Order ID: ${_job?['order_id'] ?? '-'}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildStatusChip(_job?['status'] ?? 'QUEUED'),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),

                      // Content Body
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Error Alert (if failed)
                              if ((_job?['status'] == 'FAILED' || _job?['status'] == 'FINAL_FAILED' || _job?['status'] == 'CANCELLED') &&
                                  (_job?['error_message'] != null || _job?['error_code'] != null)) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.dangerBorder),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Failure Diagnostic: ${_job?['error_code'] ?? 'PRINT_ERROR'}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.danger),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _job?['error_message'] ?? 'The printer reported an unrecoverable hardware or queue failure.',
                                              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Section 1: Print & Document Specifications
                              _buildSectionCard(
                                'Document & Printing Specifications',
                                Icons.description_outlined,
                                [
                                  _buildInfoRow('Document Name', _job?['document_name'] ?? '-'),
                                  _buildInfoRow('Total Pages', '${_job?['pages'] ?? 1} pages'),
                                  _buildInfoRow('Copies', '${_job?['copies'] ?? 1}x copies'),
                                  _buildInfoRow('Sheets Dispatched', '${_job?['total_sheets'] ?? 1} sheets'),
                                  _buildInfoRow(
                                    'Color Mode',
                                    _job?['is_color'] == true ? 'Full Color' : 'Monochrome (B&W)',
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _job?['is_color'] == true ? const Color(0xFFFAF5FF) : AppTheme.surfaceSubtle,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _job?['is_color'] == true ? 'COLOR' : 'B&W',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _job?['is_color'] == true ? const Color(0xFF7E22CE) : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  _buildInfoRow('Duplexing', _job?['is_duplex'] == true ? '2-Sided (Duplex)' : '1-Sided (Simplex)'),
                                  if (_job?['mime_type'] != null)
                                    _buildInfoRow('MIME Type', _job?['mime_type']),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Section 2: User Identity & Department
                              _buildSectionCard(
                                'User & Department Details',
                                Icons.person_outline_rounded,
                                [
                                  _buildInfoRow('User Name', _job?['user_name'] ?? 'Customer'),
                                  _buildInfoRow('Email Address', _job?['user_email'] ?? '-'),
                                  _buildInfoRow('Roll / Student ID', _job?['user_roll_number'] ?? '-'),
                                  _buildInfoRow(
                                    'Department',
                                    _job?['department_name'] ?? 'General',
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primarySurface,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _job?['department_name'] ?? 'General',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Section 3: Hardware & CUPS Station
                              _buildSectionCard(
                                'Hardware & Station Parameters',
                                Icons.local_printshop_outlined,
                                [
                                  _buildInfoRow('Printer Station', _job?['printer_name'] ?? 'Local Station'),
                                  _buildInfoRow('CUPS Queue', _job?['cups_printer_name'] ?? 'Default'),
                                  if (_job?['cups_job_id'] != null)
                                    _buildInfoRow('CUPS Job ID', '${_job?['cups_job_id']}'),
                                  _buildInfoRow('Retry Attempts', '${_job?['retry_count'] ?? 0} retries'),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Section 4: Billing & Audit Timestamps
                              _buildSectionCard(
                                'Financials & Lifecycle Timestamps',
                                Icons.receipt_long_outlined,
                                [
                                  _buildInfoRow('Billed Amount', '₹${_job?['amount'] ?? 0} ${_job?['currency'] ?? 'INR'}'),
                                  _buildInfoRow('Submitted At', _job?['created_at'] ?? '-'),
                                  _buildInfoRow('Completed At', _job?['completed_at'] ?? 'Pending / In Progress'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer Actions
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: AppTheme.border)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close Details'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
