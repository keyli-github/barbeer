import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_ui_components.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/categoria.dart';
import '../providers/categorias_provider.dart';

class CategoriasSheet extends ConsumerWidget {
  const CategoriasSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const CategoriasSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(categoriasProvider);
    final auth = ref.watch(authProvider);
    final canCreate = auth.hasPermission('categorias:crear');

    return Container(
      height: MediaQuery.sizeOf(context).height * .92,
      decoration: const BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppRadius.xl),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Categorias',
                                style: AppTextStyles.headlineMedium,
                              ),
                              Text(
                                'Organiza el catalogo global',
                                style: AppTextStyles.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        if (canCreate)
                          FilledButton.icon(
                            onPressed: () => _showForm(context, ref),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Nueva'),
                          ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: state.categorias.length + 1,
          itemBuilder: (context, index) {
            if (index == state.categorias.length) {
              return _Pager(
                page: state.pagina,
                totalPages: state.totalPaginas,
                total: state.total,
                onPage: (page) =>
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
                            ? AppColors.primarySurface
                            : AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.category_rounded,
                        size: 19,
                        color: categoria.activo
                            ? AppColors.primary
                            : AppColors.textTertiary,
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
                        ],
                      ),
                    ),
                    _ActivePill(active: categoria.activo),
                    if (auth.hasPermission('categorias:editar') ||
                        auth.hasPermission('categorias:eliminar'))
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          size: 19,
                          color: AppColors.textTertiary,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showForm(context, ref, categoria: categoria);
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
                          if (auth.hasPermission('categorias:eliminar') &&
                              categoria.activo)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Desactivar',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategoriaForm(
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

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  void _message(BuildContext context, String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.error : null,
      ),
    );
  }
}

class _CategoryFilters extends ConsumerWidget {
  final CategoriasState state;

  const _CategoryFilters({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _FilterChip(
            label: 'Todas',
            selected: state.activo == null,
            onTap: () =>
                ref.read(categoriasProvider.notifier).filterActivo(null),
          ),
          _FilterChip(
            label: 'Activas',
            selected: state.activo == true,
            onTap: () =>
                ref.read(categoriasProvider.notifier).filterActivo(true),
          ),
          _FilterChip(
            label: 'Inactivas',
            selected: state.activo == false,
            onTap: () =>
                ref.read(categoriasProvider.notifier).filterActivo(false),
          ),
        ],
      ),
    ),
  );
}

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
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.categoria == null
                          ? 'Nueva categoria'
                          : 'Editar categoria',
                      style: AppTextStyles.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 7),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.full),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySurface : AppColors.backgroundAlt,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? AppColors.primaryBorder : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    ),
  );
}

class _ActivePill extends StatelessWidget {
  final bool active;

  const _ActivePill({required this.active});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: active ? AppColors.successLight : AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(AppRadius.full),
    ),
    child: Text(
      active ? 'Activa' : 'Inactiva',
      style: AppTextStyles.labelSmall.copyWith(
        color: active ? AppColors.success : AppColors.textTertiary,
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
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}

class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final int total;
  final ValueChanged<int> onPage;

  const _Pager({
    required this.page,
    required this.totalPages,
    required this.total,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      children: [
        Text('$total resultados', style: AppTextStyles.labelSmall),
        const Spacer(),
        IconButton.filledTonal(
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          '$page / ${totalPages == 0 ? 1 : totalPages}',
          style: AppTextStyles.labelLarge,
        ),
        IconButton.filledTonal(
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight),
      ),
    ),
  );
}
