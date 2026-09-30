class AppValidators {
  /// Validates a custom page range string like "1-5, 8, 11-15" against total document pages.
  static String? validatePageRange(String? input, int totalPages) {
    if (input == null || input.trim().isEmpty || input.trim().toLowerCase() == 'all') {
      return null;
    }

    final trimmed = input.trim();
    final parts = trimmed.split(',');

    for (final part in parts) {
      final item = part.trim();
      if (item.isEmpty) return 'Invalid range format. Remove trailing commas.';

      if (item.contains('-')) {
        final subParts = item.split('-');
        if (subParts.length != 2) return 'Invalid range syntax: $item';
        final start = int.tryParse(subParts[0].trim());
        final end = int.tryParse(subParts[1].trim());

        if (start == null || end == null) return 'Page numbers must be integers: $item';
        if (start < 1) return 'Starting page must be >= 1';
        if (end < start) return 'End page must be >= start page ($item)';
        if (end > totalPages) return 'End page $end exceeds document total ($totalPages)';
      } else {
        final single = int.tryParse(item);
        if (single == null) return 'Invalid page number: $item';
        if (single < 1) return 'Page number must be >= 1';
        if (single > totalPages) return 'Page $single exceeds total pages ($totalPages)';
      }
    }

    return null;
  }

  /// Calculates actual page count according to page range string.
  static int resolvePageCount(String pageRange, int totalDocumentPages) {
    if (pageRange.trim().isEmpty || pageRange.trim().toLowerCase() == 'all') {
      return totalDocumentPages;
    }

    final parts = pageRange.split(',');
    final Set<int> includedPages = {};

    for (final part in parts) {
      final item = part.trim();
      if (item.isEmpty) continue;

      if (item.contains('-')) {
        final subParts = item.split('-');
        if (subParts.length == 2) {
          final start = int.tryParse(subParts[0].trim()) ?? 1;
          final end = int.tryParse(subParts[1].trim()) ?? totalDocumentPages;
          for (int i = start; i <= end && i <= totalDocumentPages; i++) {
            if (i >= 1) includedPages.add(i);
          }
        }
      } else {
        final single = int.tryParse(item);
        if (single != null && single >= 1 && single <= totalDocumentPages) {
          includedPages.add(single);
        }
      }
    }

    return includedPages.isEmpty ? totalDocumentPages : includedPages.length;
  }
}
