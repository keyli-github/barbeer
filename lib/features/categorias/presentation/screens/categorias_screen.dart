import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/app_nav.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_feedback.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/categoria.dart';
import '../providers/categorias_provider.dart';

/// Pantalla principal de Categorias accesible desde la navegacion del shell.
/// Replica la funcionalidad de CategoriasSheet pero sin SubPageAppBar,
/// ya que el shell provee el AppHeader.
class CategoriasScreen extends ConsumerWidget {
  const CategoriasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriasProvider);
    final auth = ref.watch(authProvider);
    final canCreate = auth.hasPermission('categorias:crear');

    return Scaffold(
      backgroundColor: context.colors.backgroundAlt,
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showForm(context, ref),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: context.colors.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AppSearchBar(
                    hint: 'Buscar categoria...',
                    onChanged: ref.read(categoriasProvider.notifier).search,
                  ),
                ),
                _CategoryFilters(state: state),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _body(context, ref, state, auth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    CategoriasState state,
    AuthState auth,
  ) {
    if (state.isLoading && state.categorias.isEmpty) {
      return const _CategorySkeleton(key: ValueKey('loading'));
    }
    if (state.error != null && state.categorias.isEmpty) {
      return AppErrorState(
        key: const ValueKey('error'),
        message: state.error!,
        onRetry: ref.read(categoriasProvider.notifier).load,
      );
    }
    if (state.categorias.isEmpty) {
      return const AppEmptyState(
        key: ValueKey('empty'),
        icon: Icons.category_outlined,
        title: 'Sin categorias',
        description: 'No hay resultados para los filtros seleccionados.',
      );
    }
    return RefreshIndicator(
      key: const ValueKey('list'),
      color: AppColors.primary,
      onRefresh: ref.read(categoriasProvider.notifier).load,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: state.categorias.length + 1,
          itemBuilder: (context, index) {
            if (index == state.categorias.length) {
              return AppPagination(
                page: state.pagina,
                totalPages: state.totalPaginas,
                total: state.total,
                onPageChange: (page) =>
                    ref.read(categoriasProvider.notifier).load(pagina: page),
              );
            }
            final categoria = state.categorias[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => _showDetail(context, ref, categoria.id),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: categoria.activo
                            ? context.colors.primarySurface
                            : context.colors.backgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.category_rounded,
                        size: 19,
                        color: categoria.activo
                            ? AppColors.primary
                            : context.colors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoria.nombre,
                            style: AppTextStyles.titleMedium,
                          ),
                          Text(
                            '${categoria.productosCount} producto${categoria.productosCount == 1 ? '' : 's'}',
                            style: AppTextStyles.labelSmall,
                          ),
                          if (categoria.descripcion?.isNotEmpty == true)
                            Text(
                              categoria.descripcion!,
                              style: AppTextStyles.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    _ActivePill(active: categoria.activo),
                    if (auth.hasPermission('categorias:editar') ||
                        auth.hasPermission('categorias:eliminar'))
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 19,
                          color: context.colors.textTertiary,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showForm(context, ref, categoria: categoria);
                          } else if (value == 'toggle') {
                            _toggle(context, ref, categoria);
                          } else {
                            _delete(context, ref, categoria);
                          }
                        },
                        itemBuilder: (_) => [
                          if (auth.hasPermission('categorias:editar'))
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                          if (auth.hasPermission('categorias:editar'))
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(
                                categoria.activo ? 'Desactivar' : 'Activar',
                              ),
                            ),
                          // 'delete' (baja lógica) es idéntico a desactivar:
                          // se omite para evitar la opción duplicada.
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    try {
      final categoria = await ref.read(categoriasProvider.notifier).detail(id);
      if (!context.mounted) return;
      await AppBottomSheet.show<void>(
        context: context,
        title: categoria.nombre,
        subtitle: categoria.activo ? 'Categoria activa' : 'Categoria inactiva',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: 'ID', value: categoria.id),
            _DetailRow(
              label: 'Descripcion',
              value: categoria.descripcion?.isNotEmpty == true
                  ? categoria.descripcion!
                  : 'Sin descripcion',
            ),
            _DetailRow(
              label: 'Productos',
              value: '${categoria.productosCount}',
            ),
            if (categoria.createdAt != null)
              _DetailRow(label: 'Creada', value: _date(categoria.createdAt!)),
            if (categoria.updatedAt != null)
              _DetailRow(
                label: 'Actualizada',
                value: _date(categoria.updatedAt!),
              ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) _message(context, error.toString(), error: true);
    }
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    Categoria? categoria,
  }) async {
    await AppNav.push<void>(
      context,
      _CategoriaForm(
        categoria: categoria,
        onSave:
            ({required nombre, required descripcion, required activo}) async {
              await ref
                  .read(categoriasProvider.notifier)
                  .save(
                    categoria: categoria,
                    nombre: nombre,
                    descripcion: descripcion,
                    activo: activo,
                  );
            },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Categoria categoria,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Desactivar categoria',
      description:
          'La categoria "${categoria.nombre}" dejara de estar disponible para nuevos productos.',
      confirmLabel: 'Desactivar',
      isDanger: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(categoriasProvider.notifier).delete(categoria.id);
      if (context.mounted) _message(context, 'Categoria desactivada');
    } catch (error) {
      if (context.mounted) _message(context, error.toString(), error: true);
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Categoria categoria,
  ) async {
    try {
      await ref
          .read(categoriasProvider.notifier)
          .save(
            categoria: categoria,
            nombre: categoria.nombre,
            descripcion: categoria.descripcion ?? '',
            activo: !categoria.activo,
          );
      if (context.mounted) {
        _message(
          context,
          categoria.activo ? 'Categoria desactivada' : 'Categoria activada',
        );
      }
    } catch (error) {
      if (context.mounted) _message(context, error.toString(), error: true);
    }
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  void _message(BuildContext context, String text, {bool error = false}) {
    if (error) {
      AppFeedback.error(context, text);
    } else {
      AppFeedback.success(context, text);
    }
  }
}

// ─── Filtros ──────────────────────────────────────────────────────────────────

class _CategoryFilters extends ConsumerWidget {
  final CategoriasState state;

  const _CategoryFilters({required this.state});

  static const _opciones = [
    (null, 'Todas'),
    (true, 'Activas'),
    (false, 'Inactivas'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentValue = state.activo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InputDecorator(
        key: const ValueKey('categorias-estado-filter'),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          prefixIcon: Icon(
            Icons.filter_alt_outlined,
            size: 18,
            color: context.colors.textTertiary,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 0,
          ),
          filled: true,
          fillColor: context.colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: context.colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: context.colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<bool?>(
            key: const ValueKey('categorias-estado-dropdown'),
            value: currentValue,
            isDense: true,
            isExpanded: true,
            borderRadius: BorderRadius.circular(12),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: context.colors.textTertiary,
            ),
            style: TextStyle(fontSize: 14, color: context.colors.textPrimary),
            items: _opciones
                .map(
                  (e) => DropdownMenuItem<bool?>(
                    value: e.$1,
                    child: Text(e.$2, style: const TextStyle(fontSize: 14)),
                  ),
                )
                .toList(),
            onChanged: (v) =>
                ref.read(categoriasProvider.notifier).filterActivo(v),
          ),
        ),
      ),
    );
  }
}

