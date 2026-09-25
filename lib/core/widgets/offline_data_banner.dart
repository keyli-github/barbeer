import 'package:flutter/material.dart';
import '../network/api_client.dart';

class OfflineDataBanner extends StatelessWidget {
  final Widget child;
  const OfflineDataBanner({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      ValueListenableBuilder<bool>(
        valueListenable: offlineDataNotice,
        builder: (context, offline, _) => offline
            ? Material(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Se están mostrando datos guardados. Las operaciones pendientes se revisan en Alertas y revisiones.',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar aviso',
                        onPressed: () => offlineDataNotice.value = false,
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      Expanded(child: child),
    ],
  );
}
