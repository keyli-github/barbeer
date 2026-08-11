# Guía del Nuevo Sistema de Diseño - BarBeer Mobile

## 📋 Resumen de Cambios

Se ha implementado un **sistema de diseño completo y profesional** para la aplicación móvil Flutter, con los siguientes objetivos:

1. ✅ **Fondo blanco limpio** en toda la aplicación
2. ✅ **Componentes reutilizables** para eliminar duplicación
3. ✅ **Header global adaptable** (hamburguesa o flecha según contexto)
4. ✅ **Sistema de permisos visuales** centralizado
5. ✅ **Diseño compacto y moderno** sin bloques grandes de color
6. ✅ **Animaciones suaves** y transiciones profesionales

---

## 🎨 Sistema de Colores

### Nuevos Colores Principales

```dart
// Color primario: Ámbar profesional
AppColors.primary = #F59E0B (amber)
AppColors.primaryDark = #D97706
AppColors.primaryLight = #FBBF24

// Fondos: Completamente blancos
AppColors.background = #FFFFFF (blanco puro)
AppColors.backgroundAlt = #FAFAFA (gris muy claro)
AppColors.surface = #FFFFFF

// Textos: Alta legibilidad
AppColors.textPrimary = #111827 (casi negro)
AppColors.textSecondary = #6B7280
AppColors.textTertiary = #9CA3AF
```

### Ubicación
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_spacing.dart` (nuevo)

---

## 🧩 Componentes Reutilizables

### 1. AppHeader - Header Global Adaptable

**Ubicación:** `lib/core/widgets/app_header.dart`

**Uso básico:**
```dart
// Pantalla principal con menú hamburguesa
AppHeader(
  title: 'Inicio',
  onMenuTap: () => Scaffold.of(context).openDrawer(),
)

// Pantalla secundaria con botón de regreso
AppHeader(
  title: 'Detalles del Producto',
  showBackButton: true,
)

// Con acciones personalizadas
AppHeader(
  title: 'Productos',
  showBackButton: true,
  actions: [
    IconButton(
      icon: Icon(Icons.search),
      onPressed: () {},
    ),
  ],
)
```

### 2. AppImage - Imágenes con Placeholder

**Ubicación:** `lib/core/widgets/app_image.dart`

**Uso:**
```dart
// Imagen rectangular
AppImage(
  imageUrl: producto.imagen,
  width: 120,
  height: 120,
  borderRadius: AppSpacing.radiusMD,
)

// Avatar circular
AppCircleImage(
  imageUrl: usuario.avatar,
  size: AppSpacing.avatarMD,
)
```

### 3. Botones Personalizados

**Ubicación:** `lib/core/widgets/app_buttons.dart`

**Tipos disponibles:**
```dart
// Botón primario
PrimaryButton(
  text: 'Guardar',
  onPressed: () {},
  icon: Icons.save,
  isLoading: false,
)

// Botón secundario (outline)
SecondaryButton(
  text: 'Cancelar',
  onPressed: () {},
)

// Botón destructivo (eliminar)
DestructiveButton(
  text: 'Eliminar',
  onPressed: () {},
  icon: Icons.delete,
)

// Botón de texto
TextButtonCustom(
  text: 'Ver más',
  onPressed: () {},
)
```

### 4. Estados de UI

**Ubicación:** `lib/core/widgets/app_states.dart`

```dart
// Estado vacío
AppEmptyState(
  icon: Icons.inventory_2_outlined,
  title: 'No hay productos',
  message: 'Agrega tu primer producto para comenzar',
  actionText: 'Agregar Producto',
  onActionPressed: () {},
)

// Estado de error
AppErrorState(
  title: 'Error al cargar',
  message: error.toString(),
  onActionPressed: () => retry(),
)

// Indicador de carga
AppLoadingIndicator(
  message: 'Cargando productos...',
)

// Sin conexión
AppNoConnectionState(
  onRetry: () => retry(),
)

