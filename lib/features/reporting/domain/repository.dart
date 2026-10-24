import 'package:hrflow_mobile/shared/domain/cases.dart';

import 'dart:typed_data';

import 'package:hrflow_mobile/shared/domain/resource_gateway.dart';

abstract interface class ReportingRepository
    implements CaseGateway, ResourceGateway {
  Future<({String name, Uint8List bytes})> exportAttendance(String key);
  Future<({String name, Uint8List bytes})> downloadExport(String id);
}
