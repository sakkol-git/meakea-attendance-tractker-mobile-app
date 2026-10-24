import 'dart:typed_data';

import 'package:hrflow_mobile/shared/domain/workflow.dart';
import 'package:hrflow_mobile/shared/domain/resource_gateway.dart';

abstract interface class AttachmentsRepository implements ResourceGateway {
  Future<void> attach(WorkflowRecord record, String name, Uint8List bytes);
  Future<Uint8List> download(
    WorkflowRecord record,
    Map<String, dynamic> attachment,
  );
}
