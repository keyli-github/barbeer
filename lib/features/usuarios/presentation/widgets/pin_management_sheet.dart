import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/usuario_permission_models.dart';
import '../../data/usuario_admin_repository.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class _PinEntry {
  final String userId;
  final String username;
  final String rol;
  bool autoGenerate;
  String pin; // current known PIN or draft manual PIN
  bool saving;
  _PinEntry({
    required this.userId,
    required this.username,
    required this.rol,
    this.autoGenerate = true,
    this.pin = '',
    this.saving = false,
  });
  _PinEntry copyWith({bool? autoGenerate, String? pin, bool? saving}) =>
      _PinEntry(
        userId: userId,
        username: username,
        rol: rol,
        autoGenerate: autoGenerate ?? this.autoGenerate,
        pin: pin ?? this.pin,
        saving: saving ?? this.saving,
      );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

/// Opens the PIN management bottom sheet with the current server configuration.
Future<void> showPinManagementSheet(
  BuildContext context, {
  UsuarioAdminRepository? repo,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _PinSheet(repo: repo),
  );
}

class _PinSheet extends ConsumerStatefulWidget {
  final UsuarioAdminRepository? repo;

  const _PinSheet({this.repo});
  @override
  ConsumerState<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends ConsumerState<_PinSheet> {
  List<_PinEntry> _entries = [];
  String _search = '';
  bool _loading = true;
  String? _error;
  late final _repo = widget.repo ?? UsuarioAdminRepository(ApiClient.instance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await _repo.getSuperadminPins();
      if (!mounted) return;
      setState(() {
        _entries = users.map((u) {
          final rol =
              (u['rol'] is Map ? u['rol']['nombre'] : u['rol']) as String? ??
              '';
          return _PinEntry(
            userId: u['id'] as String? ?? '',
            username: u['username'] as String? ?? '',
            rol: rol,
            autoGenerate: u['pinAutoGenerate'] as bool? ?? true,
            pin: u['currentPin'] as String? ?? '',
          );
        }).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save(_PinEntry entry) async {
    setState(() {
      final idx = _entries.indexOf(entry);
      if (idx >= 0) _entries[idx] = entry.copyWith(saving: true);
    });
    try {
      final payload = PinConfigPayload(
        pinAutoGenerate: entry.autoGenerate,
        superadminPin: entry.autoGenerate ? null : entry.pin,
      );
      await _repo.configureSuperadminPin(entry.userId, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PIN guardado para ${entry.username}.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          final idx = _entries.indexWhere((e) => e.userId == entry.userId);
          if (idx >= 0) _entries[idx] = _entries[idx].copyWith(saving: false);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _entries
        .where(
          (e) =>
              _search.isEmpty ||
              e.username.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Gestionar claves PIN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Buscar usuario…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No se pudieron cargar las claves PIN.',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Sin usuarios.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _PinRow(
                      entry: filtered[i],
                      onSave: _save,
                      onChanged: (updated) => setState(() {
                        final idx = _entries.indexWhere(
                          (e) => e.userId == updated.userId,
                        );
                        if (idx >= 0) _entries[idx] = updated;
                      }),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PinRow extends StatefulWidget {
  final _PinEntry entry;
  final void Function(_PinEntry) onSave;
  final void Function(_PinEntry) onChanged;
  const _PinRow({
    required this.entry,
    required this.onSave,
    required this.onChanged,
  });
  @override
  State<_PinRow> createState() => _PinRowState();
}

class _PinRowState extends State<_PinRow> {
  late TextEditingController _pinCtrl;

  @override
  void initState() {
    super.initState();
    _pinCtrl = TextEditingController(text: widget.entry.pin);
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      e.rol,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Mode toggle
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Auto')),
                  ButtonSegment(value: false, label: Text('Manual')),
                ],
                selected: {e.autoGenerate},
                onSelectionChanged: (v) {
                  widget.onChanged(e.copyWith(autoGenerate: v.first));
                },
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (e.autoGenerate) ...[
            // Auto mode: show current PIN if known, or message
            if (e.pin.isNotEmpty)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      e.pin,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                        letterSpacing: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copiar',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: e.pin));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('PIN copiado.')),
                      );
                    },
                  ),
                  const Spacer(),
                  const Text(
                    'Activo hoy',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              )
            else
              Text(
                'Clave dinámica que rota cada 24 horas.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: e.saving ? null : () => widget.onSave(e),
              icon: e.saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, size: 16),
              label: const Text('Guardar modo auto'),
            ),
          ] else ...[
            // Manual mode: PIN input
            TextFormField(
              controller: _pinCtrl,
              obscureText: true,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 22,
                letterSpacing: 8,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '• • • •',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => widget.onChanged(e.copyWith(pin: v)),
            ),
            const SizedBox(height: 4),
            ElevatedButton.icon(
              onPressed: (e.pin.length == 4 && !e.saving)
                  ? () => widget.onSave(e)
                  : null,
              icon: e.saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, size: 16),
              label: const Text('Guardar PIN'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
