import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/async/operation_state.dart';
import '../../../../core/files/android_file_artifact_service.dart';
import '../../../../core/files/file_artifact.dart';
import '../../../../core/files/file_artifact_service.dart';
import '../../../../core/files/windows_file_artifact_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/respaldo_models.dart';
import '../../data/respaldos_repository.dart';
import '../../../../core/network/api_client.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _repoProvider = Provider<RespaldosRepository>(
    (_) => RespaldosRepository(ApiClient.instance));

class _State {
  final BackupSchedule? schedule;
  final BackupRunsPage? runs;
  final bool scheduleLoading;
  final bool runsLoading;
  final bool saveLoading;
  final String? downloadingFormat;
  final String? error;
  const _State({
    this.schedule,
    this.runs,
    this.scheduleLoading = false,
    this.runsLoading = false,
    this.saveLoading = false,
    this.downloadingFormat,
    this.error,
  });
  _State copyWith({
    BackupSchedule? schedule,
    BackupRunsPage? runs,
    bool? scheduleLoading,
    bool? runsLoading,
    bool? saveLoading,
    Object? downloadingFormat = _sentinel,
    Object? error = _sentinel,
  }) =>
      _State(
        schedule: schedule ?? this.schedule,
        runs: runs ?? this.runs,
        scheduleLoading: scheduleLoading ?? this.scheduleLoading,
        runsLoading: runsLoading ?? this.runsLoading,
        saveLoading: saveLoading ?? this.saveLoading,
        downloadingFormat: downloadingFormat == _sentinel
            ? this.downloadingFormat
            : downloadingFormat as String?,
        error: error == _sentinel ? this.error : error as String?,
      );
}

const _sentinel = Object();

class _Notifier extends StateNotifier<_State> {
  final RespaldosRepository _repo;
  _Notifier(this._repo) : super(const _State());

  Future<void> loadAll() async {
    state = state.copyWith(scheduleLoading: true, runsLoading: true);
    try {
      final s = await _repo.getSchedule();
      state = state.copyWith(schedule: s, scheduleLoading: false);
    } catch (e) {
      state = state.copyWith(scheduleLoading: false, error: e.toString());
    }
    try {
      final r = await _repo.listRuns(limit: 25);
      state = state.copyWith(runs: r, runsLoading: false);
    } catch (e) {
      state = state.copyWith(runsLoading: false, error: e.toString());
    }
  }

  Future<void> refreshRuns() async {
    state = state.copyWith(runsLoading: true);
    try {
      final r = await _repo.listRuns(limit: 25);
      state = state.copyWith(runs: r, runsLoading: false);
    } catch (e) {
      state = state.copyWith(runsLoading: false, error: e.toString());
    }
  }

  Future<String?> saveSchedule(BackupSchedule s) async {
    state = state.copyWith(saveLoading: true);
    try {
      final saved = await _repo.updateSchedule(s);
      state = state.copyWith(schedule: saved, saveLoading: false);
      return null;
    } catch (e) {
      state = state.copyWith(saveLoading: false);
      return e.toString();
    }
  }

  Future<Uint8List?> downloadArtifact(
      String runId, String format, String? sha256) async {
    state = state.copyWith(downloadingFormat: format);
    try {
      final bytes = await _repo.downloadArtifact(runId, format,
          expectedSha256: sha256);
      state = state.copyWith(downloadingFormat: null);
      return bytes;
    } catch (e) {
      state = state.copyWith(downloadingFormat: null);
      rethrow;
    }
  }
}

final _notifierProvider =
    StateNotifierProvider<_Notifier, _State>((ref) => _Notifier(ref.read(_repoProvider)));

// ── Screen ────────────────────────────────────────────────────────────────────

class RespaldosScreen extends ConsumerStatefulWidget {
  const RespaldosScreen({super.key});
  @override
  ConsumerState<RespaldosScreen> createState() => _RespaldosScreenState();
}

