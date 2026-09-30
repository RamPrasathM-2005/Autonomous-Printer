import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../constants/app_typography.dart';
import '../../utils/validators.dart';

class PageRangeInput extends StatefulWidget {
  final String initialValue;
  final int totalPages;
  final ValueChanged<String> onChanged;

  const PageRangeInput({
    super.key,
    required this.initialValue,
    required this.totalPages,
    required this.onChanged,
  });

  @override
  State<PageRangeInput> createState() => _PageRangeInputState();
}

class _PageRangeInputState extends State<PageRangeInput> {
  late TextEditingController _controller;
  String? _errorText;
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    _isCustom = widget.initialValue.toLowerCase() != 'all' && widget.initialValue.isNotEmpty;
    _controller = TextEditingController(text: _isCustom ? widget.initialValue : '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleToggle(bool custom) {
    setState(() {
      _isCustom = custom;
      if (!custom) {
        _errorText = null;
        widget.onChanged('all');
      } else {
        _validateAndSubmit(_controller.text);
      }
    });
  }

  void _validateAndSubmit(String value) {
    final err = AppValidators.validatePageRange(value, widget.totalPages);
    setState(() {
      _errorText = err;
    });
    if (err == null && value.trim().isNotEmpty) {
      widget.onChanged(value.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Center(child: Text('All Pages (${widget.totalPages})')),
                selected: !_isCustom,
                onSelected: (_) => _handleToggle(false),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Custom Range')),
                selected: _isCustom,
                onSelected: (_) => _handleToggle(true),
              ),
            ),
          ],
        ),
        if (_isCustom) ...[
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'e.g. 1-5, 8, 11-15',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.format_list_numbered, size: 20),
            ),
            onChanged: _validateAndSubmit,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Specify comma-separated pages or hyphenated ranges up to page ${widget.totalPages}',
            style: AppTypography.labelSmall.copyWith(color: AppColors.outlineLight),
          ),
        ],
      ],
    );
  }
}