// ─── Form ─────────────────────────────────────────────────────────────────────

class _CategoriaForm extends StatefulWidget {
  final Categoria? categoria;
  final Future<void> Function({
    required String nombre,
    required String descripcion,
    required bool activo,
  })
  onSave;

  const _CategoriaForm({this.categoria, required this.onSave});

  @override
  State<_CategoriaForm> createState() => _CategoriaFormState();
}

class _CategoriaFormState extends State<_CategoriaForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late bool _activo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.categoria?.nombre ?? '');
    _descripcion = TextEditingController(
      text: widget.categoria?.descripcion ?? '',
    );
    _activo = widget.categoria?.activo ?? true;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    appBar: SubPageAppBar(
      title: widget.categoria == null ? 'Nueva categoria' : 'Editar categoria',
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              label: 'Nombre',
              controller: _nombre,
              maxLength: 80,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa un nombre'
                  : null,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Descripcion',
              hint: 'Opcional',
              controller: _descripcion,
              maxLength: 300,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Categoria activa',
                style: AppTextStyles.bodyMedium,
              ),
              value: _activo,
              onChanged: (value) => setState(() => _activo = value),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: widget.categoria == null
                  ? 'Crear categoria'
                  : 'Guardar cambios',
              isLoading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        nombre: _nombre.text,
        descripcion: _descripcion.text,
        activo: _activo,
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        AppFeedback.error(context, error.toString());
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _ActivePill extends StatelessWidget {
  final bool active;

  const _ActivePill({required this.active});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: active
          ? context.colors.successLight
          : context.colors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Text(
      active ? 'Activa' : 'Inactiva',
      style: AppTextStyles.labelSmall.copyWith(
        color: active ? AppColors.success : context.colors.textTertiary,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(label, style: AppTextStyles.labelLarge),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    itemBuilder: (_, index) => Container(
      height: 68,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: context.colors.borderLight),
      ),
    ),
  );
}
