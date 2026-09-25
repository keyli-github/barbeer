import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/sede_scope_provider.dart';
import '../../../core/widgets/operation_form.dart';
import '../../../core/widgets/operation_page.dart';
import '../../../core/widgets/sede_scope_selector.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../operaciones/data/operations_repository.dart';

final internalAssetsProvider = FutureProvider.autoDispose
    .family<OperationsPage, (int, String, String?)>((ref, query) {
      ref.watch(authProvider.select((state) => state.user?.id));
      return ref
          .watch(operationsRepositoryProvider)
          .list(
            '/productos-internos',
            sedeId: ref.watch(globalSedeIdProvider),
            page: query.$1,
            filters: {'q': query.$2, 'estado': ?query.$3},
          );
    });

class ProductosInternosScreen extends ConsumerStatefulWidget {
  const ProductosInternosScreen({super.key});
  @override
  ConsumerState<ProductosInternosScreen> createState() =>
      _ProductosInternosScreenState();
}

class _ProductosInternosScreenState
    extends ConsumerState<ProductosInternosScreen> {
  int _page = 1;
  String _search = '';
  String? _status;
  bool _busy = false;
  static const _states = {
    'OPERATIVO': 'Operativo',
    'MANTENIMIENTO': 'Mantenimiento',
    'BAJA': 'De baja',
  };
  void _reload() => ref.invalidate(internalAssetsProvider);

  Future<void> _edit([OperationJson? item]) async {
    final sede = ref.read(globalSedeIdProvider);
    if (item == null && sede == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona una sede para agregar un producto interno.',
          ),
        ),
      );
      return;
    }
    final name = TextEditingController(text: item?['nombre'] as String?);
    final category = TextEditingController(text: item?['categoria'] as String?);
    final description = TextEditingController(
      text: item?['descripcion'] as String?,
    );
    final location = TextEditingController(text: item?['ubicacion'] as String?);
    final quantity = TextEditingController(text: '${item?['cantidad'] ?? 1}');
    final cost = TextEditingController(text: '${item?['costo'] ?? 0}');
    String status = item?['estado'] as String? ?? 'OPERATIVO';
    bool active = item?['activo'] as bool? ?? true;
    await OperationForm.show(
      context,
      OperationForm(
        title: item == null
            ? 'Nuevo producto interno'
            : 'Editar producto interno',
        fields: (refresh) => [
          operationText(name, 'Nombre', maxLength: 120),
          operationText(category, 'Categoría', maxLength: 80, required: false),
          operationText(
            description,
            'Descripción',
            maxLength: 500,
            required: false,
          ),
          TextFormField(
            controller: quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
            validator: (value) {
              final n = int.tryParse(value ?? '');
              return n == null || n < 1 || n > 100000
                  ? 'Ingresa de 1 a 100000 unidades'
                  : null;
            },
          ),
          operationText(cost, 'Costo (S/)', money: true, allowZero: true),
          operationText(location, 'Ubicación', maxLength: 120, required: false),
          DropdownButtonFormField<String>(
            initialValue: status,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Estado'),
            items: _states.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (value) {
              status = value!;
              refresh();
            },
          ),
          if (item != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: active,
              onChanged: (value) {
                active = value;
                refresh();
              },
            ),
        ],
        onSave: () async {
          final payload = {
            'nombre': name.text.trim(),
            'categoria': category.text.trim(),
            'descripcion': description.text.trim(),
            'cantidad': int.parse(quantity.text),
            'costo': moneyValue(cost.text),
            'ubicacion': location.text.trim(),
            'estado': status,
          };
          final repo = ref.read(operationsRepositoryProvider);
          if (item == null) {
            await repo.create('/productos-internos', {
              ...payload,
              'sedeId': sede,
            });
          } else {
            await repo.update('/productos-internos/${item['id']}', {
              ...payload,
              'activo': active,
            });
          }
          _reload();
        },
      ),
    );
    for (final controller in [
      name,
      category,
      description,
      location,
      quantity,
      cost,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _action(OperationJson item, String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(operationsRepositoryProvider);
      final path = '/productos-internos/${item['id']}';
      if (action == 'image') {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
          withData: true,
        );
        final file = picked?.files.single;
        if (file?.bytes == null) return;
        await repo.uploadAssetImage('${item['id']}', file!.bytes!, file.name);
      } else {
        if (!await confirmOperation(
          context,
          action == 'removeImage' ? 'Eliminar imagen' : 'Eliminar producto',
          '${item['nombre']}',
        ))
          return;
        await repo.remove(action == 'removeImage' ? '$path/imagen' : path);
      }
      _reload();
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalSedeIdProvider, (_, __) => setState(() => _page = 1));
    final auth = ref.watch(authProvider);
    final result = ref.watch(internalAssetsProvider((_page, _search, _status)));
    final data = result.valueOrNull;
    return OperationPage(
      title: 'Productos internos',
      subtitle: 'Mobiliario, equipos y bienes de cada sede',
      loading: result.isLoading,
      error: result.error,
      page: _page,
      pages: data?.pages ?? 1,
      reload: () async => _reload(),
      onPage: (page) => setState(() => _page = page),
      onCreate: auth.hasPermission('productos-internos:crear')
          ? () => _edit()
          : null,
      filters: [
        const SedeScopeSelector(),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar producto',
            prefixIcon: Icon(Icons.search),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => setState(() {
            _search = value.trim();
            _page = 1;
          }),
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: _status == null,
              onSelected: (_) => setState(() {
                _status = null;
                _page = 1;
              }),
            ),
            ..._states.entries.map(
              (e) => ChoiceChip(
                label: Text(e.value),
                selected: _status == e.key,
                onSelected: (_) => setState(() {
                  _status = e.key;
                  _page = 1;
                }),
              ),
            ),
          ],
        ),
      ],
      cards: (data?.items ?? [])
          .map(
            (item) => Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item['imagenUrl'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          '${item['thumbnailUrl'] ?? item['imagenUrl']}',
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 80,
                            child: Center(
                              child: Icon(Icons.inventory_2_outlined, size: 36),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '${item['nombre']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${item['categoria'] ?? 'Sin categoría'} · ${item['cantidad']} unidades',
                    ),
                    Text('Costo: ${soles(item['costo'])}'),
                    if (item['ubicacion'] != null) Text('${item['ubicacion']}'),
                    Text('${objectValue(item['sede'])['nombre'] ?? ''}'),
                    Chip(
                      label: Text(
                        item['activo'] == false
                            ? 'Inactivo'
                            : _states[item['estado']] ?? '${item['estado']}',
                      ),
                    ),
                    Wrap(
                      children: [
                        if (auth.hasPermission(
                          'productos-internos:editar',
                        )) ...[
                          TextButton.icon(
                            onPressed: _busy ? null : () => _edit(item),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Editar'),
                          ),
                          TextButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _action(item, 'image'),
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: const Text('Imagen'),
                          ),
                          if (item['imagenUrl'] != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _action(item, 'removeImage'),
                              child: const Text('Quitar imagen'),
                            ),
                        ],
                        if (auth.hasPermission('productos-internos:eliminar'))
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _action(item, 'delete'),
                            child: const Text('Eliminar'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
