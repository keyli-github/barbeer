typedef Json = Map<String, dynamic>;

class ImportVenue {
  final String id;
  final String nombre;
  final String? codigoSede;

  const ImportVenue({required this.id, required this.nombre, this.codigoSede});

  factory ImportVenue.fromJson(Json json) => ImportVenue(
    id: _string(json['id']),
    nombre: _string(json['nombre']),
    codigoSede: _nullableString(json['codigoSede']),
  );
}

class ImportTotals {
  final double sales;
  final double cost;
  final double grossProfit;
  final double units;
  final double personnel;
  final double otherExpenses;
  final double netProfit;
  final double netMargin;

  const ImportTotals({
    this.sales = 0,
    this.cost = 0,
    this.grossProfit = 0,
    this.units = 0,
    this.personnel = 0,
    this.otherExpenses = 0,
    this.netProfit = 0,
    this.netMargin = 0,
  });

  factory ImportTotals.fromJson(Object? value) {
    final json = _json(value);
    return ImportTotals(
      sales: _double(json['sales']),
      cost: _double(json['cost']),
      grossProfit: _double(json['grossProfit']),
      units: _double(json['units']),
      personnel: _double(json['personnel']),
      otherExpenses: _double(json['otherExpenses']),
      netProfit: _double(json['netProfit']),
      netMargin: _double(json['netMargin']),
    );
  }
}

class ImportDateRange {
  final String from;
  final String to;

  const ImportDateRange({required this.from, required this.to});

  factory ImportDateRange.fromJson(Object? value) {
    final json = _json(value);
    return ImportDateRange(
      from: _string(json['from']),
      to: _string(json['to']),
    );
  }
}

class ExcelImportDuplicate {
  final String code;
  final String message;
  final String? importacionId;
  final String? archivoAnterior;
  final String? importadoAt;

  const ExcelImportDuplicate({
    required this.code,
    required this.message,
    this.importacionId,
    this.archivoAnterior,
    this.importadoAt,
  });

  factory ExcelImportDuplicate.fromJson(Object? value) {
    final json = _json(value);
    return ExcelImportDuplicate(
      code: _string(json['code']),
      message: _string(json['message']),
      importacionId: _nullableString(json['importacionId']),
      archivoAnterior: _nullableString(json['archivoAnterior']),
      importadoAt: _nullableString(json['importadoAt']),
    );
  }
}

class ExcelImportSummary {
  final int products;
  final int sales;
  final int expenses;
  final ImportDateRange? salesDateRange;
  final ImportDateRange? expensesDateRange;

  const ExcelImportSummary({
    this.products = 0,
    this.sales = 0,
    this.expenses = 0,
    this.salesDateRange,
    this.expensesDateRange,
  });

  factory ExcelImportSummary.fromJson(Object? value) {
    final json = _json(value);
    return ExcelImportSummary(
      products: _int(json['products']),
      sales: _int(json['sales']),
      expenses: _int(json['expenses']),
      salesDateRange: _nullableRange(json['salesDateRange']),
      expensesDateRange: _nullableRange(json['expensesDateRange']),
    );
  }
}

class ExcelImportProduct {
  final String sku;
  final String name;
  final String category;
  final double unitCost;
  final double salePrice;
  final double initialStock;
  final double currentStock;

  const ExcelImportProduct({
    required this.sku,
    required this.name,
    required this.category,
    required this.unitCost,
    required this.salePrice,
    required this.initialStock,
    required this.currentStock,
  });

  factory ExcelImportProduct.fromJson(Object? value) {
    final json = _json(value);
    return ExcelImportProduct(
      sku: _string(json['sku']),
      name: _string(json['name']),
      category: _string(json['category']),
      unitCost: _double(json['unitCost']),
      salePrice: _double(json['salePrice']),
      initialStock: _double(json['initialStock']),
      currentStock: _double(json['currentStock']),
    );
  }
}

class ExcelImportSale {
  final String date;
  final String? sourceNumber;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double total;

