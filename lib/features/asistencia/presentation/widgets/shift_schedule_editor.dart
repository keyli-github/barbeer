import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';

class ShiftScheduleEditor extends StatefulWidget {
  final String? roleId;
  final List<Map<String, dynamic>> schedules;
  final void Function(String?, List<Map<String, dynamic>>) onChanged;
  const ShiftScheduleEditor({
    super.key,
    required this.roleId,
    required this.schedules,
    required this.onChanged,
  });
  @override
  State<ShiftScheduleEditor> createState() => _ShiftScheduleEditorState();
}

class _ShiftScheduleEditorState extends State<ShiftScheduleEditor> {
  late final Future<List<Map<String, dynamic>>> _roles = _loadRoles();
  Future<List<Map<String, dynamic>>> _loadRoles() async {
    final response = await ApiClient.instance.get('/turnos/roles-disponibles');
    return (response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static const _days = [
    'Domingo',
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
  ];
  String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  void _change(int index, String field, dynamic value) {
    final updated = widget.schedules
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    updated[index][field] = value;
    widget.onChanged(widget.roleId, updated);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _roles,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return const Text(
              'No se pudo cargar el catálogo de roles. Se conservará el rol actual.',
            );
          if (!snapshot.hasData) return const LinearProgressIndicator();
          return DropdownButtonFormField<String>(
            initialValue:
                snapshot.data!.any((role) => role['id'] == widget.roleId)
                ? widget.roleId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Rol del turno'),
            items: [
              const DropdownMenuItem(value: '', child: Text('Todos los roles')),
              ...snapshot.data!.map(
                (role) => DropdownMenuItem(
                  value: '${role['id']}',
                  child: Text('${role['nombre']}'),
                ),
              ),
            ],
            onChanged: (value) =>
                widget.onChanged(value == '' ? null : value, widget.schedules),
          );
        },
      ),
      const SizedBox(height: 16),
      const Text('Horario por día · hora de Perú'),
      for (var index = 0; index < widget.schedules.length; index++)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _days[widget.schedules[index]['diaSemana'] as int],
                  ),
                  value: widget.schedules[index]['activo'] == true,
                  onChanged: (value) => _change(index, 'activo', value),
                ),
                if (widget.schedules[index]['activo'] == true)
                  Wrap(
                    spacing: 12,
                    children: [
                      for (final field in ['horaInicio', 'horaFin'])
                        OutlinedButton(
                          onPressed: () async {
                            final minutes =
                                widget.schedules[index][field] as int;
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: minutes ~/ 60,
                                minute: minutes % 60,
                              ),
                            );
                            if (picked != null && mounted)
                              _change(
                                index,
                                field,
                                picked.hour * 60 + picked.minute,
                              );
                          },
                          child: Text(
                            '${field == 'horaInicio' ? 'Entrada' : 'Salida'} ${_clock(widget.schedules[index][field] as int)}',
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      const Text(
        'La salida se registra automáticamente al finalizar el turno; el QR registra una entrada diaria.',
      ),
    ],
  );
}