// Skeleton loader para listas
SkeletonLoader(
  itemCount: 5,
  height: 80,
)
```

### 5. Diálogos y Modales

**Ubicación:** `lib/core/widgets/app_dialogs.dart`

```dart
// Confirmación
final confirmed = await ConfirmationDialog.show(
  context: context,
  title: '¿Eliminar producto?',
  message: 'Esta acción no se puede deshacer',
  confirmText: 'Eliminar',
  cancelText: 'Cancelar',
  isDestructive: true,
  icon: Icons.delete_outline,
);

if (confirmed) {
  // Realizar acción
}

// Mensaje de éxito
await SuccessMessage.show(
  context: context,
  message: 'Producto guardado correctamente',
);

// Mensaje de error
await ErrorMessage.show(
  context: context,
  message: 'No se pudo guardar el producto',
);

// Bottom sheet
await AppBottomSheet.show(
  context: context,
  title: 'Filtros',
  child: FilterWidget(),
);
```

---

## 🔒 Sistema de Permisos Visuales

**Ubicación:** `lib/core/utils/permission_guard.dart`

### Uso con PermissionGuard

```dart
// Ocultar widget si no tiene permiso
PermissionGuard(
  permissions: [Permissions.productosCrear],
  checkPermission: (p) => auth.hasPermission(p),
  child: FloatingActionButton(
    onPressed: () => _crearProducto(),
    child: Icon(Icons.add),
  ),
)

// Con fallback (mostrar alternativa)
PermissionGuard(
  permissions: [Permissions.ventasEliminar],
  checkPermission: (p) => auth.hasPermission(p),
  fallback: Text('Sin permisos'),
  child: IconButton(
    icon: Icon(Icons.delete),
    onPressed: () {},
  ),
)
```

### Uso con Extension

```dart
// Forma abreviada
FloatingActionButton(
  onPressed: () => _crearProducto(),
  child: Icon(Icons.add),
).guardWithPermission(
  Permissions.productosCrear,
  (p) => auth.hasPermission(p),
)
```

### Constantes de Permisos

En lugar de strings hardcodeados, usa las constantes:

```dart
// ❌ MAL
if (auth.hasPermission('productos:crear')) { ... }

// ✅ BIEN
if (auth.hasPermission(Permissions.productosCrear)) { ... }
```

---

## 📏 Sistema de Espaciados

**Ubicación:** `lib/core/theme/app_spacing.dart`

### Espaciados Base

```dart
AppSpacing.xxs   // 4px
AppSpacing.xs    // 8px
AppSpacing.sm    // 12px
AppSpacing.md    // 16px (más común)
AppSpacing.lg    // 20px
AppSpacing.xl    // 24px
AppSpacing.xxl   // 32px
```

### Espaciados Específicos

```dart
// Padding de pantallas
AppSpacing.screenPadding  // 16px

// Separación entre items
AppSpacing.listGap   // 12px
AppSpacing.cardGap   // 16px

// Altura de elementos
AppSpacing.buttonHeight  // 48px
AppSpacing.inputHeight   // 48px
AppSpacing.appBarHeight  // 56px

// Radios de borde
AppSpacing.radiusXS   // 4px
AppSpacing.radiusSM   // 6px
AppSpacing.radiusMD   // 8px (más común)
AppSpacing.radiusLG   // 12px
AppSpacing.radiusXL   // 16px
AppSpacing.radiusRound // 999px (circular)

// Iconos
AppSpacing.iconSM  // 20px
AppSpacing.iconMD  // 24px (estándar)
AppSpacing.iconLG  // 28px

