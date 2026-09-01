import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/importacion_models.dart';
import '../providers/importaciones_provider.dart';

const double importacionesDesktopBreakpoint = 768;

class ImportacionesScreen extends ConsumerWidget {
  const ImportacionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final canImport =
        auth.user?.rol.toUpperCase() == 'SUPERADMIN' ||
        auth.hasPermission('importaciones:ejecutar');
    if (!canImport) return const _AccessRestricted();

    final state = ref.watch(importacionesProvider);
    final notifier = ref.read(importacionesProvider.notifier);
    final desktop =
        MediaQuery.sizeOf(context).width >= importacionesDesktopBreakpoint;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: notifier.loadVenues,
          child: SingleChildScrollView(
            key: const ValueKey('importaciones-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              desktop ? 24 : 16,
              desktop ? 24 : 16,
              desktop ? 24 : 16,
              96,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1024),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PageHeader(),
                    const SizedBox(height: 20),
                    _SelectionPanel(
                      state: state,
                      notifier: notifier,
                      desktop: desktop,
                    ),
                    if (state.previewStatus == ImportOperationStatus.success &&
                        state.preview != null) ...[
                      const SizedBox(height: 20),
                      _ImportPreviewPanel(
                        result: state.preview!,
                        state: state,
                        notifier: notifier,
                        desktop: desktop,
                      ),
                    ],
                    if (state.importStatus == ImportOperationStatus.success &&
                        state.result != null) ...[
                      const SizedBox(height: 20),
                      _ImportResultPanel(
                        result: state.result!,
                        desktop: desktop,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Importación inicial desde Excel',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Text(
          'Carga productos, ventas históricas y gastos. Los productos ya '
          'existentes se reutilizan por código o nombre normalizado; solo se '
          'crean los nuevos. El sistema valida los cálculos del PANEL y '
          'Gemini completa las imágenes faltantes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.colors.textSecondary,
            height: 1.45,
          ),
        ),
      ),
    ],
  );
}

class _SelectionPanel extends StatelessWidget {
  final ImportacionesState state;
  final ImportacionesNotifier notifier;
  final bool desktop;

  const _SelectionPanel({
    required this.state,
    required this.notifier,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final venue = _VenueSelector(state: state, notifier: notifier);
    final file = _FileSelector(state: state, notifier: notifier);
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: venue),
                const SizedBox(width: 20),
                Expanded(child: file),
              ],
            )
          else ...[
            venue,
            const SizedBox(height: 18),
            file,
          ],
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: desktop ? null : double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('preview-button'),
                onPressed: state.canPreview ? notifier.previewExcel : null,
                icon: state.previewStatus == ImportOperationStatus.loading
                    ? const _ButtonProgress()
                    : const Icon(Icons.visibility_outlined),
                label: Text(
                  state.previewStatus == ImportOperationStatus.loading
                      ? 'Validando Excel…'
                      : 'Previsualizar Excel',
                ),
              ),
            ),
          ),
          if (state.previewStatus == ImportOperationStatus.error &&
              state.previewError != null) ...[
            const SizedBox(height: 14),
            _MessageBox.error(context, state.previewError!),
          ],
        ],
      ),
    );
  }
}

class _VenueSelector extends StatelessWidget {
  final ImportacionesState state;
  final ImportacionesNotifier notifier;

  const _VenueSelector({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Sede de destino',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        key: ValueKey(
          'venue-selector-${state.selectedVenueId}-${state.venues.length}',
        ),
        initialValue: state.selectedVenueId.isEmpty
            ? null
            : state.selectedVenueId,
        isExpanded: true,
        decoration: const InputDecoration(
          hintText: 'Selecciona una sede',
          prefixIcon: Icon(Icons.storefront_outlined),
        ),
        items: state.venues
            .map(
              (venue) => DropdownMenuItem(
                value: venue.id,
                child: Text(venue.nombre, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        onChanged: state.isBusy || state.venuesLoading
            ? null
            : notifier.selectVenue,
      ),
      if (state.venuesLoading) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(minHeight: 2),
      ],
      if (state.venuesError != null) ...[
        const SizedBox(height: 8),
        Text(
          state.venuesError!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.error),
        ),
      ],
    ],
  );
}

