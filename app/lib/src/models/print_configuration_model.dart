enum ColorMode { blackAndWhite, color }
enum DuplexMode { singleSided, doubleSided }
enum PrintOrientation { portrait, landscape }
enum PaperSize { a4, a3, letter }

class PrintConfigurationModel {
  final String documentId;
  final ColorMode colorMode;
  final DuplexMode duplexMode;
  final String pageRange; // e.g., 'all' or '1-5, 8'
  final PrintOrientation orientation;
  final int copies;
  final PaperSize paperSize;
  final double estimatedCost;

  const PrintConfigurationModel({
    required this.documentId,
    this.colorMode = ColorMode.blackAndWhite,
    this.duplexMode = DuplexMode.singleSided,
    this.pageRange = 'all',
    this.orientation = PrintOrientation.portrait,
    this.copies = 1,
    this.paperSize = PaperSize.a4,
    this.estimatedCost = 0.0,
  });

  PrintConfigurationModel copyWith({
    String? documentId,
    ColorMode? colorMode,
    DuplexMode? duplexMode,
    String? pageRange,
    PrintOrientation? orientation,
    int? copies,
    PaperSize? paperSize,
    double? estimatedCost,
  }) {
    return PrintConfigurationModel(
      documentId: documentId ?? this.documentId,
      colorMode: colorMode ?? this.colorMode,
      duplexMode: duplexMode ?? this.duplexMode,
      pageRange: pageRange ?? this.pageRange,
      orientation: orientation ?? this.orientation,
      copies: copies ?? this.copies,
      paperSize: paperSize ?? this.paperSize,
      estimatedCost: estimatedCost ?? this.estimatedCost,
    );
  }

  factory PrintConfigurationModel.fromJson(Map<String, dynamic> json) {
    return PrintConfigurationModel(
      documentId: json['documentId'] ?? '',
      colorMode: (json['colorMode'] == 'color') ? ColorMode.color : ColorMode.blackAndWhite,
      duplexMode: (json['duplexMode'] == 'duplex' || json['duplexMode'] == 'doubleSided')
          ? DuplexMode.doubleSided
          : DuplexMode.singleSided,
      pageRange: json['pageRange'] ?? 'all',
      orientation: (json['orientation'] == 'landscape')
          ? PrintOrientation.landscape
          : PrintOrientation.portrait,
      copies: json['copies'] ?? 1,
      paperSize: PaperSize.a4,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'documentId': documentId,
      'colorMode': colorMode == ColorMode.color ? 'color' : 'blackAndWhite',
      'duplexMode': duplexMode == DuplexMode.doubleSided ? 'duplex' : 'single',
      'pageRange': pageRange,
      'orientation': orientation == PrintOrientation.landscape ? 'landscape' : 'portrait',
      'copies': copies,
      'paperSize': paperSize.name.toUpperCase(),
      'estimatedCost': estimatedCost,
    };
  }
}
