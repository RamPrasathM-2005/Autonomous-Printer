import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A quiet mark above the document upload form.
class PrintIllustration extends StatelessWidget {
  const PrintIllustration({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: SizedBox(
      height: 80,
      width: 80,
      child: Icon(Icons.print_outlined, size: 52, color: AppTheme.primary),
    ),
  );
}
