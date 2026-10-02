import 'app_scaffold.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

class HelpAction extends StatelessWidget {
  const HelpAction({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: TextButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
      ),
      icon: const Icon(Icons.help_outline_rounded, size: 18),
      label: const Text('Help'),
      style: TextButton.styleFrom(foregroundColor: AppTheme.textPrimary),
    ),
  );
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(title: const Text('Help')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Printing help',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.upload_file_outlined),
                      title: Text('Upload files'),
                      subtitle: Text('Choose PDF, JPG, or PNG files.'),
                    ),
                    ListTile(
                      leading: Icon(Icons.tune_rounded),
                      title: Text('Review print settings'),
                      subtitle: Text(
                        'Check copies, colour, and page ranges for each file.',
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.receipt_long_outlined),
                      title: Text('Review and pay'),
                      subtitle: Text(
                        'Confirm your files and total before payment.',
                      ),
                    ),
                    ListTile(
                      leading: Icon(Icons.print_outlined),
                      title: Text('Collect your prints'),
                      subtitle: Text(
                        'Use your release code at the print station.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Need assistance?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Contact the print station staff for help with an order or printer.',
              ),
              const SizedBox(height: 16),
              const ExpansionTile(
                title: Text('Unable to connect'),
                children: [
                  ListTile(
                    title: Text(
                      'Check your network and the server address under Local.',
                    ),
                  ),
                ],
              ),
              const ExpansionTile(
                title: Text('Payment not confirmed'),
                children: [
                  ListTile(
                    title: Text(
                      'Use Check payment status on your order before paying again.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
