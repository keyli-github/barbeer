import 'package:barbeer/features/importaciones/data/models/importacion_models.dart';

Map<String, dynamic> previewJson({bool duplicate = false}) => {
  'valid': true,
  'file': 'ACTUALIZADO.xlsx',
  'sha256': 'file-sha',
  'contentSha256': 'content-sha',
  'sedeId': 'venue-1',
  'duplicate': duplicate
      ? {
          'code': 'EXCEL_ALREADY_IMPORTED',
          'message': 'Este archivo ya fue importado.',
          'importacionId': 'import-previous',
          'archivoAnterior': 'ACTUALIZADO.xlsx',
          'importadoAt': '2026-08-31T12:00:00Z',
        }
      : null,
  'summary': {
    'products': 2,
    'sales': 3,
    'expenses': 1,
    'salesDateRange': {'from': '2026-08-01', 'to': '2026-08-02'},
    'expensesDateRange': {'from': '2026-08-03', 'to': '2026-08-03'},
  },
  'totals': totalsJson(),
  'warnings': ['Se normalizó una categoría.'],
  'products': [
    {
      'sku': 'P-001',
      'name': 'Cerveza artesanal',
      'category': 'Cervezas',
      'unitCost': 5.25,
      'salePrice': 10,
      'initialStock': 20,
      'currentStock': 17,
    },
  ],
  'sales': [
    {
      'date': '2026-08-01',
      'sourceNumber': 'V-001',
      'sku': 'P-001',
      'quantity': 3,
      'unitPrice': 10,
      'total': 30,
    },
  ],
  'expenses': [
    {
      'date': '2026-08-03',
      'description': 'Limpieza',
      'category': 'Operación',
      'amount': 12.5,
    },
  ],
};

Map<String, dynamic> totalsJson() => {
  'sales': 30,
  'cost': 15.75,
  'grossProfit': 14.25,
  'units': 3,
  'personnel': 2,
  'otherExpenses': 12.5,
  'netProfit': -0.25,
  'netMargin': -0.83,
};

Map<String, dynamic> importResultJson() => {
  'success': true,
  'file': 'ACTUALIZADO.xlsx',
  'sha256': 'file-sha',
  'sedeId': 'venue-1',
  'cajaId': 'cash-1',
  'imported': {
    'products': 2,
    'sales': 3,
    'expenses': 1,
    'imagesGenerated': 1,
    'imagesFailed': 1,
  },
  'excelTotals': totalsJson(),
  'systemTotals': totalsJson(),
  'reconciled': true,
  'warnings': ['Una imagen quedó pendiente.'],
  'imageFailures': [
    {
      'productId': 'product-2',
      'product': 'Producto pendiente',
      'reason': 'Gemini no devolvió una imagen.',
    },
  ],
};

ExcelImportPreview previewModel({bool duplicate = false}) =>
    ExcelImportPreview.fromJson(previewJson(duplicate: duplicate));

ExcelImportResult importResultModel() =>
    ExcelImportResult.fromJson(importResultJson());