class _RespaldosScreenState extends ConsumerState<RespaldosScreen> {
  bool _enabled = false;
  String _frequency = 'DAILY';
  final Set<String> _formats = {'XLSX'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_notifierProvider.notifier).loadAll();
    });
  }

  void _syncFromSchedule(BackupSchedule s) {
    setState(() {
      _enabled = s.enabled;
      _frequency = s.frequency;
      _formats
        ..clear()
        ..addAll(s.formats);
    });
  }

  Future<void> _saveSchedule() async {
    if (_formats.isEmpty) return;
    final draft = BackupSchedule(
      enabled: _enabled,
      frequency: _frequency,
      formats: _formats.toList(),
      timezone: ref.read(_notifierProvider).schedule?.timezone ?? 'UTC',
    );
    final err =
        await ref.read(_notifierProvider.notifier).saveSchedule(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err == null ? 'Programación guardada.' : 'Error: $err'),
      backgroundColor: err == null ? Colors.green : Colors.red,
    ));
  }

  Future<void> _download(
      BuildContext ctx, BackupRun run, BackupArtifact artifact) async {
    Uint8List? bytes;
    try {
      bytes = await ref
          .read(_notifierProvider.notifier)
          .downloadArtifact(run.id, artifact.format, artifact.sha256);
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
      return;
    }
    if (bytes == null || !ctx.mounted) return;
    final ext = artifact.format.toLowerCase();
    final filename =
        'respaldo-${run.id.substring(0, 8)}.$ext';
    final ct = ext == 'xlsx'
        ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        : ext == 'json'
            ? 'application/json'
            : 'text/plain';
    final fa = FileArtifact(
        bytes: bytes, filename: filename, contentType: ct,
        expectedLength: bytes.length);
    FileArtifactService svc;
    if (Platform.isAndroid) {
      svc = AndroidFileArtifactService();
    } else if (Platform.isWindows) {
      svc = WindowsFileArtifactService();
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Descarga no disponible en esta plataforma.')));
      return;
    }
    final result = await svc.save(fa);
    if (!ctx.mounted) return;
    if (result is FileArtifactSaved) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Descarga completada.'), backgroundColor: Colors.green));
    } else if (result is! FileArtifactCancelled) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Error al guardar: $result'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(_notifierProvider);

    // Sync schedule to local draft once loaded
    ref.listen(_notifierProvider.select((s) => s.schedule), (_, s) {
      if (s != null) _syncFromSchedule(s);
    });

    final canManage =
        auth.user?.permisos.contains('respaldos:gestionar') ?? false;

    return Scaffold(
      body: SafeArea(
        child: canManage
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Respaldos',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _ScheduleCard(
                      schedule: state.schedule,
                      loading: state.scheduleLoading,
                      saveLoading: state.saveLoading,
                      enabled: _enabled,
                      frequency: _frequency,
                      formats: _formats,
                      onEnabledChanged: (v) =>
                          setState(() => _enabled = v),
                      onFrequencyChanged: (v) =>
                          setState(() => _frequency = v),
                      onFormatToggled: (f) => setState(() =>
                          _formats.contains(f)
                              ? _formats.remove(f)
                              : _formats.add(f)),
                      onSave: _saveSchedule,
                    ),
                    const SizedBox(height: 16),
                    _HistoryCard(
                      runs: state.runs,
                      loading: state.runsLoading,
                      downloadingFormat: state.downloadingFormat,
                      onRefresh: () =>
                          ref.read(_notifierProvider.notifier).refreshRuns(),
                      onDownload: (run, artifact) =>
                          _download(context, run, artifact),
                    ),
                  ],
                ),
              )
            : const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.shield_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Acceso restringido',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Necesitás el permiso respaldos:gestionar.',
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
      ),
    );
  }
}

