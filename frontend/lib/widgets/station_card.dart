import 'package:flutter/material.dart';
import '../models/print_server.dart';
import '../config/theme.dart';
import 'status_badge.dart';

class StationCard extends StatelessWidget {
  final PrintServer server;
  final bool isSelected;
  final VoidCallback onSelect;

  const StationCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryLight : Colors.white.withOpacity(0.08),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (isSelected ? AppTheme.primary : AppTheme.surfaceLight).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      color: isSelected ? AppTheme.primaryLight : Colors.white70,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                server.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            StatusBadge(status: server.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: Colors.white54),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                server.location,
                                style: const TextStyle(fontSize: 13, color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _statusItem(
                        icon: Icons.speed,
                        label: 'Printer: ${server.printerState}',
                        isOk: server.printerState.toUpperCase() == 'IDLE',
                      ),
                      const SizedBox(width: 12),
                      _statusItem(
                        icon: Icons.layers_outlined,
                        label: 'Paper: ${server.paperState}',
                        isOk: server.paperState.toUpperCase() == 'NORMAL',
                      ),
                    ],
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primaryLight),
                          SizedBox(width: 4),
                          Text(
                            'Selected',
                            style: TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusItem({required IconData icon, required String label, required bool isOk}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isOk ? AppTheme.success : AppTheme.warning,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isOk ? Colors.white70 : AppTheme.warning,
          ),
        ),
      ],
    );
  }
}
