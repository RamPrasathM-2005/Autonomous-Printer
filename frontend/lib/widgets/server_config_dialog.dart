import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

Future<bool?> showServerConfigModal(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => const ServerConfigDialog(),
  );
}

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late final TextEditingController _controller;
  String? _detectedTunnelUrl;
  bool _detectingTunnel = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ApiConfig.backendUrl);
    _detectTunnel();
  }

  Future<void> _detectTunnel() async {
    setState(() => _detectingTunnel = true);
    final tunnel = await ApiService().fetchActiveTunnelUrl();
    if (mounted) {
      setState(() {
        _detectingTunnel = false;
        _detectedTunnelUrl = tunnel;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPresetChip(String label, String url, {bool isTunnel = false}) {
    final isSelected = _controller.text.trim() == url;
    return InkWell(
      onTap: () {
        setState(() {
          _controller.text = url;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isTunnel ? const Color(0xFFEFF6FF) : AppTheme.primarySurface)
              : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isTunnel ? const Color(0xFF2563EB) : AppTheme.primary)
                : (isTunnel ? const Color(0xFF93C5FD) : AppTheme.border),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTunnel) ...[
              const Icon(Icons.cloud_done_rounded, size: 13, color: Color(0xFF2563EB)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected
                    ? (isTunnel ? const Color(0xFF2563EB) : AppTheme.primary)
                    : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.dns_rounded, color: AppTheme.primary, size: 22),
          SizedBox(width: 8),
          Text(
            'Server Configuration',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter backend API tunnel or server URL for quick remote/tunnel deployment:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'https://xxxx.trycloudflare.com',
                labelText: 'Backend Server URL',
                labelStyle: const TextStyle(fontSize: 12),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _controller.clear();
                    setState(() {});
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
                        setState(() {
                          _controller.text = data.text!.trim();
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pasted: ${data.text!.trim()}'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text(
                      'Paste from Clipboard',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _detectingTunnel ? null : _detectTunnel,
                  icon: _detectingTunnel
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: 'Scan for active Cloudflare tunnel',
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_detectedTunnelUrl != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded, color: Color(0xFF16A34A), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Cloudflare Quick Tunnel Found',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF166534)),
                          ),
                          Text(
                            _detectedTunnelUrl!,
                            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF15803D)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _controller.text = _detectedTunnelUrl!;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF16A34A),
                      ),
                      child: const Text('Use', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Cloudflare Quick Tunnel: Run ./start_tunnel.sh on the PC, copy the generated https://xxxx.trycloudflare.com URL, and paste it here.',
                      style: TextStyle(fontSize: 11, color: AppTheme.primary, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Quick Presets:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (_detectedTunnelUrl != null)
                  _buildPresetChip('Cloudflare Tunnel (Live)', _detectedTunnelUrl!, isTunnel: true),
                _buildPresetChip('USB Cable (127.0.0.1)', 'http://127.0.0.1:8000'),
                _buildPresetChip('PC Wi-Fi (10.11.14.85)', 'http://10.11.14.85:8000'),
                _buildPresetChip('PC LAN (172.17.3.5)', 'http://172.17.3.5:8000'),
                _buildPresetChip('Android Emulator (10.0.2.2)', 'http://10.0.2.2:8000'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newUrl = _controller.text.trim();
            if (newUrl.isNotEmpty) {
              await ApiConfig.updateBackendUrl(newUrl);
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Save & Connect', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
