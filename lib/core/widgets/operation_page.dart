import 'package:flutter/material.dart';
import '../errors/app_exception.dart';

/// Shared layout for paged operational lists. Cards reflow without fixed heights.
class OperationPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final Object? error;
  final int page;
  final int pages;
  final List<Widget> filters;
  final List<Widget> cards;
  final Future<void> Function() reload;
  final void Function(int) onPage;
  final VoidCallback? onCreate;
  const OperationPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.error,
    required this.page,
    required this.pages,
    required this.filters,
    required this.cards,
    required this.reload,
    required this.onPage,
    this.onCreate,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: onCreate == null
        ? null
        : FloatingActionButton.extended(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: reload,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth >= 700 ? 32 : 16,
              vertical: 20,
            ),
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              ...filters.expand(
                (filter) => [filter, const SizedBox(height: 12)],
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          error is AppException
                              ? (error as AppException).message
                              : 'No se pudieron cargar los datos.',
                        ),
                        TextButton.icon(
                          onPressed: reload,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (cards.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text('No hay registros para estos filtros.'),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth >= 1000
                        ? 3
                        : box.maxWidth >= 650
                        ? 2
                        : 1;
                    final width = (box.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: cards
                          .map((card) => SizedBox(width: width, child: card))
                          .toList(),
                    );
                  },
                ),
              if (!loading && error == null && pages > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Anterior',
                        onPressed: page > 1 ? () => onPage(page - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Flexible(child: Text('$page / $pages')),
                      IconButton(
                        tooltip: 'Siguiente',
                        onPressed: page < pages ? () => onPage(page + 1) : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    ),
  );
}
