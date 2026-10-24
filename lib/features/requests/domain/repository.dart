import 'package:hrflow_mobile/shared/domain/cases.dart';
import 'package:hrflow_mobile/features/workflows/domain/repository.dart';
import 'package:hrflow_mobile/features/attachments/domain/repository.dart';

abstract interface class RequestsRepository
    implements CaseGateway, WorkflowRepository, AttachmentsRepository {}
