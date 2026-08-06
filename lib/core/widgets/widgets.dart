/// BarBeer — Exportación centralizada de todos los widgets del Design System
/// 
/// Uso: import 'package:barbeer/core/widgets/widgets.dart';

// ── Design System nuevo (DS prefix) ──────────────────────────────────────────
export 'ds_card.dart';
export 'ds_button.dart';
export 'ds_list_tile.dart';
export 'ds_inputs.dart';
export 'ds_states.dart';
export 'ds_product_image.dart';

// ── Componentes legacy compatibles ───────────────────────────────────────────
export 'app_header.dart';
export 'app_states.dart';
export 'app_dialogs.dart';
export 'app_card.dart';
export 'app_text_field.dart';
export 'app_ui_components.dart';
export 'app_badge.dart';
// app_buttons.dart exporta PrimaryButton — no exportar app_button.dart para evitar conflicto
export 'app_buttons.dart';

// ── Utils ────────────────────────────────────────────────────────────────────
export '../utils/permission_guard.dart';
