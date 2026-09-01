import 'package:barbeer/features/importaciones/data/models/importacion_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'importaciones_fixtures.dart';

void main() {
  group('ExcelImportPreview', () {
    test('maps the complete preview contract', () {
      final preview = ExcelImportPreview.fromJson(previewJson(duplicate: true));

      expect(preview.valid, isTrue);
      expect(preview.file, 'ACTUALIZADO.xlsx');
      expect(preview.contentSha256, 'content-sha');
      expect(preview.duplicate?.code, 'EXCEL_ALREADY_IMPORTED');
      expect(preview.duplicate?.importacionId, 'import-previous');
      expect(preview.summary.products, 2);
      expect(preview.summary.salesDateRange?.from, '2026-08-01');
      expect(preview.summary.expensesDateRange?.to, '2026-08-03');
      expect(preview.totals.netMargin, -0.83);
      expect(preview.products.single.currentStock, 17);
      expect(preview.sales.single.sourceNumber, 'V-001');
      expect(preview.expenses.single.category, 'Operación');
      expect(preview.warnings, ['Se normalizó una categoría.']);
    });

    test('defensively handles missing and unexpected nested values', () {
      final preview = ExcelImportPreview.fromJson({
        'valid': 'true',
        'summary': {
          'products': '4',
          'salesDateRange': {'from': '', 'to': false},
        },
        'totals': {'sales': '12.50', 'units': '3'},
        'warnings': ['válida', 2, null],
        'products': [
          {'sku': 'P-1', 'currentStock': '7.5'},
          'invalid',
        ],
        'sales': null,
        'expenses': {},
      });

      expect(preview.valid, isTrue);
      expect(preview.summary.products, 4);
      expect(preview.summary.salesDateRange, isNull);
      expect(preview.totals.sales, 12.5);
      expect(preview.totals.units, 3);
      expect(preview.products, hasLength(1));
      expect(preview.products.single.currentStock, 7.5);
      expect(preview.sales, isEmpty);
      expect(preview.expenses, isEmpty);
      expect(preview.warnings, ['válida']);
    });
  });

  group('ExcelImportResult', () {
    test('maps reconciliation, counters, totals and image failures', () {
      final result = ExcelImportResult.fromJson(importResultJson());

      expect(result.success, isTrue);
      expect(result.reconciled, isTrue);
      expect(result.cajaId, 'cash-1');
      expect(result.imported.products, 2);
      expect(result.imported.imagesGenerated, 1);
      expect(result.imported.imagesFailed, 1);
      expect(result.excelTotals.grossProfit, 14.25);
      expect(result.systemTotals.netProfit, -0.25);
      expect(result.imageFailures.single.productId, 'product-2');
      expect(result.imageFailures.single.reason, contains('Gemini'));
    });

    test('uses safe defaults for malformed optional collections', () {
      final result = ExcelImportResult.fromJson({
        'success': 1,
        'imported': {'products': '2', 'imagesFailed': '1'},
        'excelTotals': null,
        'systemTotals': [],
        'reconciled': 'true',
        'warnings': 'invalid',
        'imageFailures': [null, 'invalid'],
      });

      expect(result.success, isTrue);
      expect(result.reconciled, isTrue);
      expect(result.imported.products, 2);
      expect(result.imported.imagesFailed, 1);
      expect(result.excelTotals.sales, 0);
      expect(result.systemTotals.sales, 0);
      expect(result.warnings, isEmpty);
      expect(result.imageFailures, isEmpty);
    });
  });

  test('ImportVenue tolerates nullable and unexpected fields', () {
    final venue = ImportVenue.fromJson({
      'id': 'venue-1',
      'nombre': 'Principal',
      'codigoSede': null,
    });
    final malformed = ImportVenue.fromJson({
      'id': 9,
      'nombre': false,
      'codigoSede': [],
    });

    expect(venue.codigoSede, isNull);
    expect(malformed.id, isEmpty);
    expect(malformed.nombre, isEmpty);
    expect(malformed.codigoSede, isNull);
  });
}