  const ExcelImportSale({
    required this.date,
    this.sourceNumber,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory ExcelImportSale.fromJson(Object? value) {
    final json = _json(value);
    return ExcelImportSale(
      date: _string(json['date']),
      sourceNumber: _nullableString(json['sourceNumber']),
      sku: _string(json['sku']),
      quantity: _double(json['quantity']),
      unitPrice: _double(json['unitPrice']),
      total: _double(json['total']),
    );
  }
}

class ExcelImportExpense {
  final String date;
  final String description;
  final String? category;
  final double amount;

  const ExcelImportExpense({
    required this.date,
    required this.description,
    this.category,
    required this.amount,
  });

  factory ExcelImportExpense.fromJson(Object? value) {
    final json = _json(value);
    return ExcelImportExpense(
      date: _string(json['date']),
      description: _string(json['description']),
      category: _nullableString(json['category']),
      amount: _double(json['amount']),
    );
  }
}

class ExcelImportPreview {
  final bool valid;
  final String file;
  final String sha256;
  final String contentSha256;
  final String sedeId;
  final ExcelImportDuplicate? duplicate;
  final ExcelImportSummary summary;
  final ImportTotals totals;
  final List<String> warnings;
  final List<ExcelImportProduct> products;
  final List<ExcelImportSale> sales;
  final List<ExcelImportExpense> expenses;

  const ExcelImportPreview({
    required this.valid,
    required this.file,
    required this.sha256,
    required this.contentSha256,
    required this.sedeId,
    this.duplicate,
    required this.summary,
    required this.totals,
    this.warnings = const [],
    this.products = const [],
    this.sales = const [],
    this.expenses = const [],
  });

  factory ExcelImportPreview.fromJson(Json json) => ExcelImportPreview(
    valid: _bool(json['valid']),
    file: _string(json['file']),
    sha256: _string(json['sha256']),
    contentSha256: _string(json['contentSha256']),
    sedeId: _string(json['sedeId']),
    duplicate: json['duplicate'] is Map
        ? ExcelImportDuplicate.fromJson(json['duplicate'])
        : null,
    summary: ExcelImportSummary.fromJson(json['summary']),
    totals: ImportTotals.fromJson(json['totals']),
    warnings: _strings(json['warnings']),
    products: _models(json['products'], ExcelImportProduct.fromJson),
    sales: _models(json['sales'], ExcelImportSale.fromJson),
    expenses: _models(json['expenses'], ExcelImportExpense.fromJson),
  );
}

class ExcelImportedCounts {
  final int products;
  final int sales;
  final int expenses;
  final int imagesGenerated;
  final int imagesFailed;

  const ExcelImportedCounts({
    this.products = 0,
    this.sales = 0,
    this.expenses = 0,
    this.imagesGenerated = 0,
    this.imagesFailed = 0,
  });

  factory ExcelImportedCounts.fromJson(Object? value) {
    final json = _json(value);
    return ExcelImportedCounts(
      products: _int(json['products']),
      sales: _int(json['sales']),
      expenses: _int(json['expenses']),
      imagesGenerated: _int(json['imagesGenerated']),
      imagesFailed: _int(json['imagesFailed']),
    );
  }
}

class ExcelImportImageFailure {
  final String productId;
  final String product;
  final String reason;

  const ExcelImportImageFailure({
    required this.productId,
    required this.product,
    required this.reason,
  });

  factory ExcelImportImageFailure.fromJson(Object? value) {
    final json = _json(value);
    return ExcelImportImageFailure(
      productId: _string(json['productId']),
      product: _string(json['product']),
      reason: _string(json['reason']),
    );
  }
}

class ExcelImportResult {
  final bool success;
  final String file;
  final String sha256;
  final String sedeId;
  final String cajaId;
  final ExcelImportedCounts imported;
  final ImportTotals excelTotals;
  final ImportTotals systemTotals;
  final bool reconciled;
  final List<String> warnings;
  final List<ExcelImportImageFailure> imageFailures;

  const ExcelImportResult({
    required this.success,
    required this.file,
    required this.sha256,
    required this.sedeId,
    required this.cajaId,
    required this.imported,
    required this.excelTotals,
    required this.systemTotals,
    required this.reconciled,
    this.warnings = const [],
    this.imageFailures = const [],
  });

  factory ExcelImportResult.fromJson(Json json) => ExcelImportResult(
    success: _bool(json['success']),
    file: _string(json['file']),
    sha256: _string(json['sha256']),
    sedeId: _string(json['sedeId']),
    cajaId: _string(json['cajaId']),
    imported: ExcelImportedCounts.fromJson(json['imported']),
    excelTotals: ImportTotals.fromJson(json['excelTotals']),
    systemTotals: ImportTotals.fromJson(json['systemTotals']),
    reconciled: _bool(json['reconciled']),
    warnings: _strings(json['warnings']),
    imageFailures: _models(
      json['imageFailures'],
      ExcelImportImageFailure.fromJson,
    ),
  );
}

Json _json(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

String _string(Object? value) => value is String ? value : '';

String? _nullableString(Object? value) {
  final result = _string(value).trim();
  return result.isEmpty ? null : result;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  return 0;
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? _double(value).toInt();
  return 0;
}

bool _bool(Object? value) => value == true || value == 'true' || value == 1;

List<String> _strings(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

List<T> _models<T>(Object? value, T Function(Object?) fromJson) => value is List
    ? value.whereType<Map>().map<T>(fromJson).toList(growable: false)
    : const [];

ImportDateRange? _nullableRange(Object? value) {
  if (value is! Map) return null;
  final range = ImportDateRange.fromJson(value);
  return range.from.isEmpty || range.to.isEmpty ? null : range;
}
