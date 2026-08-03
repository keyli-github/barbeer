import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

class VentasScreen extends StatelessWidget {
  const VentasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundAlt,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded, color: AppColors.warning, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Punto de Venta', style: AppTextStyles.headlineLarge),
                        Text('POS · Ventas', style: AppTextStyles.bodySmall),
                      ])),
                    ]),
                    const SizedBox(height: 20),

                    // Aviso principal
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Módulo en desarrollo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.warning))),
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'El sistema de punto de venta aún no está disponible. El backend no implementa endpoints de ventas, órdenes, cobros ni tickets en esta versión.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    Text('¿Qué falta?', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    for (final item in [
                      (Icons.shopping_bag_rounded, 'API de creación de ventas y órdenes'),
                      (Icons.inventory_rounded, 'Descuento automático de stock por venta'),
                      (Icons.receipt_rounded, 'Generación de tickets y comprobantes'),
                      (Icons.account_balance_rounded, 'Registro transaccional en caja'),
                      (Icons.cancel_rounded, 'Anulación y devoluciones'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(color: AppColors.backgroundAlt, borderRadius: BorderRadius.circular(8)),
                            child: Icon(item.$1, size: 17, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 12),
                          Text(item.$2, style: AppTextStyles.bodyMedium),
                        ]),
                      ),
                    const SizedBox(height: 24),

                    Text('Módulos disponibles ahora', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 12),
                    for (final e in [
                      (Icons.account_balance_rounded, 'Caja', 'Apertura, movimientos y cierre', '/caja', AppColors.primary),
                      (Icons.inventory_2_rounded, 'Inventario', 'Stock y ajustes en tiempo real', '/inventario', AppColors.success),
                      (Icons.shopping_cart_rounded, 'Compras', 'Órdenes y proveedores', '/compras', AppColors.warning),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => context.go(e.$4),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.borderLight),
                              boxShadow: AppShadows.card,
                            ),
                            child: Row(children: [
                              Container(width: 40, height: 40,
                                decoration: BoxDecoration(color: e.$5.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: Icon(e.$1, color: e.$5, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.$2, style: AppTextStyles.titleMedium),
                                Text(e.$3, style: AppTextStyles.bodySmall),
                              ])),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                            ]),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