// Avatares
AppSpacing.avatarSM  // 32px
AppSpacing.avatarMD  // 40px
AppSpacing.avatarLG  // 48px
```

---

## 📱 Pantallas Rediseñadas

### 1. Login Screen

**Archivo:** `lib/features/auth/presentation/screens/login_screen.dart`

✅ **Cambios aplicados:**
- Logo en contenedor con bordes redondeados
- Tarjeta de login compacta con sombras sutiles
- Fondo blanco completamente limpio
- Mensajes de error con íconos y colores semánticos
- Footer discreto

### 2. Dashboard Screen

**Archivo:** `lib/features/dashboard/presentation/screens/dashboard_screen.dart`

✅ **Cambios aplicados:**
- Eliminado bloque grande azul de bienvenida
- Tarjeta de bienvenida compacta (1 línea)
- Grid 2x2 de estadísticas con íconos en contenedores de color
- Todas las tarjetas con fondo blanco y borde sutil
- Espaciado consistente
- AppHeader con hamburguesa

---

## 🚀 Guía de Implementación para Nuevas Pantallas

### Estructura Recomendada

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/widgets.dart';

class MiPantallaScreen extends ConsumerWidget {
  const MiPantallaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(
        title: 'Mi Pantalla',
        showBackButton: true, // o onMenuTap si es principal
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // Contenido aquí
          ],
        ),
      ),
    );
  }
}
```

### Tarjeta Estándar

```dart
Container(
  padding: EdgeInsets.all(AppSpacing.md),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
    border: Border.all(color: AppColors.border, width: 1),
    boxShadow: AppShadows.card, // opcional
  ),
  child: Column(
    children: [
      // Contenido
    ],
  ),
)
```

---

## ✅ Checklist para Nuevas Pantallas

- [ ] Usar `AppColors.background` como fondo del Scaffold
- [ ] Implementar `AppHeader` en lugar de AppBar manual
- [ ] Usar `AppSpacing` para todos los paddings/margins
- [ ] Aplicar `PermissionGuard` en elementos con restricciones
- [ ] Usar componentes reutilizables (`AppImage`, `PrimaryButton`, etc.)
- [ ] Implementar estados correctos (`AppLoadingIndicator`, `AppErrorState`, `AppEmptyState`)
- [ ] Usar constantes de `Permissions` en lugar de strings
- [ ] Probar con diferentes tamaños de pantalla
- [ ] Verificar en modo `--profile` (no `--debug`)

---

## 📦 Importación Simplificada

En lugar de importar múltiples widgets:

```dart
// ❌ Antes
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/app_image.dart';
import '../../../../core/widgets/app_buttons.dart';
import '../../../../core/widgets/app_states.dart';

// ✅ Ahora
import '../../../../core/widgets/widgets.dart';
```

---

## 🎯 Próximos Pasos Recomendados

1. **Aplicar rediseño a módulos prioritarios:**
   - Productos (con soporte de imágenes)
   - Ventas
   - Inventario

2. **Actualizar navegación:**
   - Shell screen
   - Drawer menu

3. **Formularios:**
   - Crear componentes de formulario reutilizables
   - Validaciones consistentes

4. **Testing:**
   - Probar en dispositivos reales
   - Verificar performance en modo `--profile`
   - Probar con diferentes roles de usuario

---

## 📞 Patrones de Uso Comunes

### Pantalla con Lista

```dart
body: RefreshIndicator(
  color: AppColors.primary,
  onRefresh: () => _reload(),
  child: SingleChildScrollView(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Column(
      children: [
        if (isLoading)
          SkeletonLoader(itemCount: 5)
        else if (error != null)
          AppErrorState(
            message: error,
            onActionPressed: () => _reload(),
          )
        else if (items.isEmpty)
          AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No hay elementos',
          )
        else
          ...items.map((item) => _buildCard(item)),
      ],
    ),
  ),
)
```

### FAB con Permisos

```dart
floatingActionButton: FloatingActionButton(
  onPressed: () => _crear(),
  child: Icon(Icons.add),
).guardWithPermission(
  Permissions.productosCrear,
  (p) => ref.read(authProvider).hasPermission(p),
),
```

---

## 🐛 Problemas Conocidos

1. **cached_network_image**: Si no está instalado, agregarlo a `pubspec.yaml`:
   ```yaml
   dependencies:
     cached_network_image: ^3.3.1
   ```

2. **AppDimensions deprecado**: Usar `AppSpacing` en su lugar

3. **AppTextStyles**: Mantener por ahora, pero migrar gradualmente a estilos inline con constantes

---

**Autor:** Sistema de Diseño BarBeer
**Versión:** 1.0.0  
**Fecha:** 2026-08-06
