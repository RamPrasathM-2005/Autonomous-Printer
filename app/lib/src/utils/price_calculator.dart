import '../constants/api_constants.dart';
import '../models/print_configuration_model.dart';
import 'validators.dart';

class PricingItemInput {
  final int pages;
  final PrintConfigurationModel config;

  const PricingItemInput({
    required this.pages,
    required this.config,
  });
}

class PricingBreakdown {
  final double subtotal;
  final double serviceFee;
  final double gstTax;
  final double grandTotal;
  final int totalSheets;
  final int totalPrintPages;

  const PricingBreakdown({
    required this.subtotal,
    required this.serviceFee,
    required this.gstTax,
    required this.grandTotal,
    required this.totalSheets,
    required this.totalPrintPages,
  });
}

class PriceCalculator {
  /// Calculates cost for an individual document with given configuration.
  static double calculateItemCost({
    required int totalDocumentPages,
    required PrintConfigurationModel config,
  }) {
    final effectivePages = AppValidators.resolvePageCount(config.pageRange, totalDocumentPages);
    final isColor = config.colorMode == ColorMode.color;
    final isDuplex = config.duplexMode == DuplexMode.doubleSided;

    double costPerPage;
    if (isColor) {
      costPerPage = isDuplex ? (ApiConstants.colorDuplexPrice / 2.0) : ApiConstants.colorSinglePrice;
    } else {
      costPerPage = isDuplex ? (ApiConstants.bwDuplexPrice / 2.0) : ApiConstants.bwSinglePrice;
    }

    final documentCost = effectivePages * costPerPage * config.copies;
    return double.parse(documentCost.toStringAsFixed(2));
  }

  /// Calculates order breakdown across all documents.
  static PricingBreakdown calculateOrderBreakdown(List<PricingItemInput> items) {
    if (items.isEmpty) {
      return const PricingBreakdown(
        subtotal: 0.0,
        serviceFee: 0.0,
        gstTax: 0.0,
        grandTotal: 0.0,
        totalSheets: 0,
        totalPrintPages: 0,
      );
    }

    double subtotal = 0.0;
    int totalPrintPages = 0;
    int totalSheets = 0;

    for (final item in items) {
      final docPages = AppValidators.resolvePageCount(item.config.pageRange, item.pages);
      final itemCost = calculateItemCost(
        totalDocumentPages: item.pages,
        config: item.config,
      );
      subtotal += itemCost;

      final printed = docPages * item.config.copies;
      totalPrintPages += printed;

      if (item.config.duplexMode == DuplexMode.doubleSided) {
        totalSheets += (printed / 2.0).ceil();
      } else {
        totalSheets += printed;
      }
    }

    const serviceFee = ApiConstants.serviceFee;
    final taxable = subtotal + serviceFee;
    final gstTax = double.parse((taxable * ApiConstants.gstRate).toStringAsFixed(2));
    final grandTotal = double.parse((taxable + gstTax).toStringAsFixed(2));

    return PricingBreakdown(
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      serviceFee: serviceFee,
      gstTax: gstTax,
      grandTotal: grandTotal,
      totalSheets: totalSheets,
      totalPrintPages: totalPrintPages,
    );
  }
}
