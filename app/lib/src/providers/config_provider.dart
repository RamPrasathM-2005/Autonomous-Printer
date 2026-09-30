import 'package:flutter/material.dart';
import '../models/print_configuration_model.dart';
import '../models/document_model.dart';
import '../utils/price_calculator.dart';

class ConfigProvider with ChangeNotifier {
  final Map<String, PrintConfigurationModel> _configurations = {};

  Map<String, PrintConfigurationModel> get configurations => Map.unmodifiable(_configurations);

  PrintConfigurationModel getConfiguration(String documentId, {int defaultPages = 1}) {
    if (_configurations.containsKey(documentId)) {
      return _configurations[documentId]!;
    }
    // Return default configuration
    final defaultConfig = PrintConfigurationModel(
      documentId: documentId,
      colorMode: ColorMode.blackAndWhite,
      duplexMode: DuplexMode.singleSided,
      pageRange: 'all',
      orientation: PrintOrientation.portrait,
      copies: 1,
      paperSize: PaperSize.a4,
      estimatedCost: PriceCalculator.calculateItemCost(
        totalDocumentPages: defaultPages,
        config: PrintConfigurationModel(documentId: documentId),
      ),
    );
    _configurations[documentId] = defaultConfig;
    return defaultConfig;
  }

  void updateConfiguration(String documentId, PrintConfigurationModel newConfig, int totalDocumentPages) {
    final cost = PriceCalculator.calculateItemCost(
      totalDocumentPages: totalDocumentPages,
      config: newConfig,
    );
    _configurations[documentId] = newConfig.copyWith(estimatedCost: cost);
    notifyListeners();
  }

  void applyToAll(PrintConfigurationModel baseConfig, List<DocumentModel> documents) {
    for (final doc in documents) {
      final config = baseConfig.copyWith(
        documentId: doc.id,
        estimatedCost: PriceCalculator.calculateItemCost(
          totalDocumentPages: doc.pageCount,
          config: baseConfig.copyWith(documentId: doc.id),
        ),
      );
      _configurations[doc.id] = config;
    }
    notifyListeners();
  }

  void removeConfiguration(String documentId) {
    _configurations.remove(documentId);
    notifyListeners();
  }

  void reset() {
    _configurations.clear();
    notifyListeners();
  }
}