class _FileSelector extends StatelessWidget {
  final ImportacionesState state;
  final ImportacionesNotifier notifier;

  const _FileSelector({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Documento XLSX',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Semantics(
        button: true,
        label: 'Seleccionar documento XLSX',
        child: Material(
          color: context.colors.surfaceAlt.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: context.colors.border),
          ),
          child: InkWell(
            key: const ValueKey('file-picker'),
            borderRadius: BorderRadius.circular(10),
            onTap: state.isBusy ? null : notifier.pickFile,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    if (state.pickerBusy)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.description_outlined,
                        color: context.colors.primary,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.selectedFile?.name ??
                            'Selecciona ACTUALIZADO.xlsx',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: state.selectedFile == null
                              ? context.colors.textSecondary
                              : context.colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      if (state.fileError != null) ...[
        const SizedBox(height: 8),
        Text(
          state.fileError!,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.error),
        ),
      ],
      const SizedBox(height: 5),
      Text(
        'Formato .xlsx · Tamaño máximo 15 MB',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textTertiary),
      ),
    ],
  );
}

class _ImportPreviewPanel extends StatelessWidget {
  final ExcelImportPreview result;
  final ImportacionesState state;
  final ImportacionesNotifier notifier;
  final bool desktop;

  const _ImportPreviewPanel({
    required this.result,
    required this.state,
    required this.notifier,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final duplicate = result.duplicate;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusHeader(
            success: duplicate == null,
            title: duplicate == null
                ? 'Excel validado'
                : 'Importación duplicada detectada',
            message:
                duplicate?.message ??
                'Revisa estos datos antes de ejecutar la importación definitiva.',
          ),
          const SizedBox(height: 20),
          _Counters(
            desktop: desktop,
            values: [
              ('Productos', result.summary.products, null),
              ('Productos nuevos', result.summary.newProducts, null),
              ('Reutilizados', result.summary.reusedProducts, null),
              ('Líneas de venta', result.summary.sales, null),
              ('Gastos', result.summary.expenses, null),
            ],
          ),
          const SizedBox(height: 16),
          _DateRanges(summary: result.summary, desktop: desktop),
          const SizedBox(height: 20),
          _TotalsPreview(totals: result.totals, desktop: desktop),
          const SizedBox(height: 22),
          _PreviewBlock(
            title: 'Productos',
            subtitle:
                'Primeros ${result.products.length} de ${result.summary.products}',
            columns: const [
              'Código',
              'Producto',
              'Estado',
              'Categoría',
              'Costo',
              'Venta',
              'Stock actual',
            ],
            rows: result.products
                .map(
                  (product) => [
                    product.sku,
                    product.name,
                    product.isReused
                        ? 'Existente (${product.existingCode ?? product.existingName ?? 'coincidencia'})'
                        : 'Nuevo',
                    product.category,
                    _currency(product.unitCost),
                    _currency(product.salePrice),
                    _number(product.currentStock),
                  ],
                )
                .toList(growable: false),
            desktop: desktop,
            testKey: 'preview-products',
          ),
          const SizedBox(height: 22),
          _PreviewBlock(
            title: 'Ventas',
            subtitle:
                'Primeras ${result.sales.length} de ${result.summary.sales}',
            columns: const [
              'Fecha',
              'N°',
              'Código',
              'Cantidad',
              'P. unitario',
              'Total',
            ],
            rows: result.sales
                .map(
                  (sale) => [
                    _displayDate(sale.date),
                    sale.sourceNumber ?? '—',
                    sale.sku,
                    _number(sale.quantity),
                    _currency(sale.unitPrice),
                    _currency(sale.total),
                  ],
                )
                .toList(growable: false),
            desktop: desktop,
            testKey: 'preview-sales',
          ),
          if (result.expenses.isNotEmpty) ...[
            const SizedBox(height: 22),
            _PreviewBlock(
              title: 'Otros gastos',
              subtitle:
                  'Primeros ${result.expenses.length} de ${result.summary.expenses}',
              columns: const ['Fecha', 'Categoría', 'Descripción', 'Importe'],
              rows: result.expenses
                  .map(
                    (expense) => [
                      _displayDate(expense.date),
                      expense.category ?? '—',
                      expense.description,
                      _currency(expense.amount),
                    ],
                  )
                  .toList(growable: false),
              desktop: desktop,
              testKey: 'preview-expenses',
            ),
          ],
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 20),
            _Warnings(items: result.warnings),
          ],
          if (duplicate == null) ...[
            const SizedBox(height: 20),
            _Confirmation(state: state, onChanged: notifier.setConfirmed),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: desktop ? null : double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('import-button'),
                  onPressed: state.canSubmit ? notifier.importExcel : null,
                  icon: state.importStatus == ImportOperationStatus.loading
                      ? const _ButtonProgress()
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    state.importStatus == ImportOperationStatus.loading
                        ? 'Importando y generando imágenes…'
                        : 'Confirmar e importar',
                  ),
                ),
              ),
            ),
            if (state.importStatus == ImportOperationStatus.loading) ...[
              const SizedBox(height: 10),
              Text(
                'Gemini puede tardar varios minutos en generar las imágenes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            if (state.importStatus == ImportOperationStatus.error &&
                state.importError != null) ...[
              const SizedBox(height: 14),
              _MessageBox.error(context, state.importError!),
            ],
          ],
        ],
      ),
    );
  }
}