// ── Schedule Card ─────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final BackupSchedule? schedule;
  final bool loading, saveLoading;
  final bool enabled;
  final String frequency;
  final Set<String> formats;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<String> onFormatToggled;
  final VoidCallback onSave;
  const _ScheduleCard({
    required this.schedule,
    required this.loading,
    required this.saveLoading,
    required this.enabled,
    required this.frequency,
    required this.formats,
    required this.onEnabledChanged,
    required this.onFrequencyChanged,
    required this.onFormatToggled,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())));
    }
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Programación automática',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activar respaldos programados'),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
                labelText: 'Frecuencia', border: OutlineInputBorder()),
            value: frequency,
            items: const [
              DropdownMenuItem(value: 'DAILY', child: Text('Diaria')),
              DropdownMenuItem(value: 'WEEKLY', child: Text('Semanal')),
              DropdownMenuItem(value: 'MONTHLY', child: Text('Mensual')),
            ],
            onChanged: (v) => onFrequencyChanged(v!),
          ),
          const SizedBox(height: 8),
          const Text('Formatos de artefacto',
              style: TextStyle(fontWeight: FontWeight.w600)),
          ...[
            ('XLSX', 'Excel (.xlsx)'),
            ('JSON', 'JSON (.json)'),
            ('TXT', 'Texto (.txt)'),
          ].map((f) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(f.$2),
                value: formats.contains(f.$1),
                onChanged: (_) => onFormatToggled(f.$1),
              )),
          if (formats.isEmpty)
            const Text('Seleccioná al menos un formato.',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          if (schedule != null) ...[
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Timezone'),
              trailing: Text(schedule!.timezone),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Próxima ejecución'),
              trailing: Text(schedule!.nextRunAt ?? '—'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Última ejecución'),
              trailing: Text(schedule!.lastRunAt ?? '—'),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: formats.isEmpty || saveLoading ? null : onSave,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white),
              child: saveLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar programación'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── History Card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final BackupRunsPage? runs;
  final bool loading;
  final String? downloadingFormat;
  final VoidCallback onRefresh;
  final void Function(BackupRun, BackupArtifact) onDownload;
  const _HistoryCard({
    required this.runs,
    required this.loading,
    required this.downloadingFormat,
    required this.onRefresh,
    required this.onDownload,
  });

  Color _statusColor(String status) => switch (status) {
        'SUCCEEDED' => Colors.green,
        'FAILED' => Colors.red,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Historial de ejecuciones',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold))),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: loading ? null : onRefresh),
            ]),
            if (loading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator()))
            else if (runs == null || runs!.data.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Sin ejecuciones registradas.',
                      style: TextStyle(color: Colors.grey)))
            else
              ...runs!.data.map((run) => _RunTile(
                  run: run,
                  downloadingFormat: downloadingFormat,
                  onDownload: onDownload,
                  statusColor: _statusColor(run.status))),
          ],
        ),
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  final BackupRun run;
  final String? downloadingFormat;
  final void Function(BackupRun, BackupArtifact) onDownload;
  final Color statusColor;
  const _RunTile(
      {required this.run,
      required this.downloadingFormat,
      required this.onDownload,
      required this.statusColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (run.status == 'RUNNING')
                  const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                if (run.status == 'RUNNING') const SizedBox(width: 4),
                Text(run.status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const Spacer(),
            Text('${run.attempts} intento(s)',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          if (run.startedAt != null) ...[
            const SizedBox(height: 4),
            Text(run.startedAt!,
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (run.lastError != null) ...[
            const SizedBox(height: 4),
            Text('Error: ${run.lastError}',
                style: const TextStyle(
                    color: Colors.red, fontSize: 12)),
          ],
          if (run.artifacts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: run.artifacts.map((a) {
              final isThis = downloadingFormat == a.format;
              return OutlinedButton.icon(
                onPressed: downloadingFormat != null ? null : () => onDownload(run, a),
                icon: isThis
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download, size: 14),
                label: Text(a.format, style: const TextStyle(fontSize: 12)),
              );
            }).toList()),
          ],
        ]),
      ),
    );
  }
}
