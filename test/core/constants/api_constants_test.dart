import 'package:barbeer/core/constants/api_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the local API unless a build-time override is provided', () {
    expect(ApiConstants.baseUrl, ApiConstants.localBaseUrl);
  });
}