class _DateRanges extends StatelessWidget {
  final ExcelImportSummary summary;
  final bool desktop;

  const _DateRanges({required this.summary, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final sales = _DateRangeCard(
      label: 'Período de ventas',
      value: _displayRange(summary.salesDateRange),
    );
    final expenses = _DateRangeCard(
      label: 'Período de gastos',
      value: _displayRange(summary.expensesDateRange),
    );
    if (!desktop) {
      return Column(children: [sales, const SizedBox(height: 12), expenses]);
    }
    return Row(
      children: [
        Expanded(child: sales),
        const SizedBox(width: 12),
        Expanded(child: expenses),
      ],
    );
  }
}

class _DateRangeCard extends StatelessWidget {
  final String label;
  final String value;

  const _DateRangeCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => _SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _TotalsPreview extends StatelessWidget {
  final ImportTotals totals;
  final bool desktop;

  const _TotalsPreview({required this.totals, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final rows = _metricRows
        .map((metric) => (metric.label, metric.format(metric.read(totals))))
        .toList(growable: false);
    if (!desktop) {
      return Column(
        key: const ValueKey('preview-totals-cards'),
        children: rows
            .map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LabelValueCard(label: row.$1, value: row.$2),
              ),
            )
            .toList(growable: false),
      );
    }
    return _BorderedTable(
      key: const ValueKey('preview-totals-table'),
      headers: const ['Indicador', 'Valor del Excel'],
      rows: rows.map((row) => [row.$1, row.$2]).toList(growable: false),
      numericColumns: const {1},
    );
  }
}

class _PreviewBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> columns;
  final List<List<String>> rows;
  final bool desktop;
  final String testKey;

  const _PreviewBlock({
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.rows,
    required this.desktop,
    required this.testKey,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(
        subtitle,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
      ),
      const SizedBox(height: 9),
      if (desktop)
        _BorderedTable(
          key: ValueKey('$testKey-table'),
          headers: columns,
          rows: rows,
        )
      else
        Column(
          key: ValueKey('$testKey-cards'),
          children: List.generate(
            rows.length,
            (rowIndex) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _RecordCard(
                labels: columns,
                values: rows[rowIndex],
                testKey: '$testKey-card-$rowIndex',
              ),
            ),
          ),
        ),
    ],
  );
}

class _ImportResultPanel extends StatelessWidget {
  final ExcelImportResult result;
  final bool desktop;

  const _ImportResultPanel({required this.result, required this.desktop});

