import 'package:flutter/foundation.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  String? _pendingLocation;
  String? get pendingLocation => _pendingLocation;
  void remember(String location) => _pendingLocation ??= location;
  void clearPending() => _pendingLocation = null;
  void refresh() => notifyListeners();
}
