import 'package:hrflow_mobile/core/protocol.dart';

void validateClientConfiguration({
  required bool release,
  required String dataSource,
  required bool allowDemoRelease,
  String apiBaseUrl = '',
}) {
  if (!{'local', 'remote'}.contains(dataSource)) {
    throw const DataFailure(
      0,
      'INVALID_MODE',
      'DATA_SOURCE must be local or remote.',
    );
  }
  if (release && dataSource == 'local' && !allowDemoRelease) {
    throw const DataFailure(
      0,
      'DEMO_RELEASE_BLOCKED',
      'Release builds require DATA_SOURCE=remote. Set ALLOW_DEMO_RELEASE=true only for an explicitly labeled demonstration build.',
    );
  }
  if (dataSource != 'remote') return;

  final url = Uri.tryParse(apiBaseUrl);
  final loopback =
      url != null &&
      {'localhost', '127.0.0.1', '::1'}.contains(url.host.toLowerCase());
  final safe =
      url != null &&
      url.hasScheme &&
      url.hasAuthority &&
      (url.scheme == 'https' || loopback && url.scheme == 'http') &&
      url.userInfo.isEmpty &&
      !url.hasQuery &&
      !url.hasFragment &&
      url.path.replaceFirst(RegExp(r'/$'), '').endsWith('/api/v1');
  if (!safe) {
    throw const DataFailure(
      0,
      'INVALID_API_URL',
      'API_BASE_URL must use HTTPS, end in /api/v1, and contain no credentials, query, or fragment. HTTP is allowed only for loopback development.',
    );
  }
}
