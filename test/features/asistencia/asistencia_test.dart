import 'package:flutter_test/flutter_test.dart';
import 'package:barbeer/features/asistencia/data/asistencia_repository.dart';
import 'package:barbeer/features/asistencia/presentation/screens/asistencia_screen.dart';
import 'package:barbeer/features/auth/presentation/providers/auth_provider.dart';
import 'package:barbeer/features/auth/data/models/auth_models.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

UserProfile _makeUser({
  required String rol,
  List<String> permisos = const [],
}) => UserProfile(
  id: 'u-test',
  username: 'test',
  rol: rol,
  nivel: 10,
  createdAt: '2026-01-01',
  permisos: permisos,
);

AuthState _authWith(UserProfile user) =>
    AuthState(status: AuthStatus.authenticated, user: user);

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  test('desktop attendance layout starts at 1024 logical pixels', () {
    expect(usesAsistenciaDesktopLayout(1023), isFalse);
    expect(usesAsistenciaDesktopLayout(1024), isTrue);
  });

  group('Turno backend contract', () {
    test(
      'fromJson parses minutes-from-midnight and derives formatted labels',
      () {
        final turno = Turno.fromJson({
          'id': 't-1',
          'sedeId': 'sede-1',
          'nombre': 'Turno Mañana',
          'horaInicio': 480, // 08:00
          'horaFin': 960, // 16:00
          'margenTardanza': 10,
          'activo': true,
        });

        expect(turno.id, 't-1');
        expect(turno.nombre, 'Turno Mañana');
        expect(turno.horaInicio, 480);
        expect(turno.horaFin, 960);
        expect(turno.margenTardanza, 10);
        expect(turno.horaInicioLabel, '08:00');
        expect(turno.horaFinLabel, '16:00');
        expect(turno.cruzaMedianoche, isFalse);
      },
    );

    test('cruzaMedianoche is true when horaFin is before horaInicio', () {
      final nocturno = Turno.fromJson({
        'id': 't-2',
        'sedeId': 'sede-1',
        'nombre': 'Turno Nocturno',
        'horaInicio': 1320, // 22:00
        'horaFin': 360, // 06:00 next day
        'margenTardanza': 15,
        'activo': true,
      });

      expect(nocturno.cruzaMedianoche, isTrue);
      expect(nocturno.horaInicioLabel, '22:00');
      expect(nocturno.horaFinLabel, '06:00');
    });

    test('fromJson uses safe defaults for missing fields', () {
      final minimal = Turno.fromJson({
        'id': 't-3',
        'sedeId': 'sede-1',
        'nombre': 'Parcial',
      });

      expect(minimal.horaInicio, 0);
      expect(minimal.horaFin, 0);
      expect(minimal.margenTardanza, 15);
      expect(minimal.activo, isTrue);
    });
  });

  group('AsistenciaPlanilla backend contract', () {
    test('fromJson reads nested sede as sedeId and sedeName', () {
      final planilla = AsistenciaPlanilla.fromJson({
        'usuarioId': 'u-1',
        'username': 'maria.gomez',
        'rol': 'CAJERO',
        'fecha': '2026-08-13',
        'estado': 'PRESENTE',
        'sede': {'id': 'sede-centro', 'nombre': 'Centro'},
        'asistenciaId': 'asist-1',
        'turno': 'Turno Mañana',
        'horaEntrada': '08:05',
        'horaSalida': '16:02',
        'notas': null,
        'horasTrabajadas': 7.95,
      });

      expect(planilla.username, 'maria.gomez');
      expect(planilla.sedeId, 'sede-centro');
      expect(planilla.sedeName, 'Centro');
      expect(planilla.estado, 'PRESENTE');
      expect(planilla.turno, 'Turno Mañana');
      expect(planilla.horaEntrada, '08:05');
      expect(planilla.horasTrabajadas, 7.95);
    });

    test('fromJson defaults to AUSENTE and handles absent optional fields', () {
      final absent = AsistenciaPlanilla.fromJson({
        'usuarioId': 'u-2',
        'username': 'pedro.rios',
        'rol': 'VENDEDORA',
        'fecha': '2026-08-13',
        'estado': 'AUSENTE',
      });

      expect(absent.estado, 'AUSENTE');
      expect(absent.sedeId, isNull);
      expect(absent.sedeName, isNull);
      expect(absent.asistenciaId, isNull);
      expect(absent.horasTrabajadas, isNull);
    });
  });

  group('QR kiosco and marcaje contract', () {
    test(
      'QrKioscoResponse fromJson maps token, sedeId, and expiraEnSegundos',
      () {
        final qr = QrKioscoResponse.fromJson({
          'token': 'eyJhbGciOiJIUzI1NiJ9.abc',
          'sedeId': 'sede-centro',
          'fecha': '2026-08-13',
          'expiraEnSegundos': 300,
        });

        expect(qr.token, 'eyJhbGciOiJIUzI1NiJ9.abc');
        expect(qr.sedeId, 'sede-centro');
        expect(qr.fecha, '2026-08-13');
        expect(qr.expiraEnSegundos, 300);
      },
    );

    test(
      'MarcajeQrResponse fromJson maps tipo ENTRADA/SALIDA and horasTrabajadas',
      () {
        final entrada = MarcajeQrResponse.fromJson({
          'tipo': 'ENTRADA',
          'username': 'maria.gomez',
          'estado': 'PUNTUAL',
          'turno': 'Turno Mañana',
          'hora': '08:03',
          'horasTrabajadas': null,
          'mensaje': 'Entrada registrada correctamente',
        });

        final salida = MarcajeQrResponse.fromJson({
          'tipo': 'SALIDA',
          'username': 'maria.gomez',
          'estado': 'TARDANZA',
          'turno': 'Turno Mañana',
          'hora': '16:15',
          'horasTrabajadas': 8.2,
          'mensaje': 'Salida registrada con leve tardanza',
        });

        expect(entrada.tipo, 'ENTRADA');
        expect(entrada.estado, 'PUNTUAL');
        expect(entrada.horasTrabajadas, isNull);
        expect(salida.tipo, 'SALIDA');
        expect(salida.estado, 'TARDANZA');
        expect(salida.horasTrabajadas, 8.2);
      },
    );
  });

  group('AsistenciaResumen backend contract', () {
    test('fromJson maps all daily summary stats fields', () {
      final resumen = AsistenciaResumen.fromJson({
        'fecha': '2026-08-13',
        'totalEmpleados': 12,
        'presente': 8,
        'tardanza': 2,
        'diaLibre': 1,
        'ausente': 1,
      });

      expect(resumen.fecha, '2026-08-13');
      expect(resumen.totalEmpleados, 12);
      expect(resumen.presente, 8);
      expect(resumen.tardanza, 2);
      expect(resumen.diaLibre, 1);
      expect(resumen.ausente, 1);
      expect(
        resumen.presente +
            resumen.tardanza +
            resumen.diaLibre +
            resumen.ausente,
        resumen.totalEmpleados,
      );
    });
  });

  group('Asistencia authorization matrix', () {
    test(
      'authenticated CAJERO can access /asistencia without extra permission',
      () {
        final auth = _authWith(
          _makeUser(rol: 'CAJERO', permisos: ['caja:leer']),
        );
        expect(auth.canAccess('/asistencia'), isTrue);
      },
    );

    test(
      'authenticated VENDEDORA can access /asistencia (open authenticated)',
      () {
        final auth = _authWith(
          _makeUser(
            rol: 'VENDEDORA',
            permisos: ['ventas:crear', 'ventas:leer-propias'],
          ),
        );
        expect(auth.canAccess('/asistencia'), isTrue);
      },
    );
  });
}
