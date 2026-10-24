import '../protocol.dart';
import 'storage.dart';

abstract interface class ApiClient {
  bool get isLocal;
  int get workspaceRevision;
  String get namespace;
  SecretStore get secrets;
  Future<DataResponse> request(DataRequest request);
  Future<void> clearCache();
}
