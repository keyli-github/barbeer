import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/etiquetas_repository.dart';

final etiquetasRepositoryProvider = Provider<EtiquetasRepository>(
  (ref) => EtiquetasRepository(ApiClient.instance),
);
