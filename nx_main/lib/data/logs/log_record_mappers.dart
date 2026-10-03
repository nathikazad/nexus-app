import 'package:nx_db/nx_db.dart' as nx;
import '../../domain/logs/log_records.dart';

NexusLogRow nexusLogRowFromNx(nx.NexusLogRow row) => NexusLogRow(
      id: row.id,
      time: row.time,
      receivedAt: row.receivedAt,
      originKind: row.originKind,
      origin: row.origin,
      severity: row.severity,
      message: row.message,
      userId: row.userId,
      deviceId: row.deviceId,
      sessionId: row.sessionId,
      traceId: row.traceId,
      eventName: row.eventName,
      category: row.category,
      payload: row.payload,
    );

DbChangeOperation dbChangeOperationFromNx(nx.DbChangeOperation row) =>
    DbChangeOperation(
      id: row.id,
      createdAt: row.createdAt,
      sourceKind: row.sourceKind,
      sourceId: row.sourceId,
      sourceLabel: row.sourceLabel,
      userId: row.userId,
      domainId: row.domainId,
      txid: row.txid,
      reversalOfOperationId: row.reversalOfOperationId,
      reversedByOperationId: row.reversedByOperationId,
      reversedAt: row.reversedAt,
    );

DbChangeEvent dbChangeEventFromNx(nx.DbChangeEvent row) => DbChangeEvent(
      id: row.id,
      operationId: row.operationId,
      occurredAt: row.occurredAt,
      tableName: row.tableName,
      op: row.op,
      rowPk: row.rowPk,
      beforeRow: row.beforeRow,
      afterRow: row.afterRow,
    );

DbChangeMetadata dbChangeMetadataFromNx(nx.DbChangeMetadata row) =>
    DbChangeMetadata(
      modelTypes: row.modelTypes,
      attributeDefinitions: row.attributeDefinitions,
      relationshipTypes: row.relationshipTypes,
      relationAttributeDefinitions: row.relationAttributeDefinitions,
    );
