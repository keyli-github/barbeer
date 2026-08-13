enum EtiquetaTipo {
  entrada('ENTRADA', 'Entrada'),
  salida('SALIDA', 'Salida'),
  ambos('AMBOS', 'Ambos');

  const EtiquetaTipo(this.value, this.label);

  final String value;
  final String label;

  static EtiquetaTipo fromJson(Object? value) => values.firstWhere(
    (tipo) => tipo.value == value,
    orElse: () => EtiquetaTipo.entrada,
  );
}

class Etiqueta {
  const Etiqueta({
    required this.id,
    required this.nombre,
    required this.activo,
    this.sedeId,
    required this.requiereComprobante,
    required this.tipo,
    required this.esSistema,
    required this.orden,
  });

  final String id;
  final String nombre;
  final bool activo;
  final String? sedeId;
  final bool requiereComprobante;
  final EtiquetaTipo tipo;
  final bool esSistema;
  final int orden;

  factory Etiqueta.fromJson(Map<String, dynamic> json) => Etiqueta(
    id: json['id'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    activo: json['activo'] as bool? ?? true,
    sedeId: json['sedeId'] as String?,
    requiereComprobante: json['requiereComprobante'] as bool? ?? true,
    tipo: EtiquetaTipo.fromJson(json['tipo']),
    esSistema: json['esSistema'] as bool? ?? false,
    orden: (json['orden'] as num?)?.toInt() ?? 0,
  );
}
