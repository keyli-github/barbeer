import 'package:barbeer/core/constants/api_constants.dart';
import 'package:barbeer/core/network/api_client.dart';
import 'package:barbeer/features/caja/data/caja_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reenviarReporte posts to the authorized close-report endpoint', () async {
    final paths = <String>[];
    final repository = CajaRepository(
      ApiClient.instance,
      postRequest: (path) async {
        paths.add(path);
        return const {'queued': true};
      },
    );

    await repository.reenviarReporte('closed-session-1');

    expect(paths, [ApiConstants.cajaReporteReenvio('closed-session-1')]);
  });
}