  @override
  Widget build(BuildContext context) {
    final comparisons = _metricRows
        .map(
          (metric) => [
            metric.label,
            metric.format(metric.read(result.excelTotals)),
            metric.format(metric.read(result.systemTotals)),
            result.reconciled ? 'Coincide' : 'Revisar',
          ],
        )
        .toList(growable: false);
    return _Panel(
      borderColor: result.reconciled
          ? context.colors.successBorder
          : context.colors.warningBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusHeader(
            success: result.reconciled,
            title: result.reconciled
                ? 'Importación reconciliada'
                : 'Importación completada con diferencias',
            message: result.reconciled
                ? 'Los cálculos del sistema coinciden con el PANEL del Excel.'
                : 'Revisa las diferencias entre el Excel y el sistema.',
          ),
          const SizedBox(height: 20),
          _Counters(
            desktop: desktop,
            values: [
              ('Productos', result.imported.products, null),
              ('Nuevos', result.imported.productsCreated, null),
              ('Reutilizados', result.imported.productsReused, null),
              ('Líneas de venta', result.imported.sales, null),
              ('Gastos', result.imported.expenses, null),
              (
                'Imágenes creadas',
                result.imported.imagesGenerated,
                Icons.image_outlined,
              ),
              ('Imágenes pendientes', result.imported.imagesFailed, null),
            ],
          ),
          const SizedBox(height: 20),
          if (desktop)
            _BorderedTable(
              key: const ValueKey('import-result-table'),
              headers: const ['Indicador', 'Excel', 'Sistema', 'Estado'],
              rows: comparisons,
              numericColumns: const {1, 2},
            )
          else
            Column(
              key: const ValueKey('import-result-cards'),
              children: comparisons
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _RecordCard(
                        labels: const [
                          'Indicador',
                          'Excel',
                          'Sistema',
                          'Estado',
                        ],
                        values: row,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          if (result.warnings.isNotEmpty) ...[
            const SizedBox(height: 20),
            _Warnings(items: result.warnings),
          ],
          if (result.imageFailures.isNotEmpty) ...[
            const SizedBox(height: 20),
            _Warnings(
              title: 'Imágenes pendientes',
              items: result.imageFailures
                  .map((failure) => '${failure.product}: ${failure.reason}')
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _Counters extends StatelessWidget {
  final List<(String, int, IconData?)> values;
  final bool desktop;

  const _Counters({required this.values, required this.desktop});

  @override
  Widget build(BuildContext context) {
    if (!desktop) {
      return Column(
        children: values
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _CounterCard(
                  label: item.$1,
                  value: item.$2,
                  icon: item.$3,
                ),
              ),
            )
            .toList(growable: false),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: _CounterCard(
              label: values[index].$1,
              value: values[index].$2,
              icon: values[index].$3,
            ),
          ),
        ],
      ],
    );
  }
}

class _CounterCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData? icon;

  const _CounterCard({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) => _SoftCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: context.colors.textSecondary),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _StatusHeader extends StatelessWidget {
  final bool success;
  final String title;
  final String message;

  const _StatusHeader({
    required this.success,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        success ? Icons.check_circle_outline : Icons.warning_amber_rounded,
        color: success ? context.colors.success : context.colors.error,
        size: 26,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Confirmation extends StatelessWidget {
  final ImportacionesState state;
  final ValueChanged<bool> onChanged;

  const _Confirmation({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) => _MessageBox(
    color: context.colors.warning,
    backgroundColor: context.colors.warningLight,
    borderColor: context.colors.warningBorder,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: context.colors.warning,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirmación final',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                  'La importación reutilizará los productos existentes y creará '
                  'únicamente los nuevos. También cargará ventas, gastos e imágenes faltantes.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  key: const ValueKey('confirm-checkbox'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: state.confirmed,
                  onChanged: state.importStatus == ImportOperationStatus.loading
                      ? null
                      : (value) => onChanged(value ?? false),
                  title: const Text(
                    'Confirmo que revisé la previsualización y seleccioné la sede correcta.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Warnings extends StatelessWidget {
  final String title;
  final List<String> items;

  const _Warnings({this.title = 'Observaciones', required this.items});

  @override
  Widget build(BuildContext context) => _MessageBox(
    color: context.colors.warning,
    backgroundColor: context.colors.warningLight,
    borderColor: context.colors.warningBorder,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _BorderedTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final Set<int> numericColumns;

  const _BorderedTable({
    super.key,
    required this.headers,
    required this.rows,
    this.numericColumns = const {},
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(context.colors.surfaceAlt),
          headingTextStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          dataTextStyle: Theme.of(context).textTheme.bodySmall,
          horizontalMargin: 14,
          columnSpacing: 24,
          columns: List.generate(
            headers.length,
            (index) => DataColumn(
              label: Text(headers[index]),
              numeric: numericColumns.contains(index),
            ),
          ),
          rows: rows
              .map(
                (row) => DataRow(
                  cells: List.generate(
                    headers.length,
                    (index) => DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 230),
                        child: Text(
                          index < row.length ? row[index] : '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    ),
  );
}

class _RecordCard extends StatelessWidget {
  final List<String> labels;
  final List<String> values;
  final String? testKey;

  const _RecordCard({required this.labels, required this.values, this.testKey});

  @override
  Widget build(BuildContext context) => Container(
    key: testKey == null ? null : ValueKey(testKey),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.surfaceAlt.withValues(alpha: 0.35),
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      children: List.generate(
        labels.length,
        (index) => Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 96,
                child: Text(
                  labels[index],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  index < values.length ? values[index] : '',
                  textAlign: TextAlign.right,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LabelValueCard extends StatelessWidget {
  final String label;
  final String value;

  const _LabelValueCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => _SoftCard(
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 12),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _Panel({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: borderColor ?? context.colors.border),
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppShadows.card,
    ),
    child: child,
  );
}

class _SoftCard extends StatelessWidget {
  final Widget child;

  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.colors.surfaceAlt.withValues(alpha: 0.35),
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}

class _MessageBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  const _MessageBox({
    required this.child,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  factory _MessageBox.error(BuildContext context, String message) =>
      _MessageBox(
        color: context.colors.error,
        backgroundColor: context.colors.errorLight,
        borderColor: context.colors.errorBorder,
        child: Text(message),
      );

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: color, fontSize: 14),
      child: child,
    ),
  );
}

class _ButtonProgress extends StatelessWidget {
  const _ButtonProgress();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
}

class _AccessRestricted extends StatelessWidget {
  const _AccessRestricted();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _Panel(
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 36,
                    color: context.colors.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Acceso restringido',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'El módulo requiere el permiso de importación asignado por el superadministrador.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _MetricDefinition {
  final String label;
  final double Function(ImportTotals totals) read;
  final String Function(double value) format;

  const _MetricDefinition(this.label, this.read, this.format);
}

final _metricRows = <_MetricDefinition>[
  _MetricDefinition('Ventas totales', (totals) => totals.sales, _currency),
  _MetricDefinition('Costo de productos', (totals) => totals.cost, _currency),
  _MetricDefinition(
    'Utilidad bruta',
    (totals) => totals.grossProfit,
    _currency,
  ),
  _MetricDefinition('Unidades vendidas', (totals) => totals.units, _number),
  _MetricDefinition(
    'Gasto en personal',
    (totals) => totals.personnel,
    _currency,
  ),
  _MetricDefinition(
    'Otros gastos',
    (totals) => totals.otherExpenses,
    _currency,
  ),
  _MetricDefinition('Utilidad neta', (totals) => totals.netProfit, _currency),
  _MetricDefinition(
    'Margen neto',
    (totals) => totals.netMargin,
    (value) => '${value.toStringAsFixed(2)}%',
  ),
];

final NumberFormat _currencyFormat = NumberFormat.currency(
  locale: 'es_PE',
  symbol: 'S/ ',
  decimalDigits: 2,
);

String _currency(double value) => _currencyFormat.format(value);

String _number(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String _displayDate(String value) {
  final date = DateTime.tryParse(
    value.length >= 10 ? value.substring(0, 10) : value,
  );
  if (date == null) return value;
  return '${date.day}/${date.month}/${date.year}';
}

String _displayRange(ImportDateRange? range) {
  if (range == null) return 'Sin registros';
  if (range.from == range.to) return _displayDate(range.from);
  return '${_displayDate(range.from)} – ${_displayDate(range.to)}';
}
