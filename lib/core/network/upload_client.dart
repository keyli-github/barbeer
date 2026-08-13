import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

import '../constants/api_constants.dart';
import 'api_client.dart';

class UploadResult {
  final String url;
  final String filename;

  const UploadResult({required this.url, required this.filename});
}

class PickedUploadImage {
  final Uint8List bytes;
  final String filename;

  const PickedUploadImage({required this.bytes, required this.filename});
}

class UploadClient {
  final ApiClient _api;

  const UploadClient(this._api);

  Future<UploadResult> uploadImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final response = await _api.postMultipart(
      ApiConstants.uploads,
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: _contentType(filename),
        ),
      }),
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    return UploadResult(
      url: json['url'] as String? ?? '',
      filename: json['filename'] as String? ?? '',
    );
  }

  MediaType _contentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }
}
