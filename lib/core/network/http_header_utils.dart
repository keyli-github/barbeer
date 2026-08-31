import 'dart:typed_data';

/// Parsed HTTP response with header metadata for file downloads.
class HttpBytesResponse {
  final Uint8List bytes;
  final String? contentDisposition;
  final String? contentType;
  const HttpBytesResponse({
    required this.bytes,
    this.contentDisposition,
    this.contentType,
  });
}

/// Extracts the filename parameter from a Content-Disposition header.
/// Returns null if the header is absent or has no filename.
String? parseContentDispositionFilename(String? header) {
  if (header == null || header.isEmpty) return null;
  final match =
      RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(header);
  return match?.group(1);
}
