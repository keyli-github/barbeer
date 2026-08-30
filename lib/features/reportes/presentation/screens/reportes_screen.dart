import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/async/operation_state.dart';
import '../../../../core/files/android_file_artifact_service.dart';
import '../../../../core/files/file_artifact.dart';
import '../../../../core/files/file_artifact_service.dart';
import '../../../../core/files/windows_file_artifact_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/reporte_models.dart';
import '../providers/reportes_provider.dart';

class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen> {
  int _tab = 0;

  // Exportar tab state
  String _reportType = 'ventas';
  late DateTime _desde;
  late DateTime _hasta;
  String _format = 'xlsx';

  // Correo tab state
  final List<TextEditingController> _recipientControllers = [];
  bool _syncedRecipients = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _desde = DateTime(now.year, now.month, 1);
    _hasta = now;
    _recipientControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _recipientControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // React to export state changes
    ref.listen<ReportesState>(reportesProvider, (prev, next) {
      if (prev?.exportState == next.exportState) return;
      final st = next.exportState;
      if (st is OperationContent<ReporteExportado>) {
        _saveFile(st.data);
      } else if (st is OperationRecoverableError<ReporteExportado>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al exportar: ${st.error.message}'),
            backgroundColor: AppColors.error,
          ));
        }
      }
    });

    // React to email state changes
    ref.listen<ReportesState>(reportesProvider, (prev, next) {
      if (!mounted) return;
      if (next.emailSaveSucceeded &&
          prev?.emailSaveSucceeded != next.emailSaveSucceeded) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Destinatarios guardados correctamente.'),
          backgroundColor: AppColors.success,
        ));
      }
      if (next.emailSaveError != null &&
          prev?.emailSaveError != next.emailSaveError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${next.emailSaveError!.message}'),
          backgroundColor: AppColors.error,
        ));
      }
      if (next.emailTestResult != null &&
          prev?.emailTestResult != next.emailTestResult) {
        final ok = next.emailTestResult!.delivered;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Correo de prueba enviado correctamente.'
              : 'El correo no fue entregado.'),
          backgroundColor: ok ? AppColors.success : AppColors.warning,
        ));
      }
      if (next.emailTestError != null &&
          prev?.emailTestError != next.emailTestError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${next.emailTestError!.message}'),
          backgroundColor: AppColors.error,
        ));
      }
    });

    // Sync recipient controllers once when email config first loads
    ref.listen<OperationState<ReporteEmailConfig>>(
      reportesProvider.select((s) => s.emailConfigState),
      (prev, next) {
        if (next is OperationContent<ReporteEmailConfig> &&
            !_syncedRecipients) {
          _syncedRecipients = true;
          final saved = next.data.recipients;
          setState(() {
            for (final c in _recipientControllers) {
              c.dispose();
            }
            _recipientControllers.clear();
            for (final email in saved) {
              _recipientControllers.add(TextEditingController(text: email));
            }
            if (_recipientControllers.isEmpty) {
              _recipientControllers.add(TextEditingController());
            }
          });
        }
      },
    );

    if (auth.user?.rol != 'SUPERADMIN') {
      return const _AccessDeniedScreen();
    }

    final state = ref.watch(reportesProvider);
    final notifier = ref.read(reportesProvider.notifier);

    return SafeArea(
      child: Scaffold(
        body: Column(
          children: [
            _TabToggle(tab: _tab, onTabChange: (t) => setState(() => _tab = t)),
            Expanded(
              child: _tab == 0
                  ? _buildExportarTab(state, notifier)
                  : _buildCorreoTab(state, notifier),
            ),
          ],
        ),
      ),
    );
  }

  // ── Exportar Tab ──────────────────────────────────────────────────────────

  Widget _buildExportarTab(ReportesState state, ReportesNotifier notifier) {
    final invalidDates = _desde.isAfter(_hasta);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // Report type selector
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo de reporte',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _ReportTypeCard(
                      label: 'Ventas',
                      icon: Icons.receipt_long_outlined,
                      value: 'ventas',
                      selected: _reportType,
                      onTap: (v) => setState(() => _reportType = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportTypeCard(
                      label: 'Movimientos',
                      icon: Icons.swap_horiz_rounded,
                      value: 'movimientos',
                      selected: _reportType,
                      onTap: (v) => setState(() => _reportType = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ReportTypeCard(
                      label: 'Ganancias',
                      icon: Icons.trending_up_rounded,
                      value: 'ganancias',
                      selected: _reportType,
                      onTap: (v) => setState(() => _reportType = v),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Date range
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rango de fechas',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _DateRow(
                  label: 'Desde',
                  date: _desde,
                  onPick: (d) => setState(() => _desde = d),
                ),
                const SizedBox(height: 8),
                _DateRow(
                  label: 'Hasta',
                  date: _hasta,
                  onPick: (d) => setState(() => _hasta = d),
                ),
                if (invalidDates) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'La fecha de inicio no puede ser posterior a la fecha de fin.',
                    style: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Format selector
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formato',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final entry in [
                      ('xlsx', 'Excel (.xlsx)'),
                      ('json', 'JSON (.json)'),
                      ('txt', 'Texto (.txt)'),
                    ])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _format == entry.$1
                              ? ElevatedButton(
                                  onPressed: () =>
                                      setState(() => _format = entry.$1),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  child: Text(
                                    entry.$2,
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              : OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _format = entry.$1),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                  ),
                                  child: Text(
                                    entry.$2,
                                    style: const TextStyle(fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            icon: state.exportBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            label:
                Text(state.exportBusy ? 'Descargando...' : 'Descargar reporte'),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: state.exportBusy || invalidDates
                ? null
                : () => _doExport(notifier),
          ),
        ),
      ],
    );
  }

  void _doExport(ReportesNotifier notifier) {
    notifier.exportReport(
      _reportType,
      formato: _format,
      fechaInicio: _isoDate(_desde),
      fechaFin: _isoDate(_hasta),
    );
  }

  String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  Future<void> _saveFile(ReporteExportado exported) async {
    final artifact = FileArtifact(
      bytes: Uint8List.fromList(exported.bytes),
      filename: exported.filename,
      contentType: exported.contentType,
    );

    FileArtifactService service;
    if (Platform.isAndroid) {
      service = AndroidFileArtifactService();
    } else if (Platform.isWindows) {
      service = WindowsFileArtifactService();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Descarga no disponible en esta plataforma.')));
      }
      return;
    }

    final result = await service.save(artifact);
    if (!mounted) return;

    final (String? msg, Color? color) = switch (result) {
      FileArtifactSaved(:final savedPath) => (
          'Reporte guardado: $savedPath',
          AppColors.success as Color?,
        ),
      FileArtifactCancelled() => (null, null),
      FileArtifactValidationFailure(:final reason) => (
          'Archivo inválido: $reason',
          AppColors.error as Color?,
        ),
      FileArtifactPermissionDenied() => (
          'Permiso denegado para guardar el archivo.',
          AppColors.error as Color?,
        ),
      FileArtifactInsufficientSpace() => (
          'Espacio insuficiente en el disco.',
          AppColors.error as Color?,
        ),
      FileArtifactWriteFailure(:final reason) => (
          'Error al guardar: $reason',
          AppColors.error as Color?,
        ),
      FileArtifactOpenUnsupported() => (
          'No se puede abrir este tipo de archivo.',
          AppColors.warning as Color?,
        ),
    };

    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: color));
    }
  }

  // ── Correo Tab ────────────────────────────────────────────────────────────

  Widget _buildCorreoTab(ReportesState state, ReportesNotifier notifier) {
    final emailState = state.emailConfigState;

    if (emailState is OperationLoading<ReporteEmailConfig>) {
      return const Center(child: CircularProgressIndicator());
    }

    if (emailState is OperationRecoverableError<ReporteEmailConfig>) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Error: ${emailState.error.message}',
            style: const TextStyle(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            onPressed: notifier.loadEmailConfig,
          ),
        ]),
      );
    }

    final config = emailState is OperationContent<ReporteEmailConfig>
        ? emailState.data
        : null;
    final smtpOk = config?.smtpConfigured ?? false;

    final hasFormatError =
        _recipientControllers.any((c) => _hasEmailFormatError(c.text));
    final hasDuplicates = _hasDuplicateEmails();
    final canSave = !hasFormatError && !hasDuplicates;
    final canTest = smtpOk && canSave;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // SMTP status badge
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(
                smtpOk
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: smtpOk ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                smtpOk ? 'Servidor de correo listo' : 'SMTP requerido',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: smtpOk ? AppColors.success : AppColors.error,
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        // Recipients card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Destinatarios',
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${_recipientControllers.length}/10',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...List.generate(_recipientControllers.length, (i) {
                  final ctrl = _recipientControllers[i];
                  final formatErr = _hasEmailFormatError(ctrl.text);
                  final dupErr = _isDuplicateAt(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'correo@ejemplo.com',
                            isDense: true,
                            errorText: formatErr
                                ? 'Correo inválido'
                                : dupErr
                                    ? 'Correo duplicado'
                                    : null,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_recipientControllers.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: AppColors.error,
                          onPressed: () => setState(() {
                            ctrl.dispose();
                            _recipientControllers.removeAt(i);
                          }),
                        ),
                    ]),
                  );
                }),
                if (_recipientControllers.length < 10)
                  TextButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Agregar destinatario'),
                    onPressed: () => setState(() =>
                        _recipientControllers.add(TextEditingController())),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            icon: state.emailSaveBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
                state.emailSaveBusy ? 'Guardando...' : 'Guardar destinatarios'),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: state.emailSaveBusy || !canSave
                ? null
                : () {
                    final recipients = _recipientControllers
                        .map((c) => c.text.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    notifier.saveEmailConfig(recipients);
                  },
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            icon: state.emailTestBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(
                state.emailTestBusy ? 'Enviando...' : 'Enviar prueba'),
            onPressed: state.emailTestBusy || !canTest
                ? null
                : () {
                    final recipients = _recipientControllers
                        .map((c) => c.text.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    notifier.testEmailDelivery(recipients: recipients);
                  },
          ),
        ),
      ],
    );
  }

  bool _hasEmailFormatError(String email) {
    if (email.isEmpty) return false;
    return !RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  bool _isDuplicateAt(int index) {
    final val = _recipientControllers[index].text.trim();
    if (val.isEmpty) return false;
    for (var i = 0; i < _recipientControllers.length; i++) {
      if (i != index &&
          _recipientControllers[i].text.trim() == val) return true;
    }
    return false;
  }

  bool _hasDuplicateEmails() {
    final vals = _recipientControllers
        .map((c) => c.text.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return vals.length != vals.toSet().length;
  }
}

// ── Access Denied ─────────────────────────────────────────────────────────

class _AccessDeniedScreen extends StatelessWidget {
  const _AccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Center(
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Acceso restringido',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Solo los superadministradores pueden acceder a los reportes.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tab Toggle ────────────────────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTabChange;

  const _TabToggle({required this.tab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(
          child: tab == 0
              ? ElevatedButton(
                  onPressed: () => onTabChange(0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Exportar'),
                )
              : OutlinedButton(
                  onPressed: () => onTabChange(0),
                  child: const Text('Exportar'),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: tab == 1
              ? ElevatedButton(
                  onPressed: () => onTabChange(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Correo'),
                )
              : OutlinedButton(
                  onPressed: () => onTabChange(1),
                  child: const Text('Correo'),
                ),
        ),
      ]),
    );
  }
}

// ── Report Type Card ──────────────────────────────────────────────────────

class _ReportTypeCard extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final IconData icon;
  final ValueChanged<String> onTap;

  const _ReportTypeCard({
    required this.label,
    required this.value,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color:
                    isSelected ? AppColors.primary : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? AppColors.primary : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Row ──────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  const _DateRow({
    required this.label,
    required this.date,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 56,
        child:
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_rounded, size: 16),
          label: Text(_fmt(date)),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) onPick(picked);
          },
        ),
      ),
    ]);
  }

  String _fmt(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
