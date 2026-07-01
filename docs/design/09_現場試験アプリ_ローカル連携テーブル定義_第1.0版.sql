/*
現場試験アプリ ローカル連携テーブル定義 第1.0版

実行先:
- Labonity Provider: Sync Agent設定で指定した LibLocal.xml から解決した LibertyDatabaseSetting.xml の p_出荷管理データベース名。
- Liberty Provider: Sync Agent設定で指定した LIBLocal.Ini から解決した LIBCTRL.ini の 出荷データＤＢ名。

固定方針:
- 両Providerとも、解決した出荷DB内の固定スキーマ FieldTest へ登録する。
- スキーマ名 FieldTest は第1.0版では変更不可である。
- 既存出荷テーブル、既存フレッシュテーブル、写真台帳DB、品質系DBへSync Agentが直接結果を書き込まない。
- SQL Server名が空欄の場合は本DDL実行前のProvider診断で停止する。localhost 等への補完やfallbackは行わない。
*/

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET XACT_ABORT ON;
GO

/* ============================================================
   V001_CoreSchema
   ============================================================ */
BEGIN TRANSACTION;

IF SCHEMA_ID(N'FieldTest') IS NULL
    EXEC(N'CREATE SCHEMA FieldTest');

IF OBJECT_ID(N'FieldTest.SchemaMigration', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.SchemaMigration(
        migration_id nvarchar(64) NOT NULL CONSTRAINT PK_FieldTestSchemaMigration PRIMARY KEY,
        applied_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestSchemaMigration_applied_at DEFAULT SYSUTCDATETIME(),
        checksum_sha256 char(64) NOT NULL,
        description nvarchar(300) NOT NULL
    );
END;

IF OBJECT_ID(N'FieldTest.ProviderConfigSnapshot', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.ProviderConfigSnapshot(
        provider_config_snapshot_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestProviderConfigSnapshot PRIMARY KEY DEFAULT NEWID(),
        provider nvarchar(20) NOT NULL CONSTRAINT CK_FieldTestProviderConfigSnapshot_provider CHECK(provider IN (N'Labonity', N'Liberty')),
        tenant_id uniqueidentifier NOT NULL,
        org_id uniqueidentifier NOT NULL,
        plant_id uniqueidentifier NOT NULL,
        plant_code nvarchar(32) NULL,
        entry_config_path nvarchar(1000) NOT NULL,
        derived_config_path nvarchar(1000) NOT NULL,
        entry_config_sha256 char(64) NULL,
        derived_config_sha256 char(64) NULL,
        sql_server_name_masked nvarchar(256) NOT NULL,
        master_database_name sysname NOT NULL,
        shipping_database_name sysname NOT NULL,
        settings_source nvarchar(40) NULL,
        settings_database_name sysname NULL,
        ignored_database_names_json nvarchar(max) NULL,
        diagnostic_status nvarchar(30) NOT NULL CONSTRAINT DF_FieldTestProviderConfigSnapshot_status DEFAULT N'Pending',
        diagnostic_error_code nvarchar(64) NULL,
        diagnostic_message nvarchar(4000) NULL,
        created_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestProviderConfigSnapshot_created_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_FieldTestProviderConfigSnapshot_sqlserver_not_blank CHECK(LEN(LTRIM(RTRIM(sql_server_name_masked))) > 0)
    );
END;

IF OBJECT_ID(N'FieldTest.SourceShipmentMap', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.SourceShipmentMap(
        source_shipment_map_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestSourceShipmentMap PRIMARY KEY DEFAULT NEWID(),
        provider nvarchar(20) NOT NULL CONSTRAINT CK_FieldTestSourceShipmentMap_provider CHECK(provider IN (N'Labonity', N'Liberty')),
        tenant_id uniqueidentifier NOT NULL,
        org_id uniqueidentifier NOT NULL,
        plant_id uniqueidentifier NOT NULL,
        plant_code nvarchar(32) NOT NULL,
        source_database_name sysname NOT NULL,
        source_table_name sysname NULL,
        source_key_version int NOT NULL CONSTRAINT DF_FieldTestSourceShipmentMap_key_version DEFAULT 1,
        source_shipment_key nvarchar(1000) NOT NULL,
        source_key_json nvarchar(max) NOT NULL,
        source_key_hash_sha256 char(64) NOT NULL,
        source_yotei_id uniqueidentifier NULL,
        source_syukka_id uniqueidentifier NULL,
        shipment_date date NULL,
        shipment_no nvarchar(50) NULL,
        site_id uniqueidentifier NULL,
        site_name nvarchar(200) NULL,
        source_row_hash_sha256 char(64) NULL,
        first_seen_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestSourceShipmentMap_first_seen_at DEFAULT SYSUTCDATETIME(),
        last_seen_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestSourceShipmentMap_last_seen_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT CK_FieldTestSourceShipmentMap_hash CHECK(source_key_hash_sha256 NOT LIKE '%[^0-9A-Fa-f]%')
    );
END;

IF OBJECT_ID(N'FieldTest.SyncState', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.SyncState(
        sync_state_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestSyncState PRIMARY KEY DEFAULT NEWID(),
        provider nvarchar(20) NOT NULL CONSTRAINT CK_FieldTestSyncState_provider CHECK(provider IN (N'Labonity', N'Liberty')),
        tenant_id uniqueidentifier NOT NULL,
        org_id uniqueidentifier NOT NULL,
        plant_id uniqueidentifier NOT NULL,
        plant_code nvarchar(32) NOT NULL,
        cursor_name nvarchar(100) NOT NULL,
        cursor_value nvarchar(400) NULL,
        last_synced_at datetime2(3) NULL,
        status nvarchar(20) NOT NULL CONSTRAINT DF_FieldTestSyncState_status DEFAULT N'Active',
        last_error_code nvarchar(64) NULL,
        last_error_message nvarchar(4000) NULL,
        created_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestSyncState_created_at DEFAULT SYSUTCDATETIME(),
        updated_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestSyncState_updated_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_FieldTestSyncState_cursor UNIQUE(provider, plant_id, cursor_name)
    );
END;

IF OBJECT_ID(N'FieldTest.TestResult', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.TestResult(
        result_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestTestResult PRIMARY KEY DEFAULT NEWID(),
        tenant_id uniqueidentifier NOT NULL,
        org_id uniqueidentifier NOT NULL,
        plant_id uniqueidentifier NOT NULL,
        plant_code nvarchar(32) NOT NULL,
        provider nvarchar(20) NOT NULL CONSTRAINT CK_FieldTestTestResult_provider CHECK(provider IN (N'Labonity', N'Liberty')),
        source_shipment_map_id uniqueidentifier NULL,
        source_key_version int NOT NULL CONSTRAINT DF_FieldTestTestResult_source_key_version DEFAULT 1,
        source_shipment_key nvarchar(1000) NOT NULL,
        source_key_hash_sha256 char(64) NOT NULL,
        source_result_key_version int NOT NULL CONSTRAINT DF_FieldTestTestResult_result_key_version DEFAULT 1,
        source_result_key nvarchar(1000) NOT NULL,
        source_result_key_json nvarchar(max) NOT NULL,
        source_result_key_hash_sha256 char(64) NOT NULL,
        shipment_date date NULL,
        shipment_no nvarchar(50) NULL,
        site_id uniqueidentifier NULL,
        site_name nvarchar(200) NULL,
        siken_kubun nvarchar(20) NOT NULL,
        is_tatewari bit NOT NULL CONSTRAINT DF_FieldTestTestResult_is_tatewari DEFAULT 0,
        group_no tinyint NOT NULL CONSTRAINT DF_FieldTestTestResult_group_no DEFAULT 0,
        data_kubun tinyint NOT NULL CONSTRAINT DF_FieldTestTestResult_data_kubun DEFAULT 0,
        slump_text nvarchar(20) NULL,
        slump_value decimal(7,2) NULL,
        flow1_text nvarchar(20) NULL,
        flow1_value decimal(7,2) NULL,
        flow2_text nvarchar(20) NULL,
        flow2_value decimal(7,2) NULL,
        air_text nvarchar(20) NULL,
        air_value decimal(7,2) NULL,
        concrete_temperature_text nvarchar(20) NULL,
        concrete_temperature_value decimal(7,2) NULL,
        unit_volume_mass_text nvarchar(20) NULL,
        unit_volume_mass_value decimal(9,2) NULL,
        chloride1_text nvarchar(20) NULL,
        chloride1_value decimal(9,3) NULL,
        chloride2_text nvarchar(20) NULL,
        chloride2_value decimal(9,3) NULL,
        chloride3_text nvarchar(20) NULL,
        chloride3_value decimal(9,3) NULL,
        unit_water_text nvarchar(20) NULL,
        unit_water_value decimal(9,2) NULL,
        witness nvarchar(80) NULL,
        placement_location nvarchar(240) NULL,
        outside_temperature_text nvarchar(20) NULL,
        outside_temperature_value decimal(7,2) NULL,
        remarks nvarchar(400) NULL,
        result_status nvarchar(20) NOT NULL CONSTRAINT DF_FieldTestTestResult_status DEFAULT N'Confirmed',
        event_id uniqueidentifier NOT NULL,
        confirmed_at datetime2(3) NULL,
        confirmed_by_user_id uniqueidentifier NULL,
        created_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestTestResult_created_at DEFAULT SYSUTCDATETIME(),
        updated_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestTestResult_updated_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_FieldTestTestResult_SourceShipmentMap FOREIGN KEY(source_shipment_map_id) REFERENCES FieldTest.SourceShipmentMap(source_shipment_map_id),
        CONSTRAINT UQ_FieldTestTestResult_event UNIQUE(event_id),
        CONSTRAINT CK_FieldTestTestResult_key_hash CHECK(source_result_key_hash_sha256 NOT LIKE '%[^0-9A-Fa-f]%')
    );
END;

IF OBJECT_ID(N'FieldTest.TestPhoto', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.TestPhoto(
        photo_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestTestPhoto PRIMARY KEY DEFAULT NEWID(),
        result_id uniqueidentifier NOT NULL,
        photo_kind nvarchar(40) NOT NULL,
        mime_type nvarchar(100) NOT NULL,
        file_size bigint NULL,
        sha256 char(64) NOT NULL,
        storage_uri nvarchar(1000) NULL,
        local_file_path nvarchar(1000) NULL,
        is_ocr_primary bit NOT NULL CONSTRAINT DF_FieldTestTestPhoto_is_ocr_primary DEFAULT 0,
        captured_at datetime2(3) NULL,
        event_id uniqueidentifier NOT NULL,
        created_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestTestPhoto_created_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_FieldTestTestPhoto_TestResult FOREIGN KEY(result_id) REFERENCES FieldTest.TestResult(result_id) ON DELETE CASCADE,
        CONSTRAINT UQ_FieldTestTestPhoto_event UNIQUE(event_id),
        CONSTRAINT CK_FieldTestTestPhoto_location CHECK(storage_uri IS NOT NULL OR local_file_path IS NOT NULL),
        CONSTRAINT CK_FieldTestTestPhoto_hash CHECK(sha256 NOT LIKE '%[^0-9A-Fa-f]%')
    );
END;

IF OBJECT_ID(N'FieldTest.OcrResult', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.OcrResult(
        ocr_result_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestOcrResult PRIMARY KEY DEFAULT NEWID(),
        result_id uniqueidentifier NOT NULL,
        photo_id uniqueidentifier NULL,
        raw_ocr_json nvarchar(max) NULL,
        normalized_json nvarchar(max) NULL,
        normalized_json_hash_sha256 char(64) NULL,
        ocr_status nvarchar(30) NOT NULL CONSTRAINT DF_FieldTestOcrResult_status DEFAULT N'Confirmed',
        confidence decimal(5,4) NULL,
        confirmed_at datetime2(3) NULL,
        confirmed_by_user_id uniqueidentifier NULL,
        event_id uniqueidentifier NOT NULL,
        created_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestOcrResult_created_at DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_FieldTestOcrResult_TestResult FOREIGN KEY(result_id) REFERENCES FieldTest.TestResult(result_id) ON DELETE CASCADE,
        CONSTRAINT FK_FieldTestOcrResult_TestPhoto FOREIGN KEY(photo_id) REFERENCES FieldTest.TestPhoto(photo_id),
        CONSTRAINT UQ_FieldTestOcrResult_event UNIQUE(event_id)
    );
END;

IF OBJECT_ID(N'FieldTest.AuditEvent', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.AuditEvent(
        audit_event_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestAuditEvent PRIMARY KEY DEFAULT NEWID(),
        event_time datetime2(3) NOT NULL CONSTRAINT DF_FieldTestAuditEvent_event_time DEFAULT SYSUTCDATETIME(),
        provider nvarchar(20) NULL,
        tenant_id uniqueidentifier NULL,
        org_id uniqueidentifier NULL,
        plant_id uniqueidentifier NULL,
        actor_type nvarchar(40) NULL,
        actor_id nvarchar(200) NULL,
        correlation_id uniqueidentifier NULL,
        event_name nvarchar(100) NOT NULL,
        severity nvarchar(20) NOT NULL CONSTRAINT DF_FieldTestAuditEvent_severity DEFAULT N'Info',
        subject_type nvarchar(100) NULL,
        subject_id nvarchar(200) NULL,
        error_code nvarchar(64) NULL,
        before_json nvarchar(max) NULL,
        after_json nvarchar(max) NULL,
        detail_json nvarchar(max) NULL
    );
END;

DECLARE @v001 char(64) = CONVERT(char(64), HASHBYTES('SHA2_256', N'V001_CoreSchema_FieldTest_1.0'), 2);
IF NOT EXISTS (SELECT 1 FROM FieldTest.SchemaMigration WHERE migration_id = N'V001_CoreSchema')
    INSERT INTO FieldTest.SchemaMigration(migration_id, checksum_sha256, description) VALUES(N'V001_CoreSchema', @v001, N'FieldTest core schema');

COMMIT;
GO

/* ============================================================
   V002_EventQueuesAndIndexes
   ============================================================ */
BEGIN TRANSACTION;

IF OBJECT_ID(N'FieldTest.InboundEvent', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.InboundEvent(
        inbound_event_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestInboundEvent PRIMARY KEY DEFAULT NEWID(),
        event_id uniqueidentifier NOT NULL,
        event_type nvarchar(100) NOT NULL,
        provider nvarchar(20) NOT NULL,
        tenant_id uniqueidentifier NOT NULL,
        org_id uniqueidentifier NOT NULL,
        plant_id uniqueidentifier NOT NULL,
        aggregate_type nvarchar(100) NULL,
        aggregate_id nvarchar(100) NULL,
        payload_json nvarchar(max) NOT NULL,
        status nvarchar(20) NOT NULL CONSTRAINT DF_FieldTestInboundEvent_status DEFAULT N'Received',
        retry_count int NOT NULL CONSTRAINT DF_FieldTestInboundEvent_retry_count DEFAULT 0,
        next_retry_at datetime2(3) NULL,
        last_error_code nvarchar(64) NULL,
        last_error_message nvarchar(4000) NULL,
        received_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestInboundEvent_received_at DEFAULT SYSUTCDATETIME(),
        processed_at datetime2(3) NULL,
        correlation_id uniqueidentifier NULL,
        CONSTRAINT UQ_FieldTestInboundEvent_event UNIQUE(event_id)
    );
END;

IF OBJECT_ID(N'FieldTest.OutboxEvent', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.OutboxEvent(
        outbox_event_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestOutboxEvent PRIMARY KEY DEFAULT NEWID(),
        event_id uniqueidentifier NOT NULL,
        event_type nvarchar(100) NOT NULL,
        aggregate_type nvarchar(100) NOT NULL,
        aggregate_id nvarchar(100) NOT NULL,
        payload_json nvarchar(max) NOT NULL,
        status nvarchar(20) NOT NULL CONSTRAINT DF_FieldTestOutboxEvent_status DEFAULT N'Pending',
        retry_count int NOT NULL CONSTRAINT DF_FieldTestOutboxEvent_retry_count DEFAULT 0,
        next_retry_at datetime2(3) NULL,
        last_error_code nvarchar(64) NULL,
        last_error_message nvarchar(4000) NULL,
        created_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestOutboxEvent_created_at DEFAULT SYSUTCDATETIME(),
        sent_at datetime2(3) NULL,
        acked_at datetime2(3) NULL,
        correlation_id uniqueidentifier NULL,
        CONSTRAINT UQ_FieldTestOutboxEvent_event UNIQUE(event_id)
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_FieldTestSourceShipmentMap_SourceHash' AND object_id = OBJECT_ID(N'FieldTest.SourceShipmentMap'))
    CREATE UNIQUE INDEX UX_FieldTestSourceShipmentMap_SourceHash ON FieldTest.SourceShipmentMap(provider, plant_id, source_key_version, source_key_hash_sha256);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_FieldTestTestResult_ResultHash' AND object_id = OBJECT_ID(N'FieldTest.TestResult'))
    CREATE UNIQUE INDEX UX_FieldTestTestResult_ResultHash ON FieldTest.TestResult(provider, plant_id, source_result_key_version, source_result_key_hash_sha256);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FieldTestTestResult_Shipment' AND object_id = OBJECT_ID(N'FieldTest.TestResult'))
    CREATE INDEX IX_FieldTestTestResult_Shipment ON FieldTest.TestResult(provider, plant_id, shipment_date, shipment_no, site_name);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_FieldTestTestPhoto_ResultKindHash' AND object_id = OBJECT_ID(N'FieldTest.TestPhoto'))
    CREATE UNIQUE INDEX UX_FieldTestTestPhoto_ResultKindHash ON FieldTest.TestPhoto(result_id, photo_kind, sha256);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_FieldTestTestPhoto_OcrPrimary' AND object_id = OBJECT_ID(N'FieldTest.TestPhoto'))
    CREATE UNIQUE INDEX UX_FieldTestTestPhoto_OcrPrimary ON FieldTest.TestPhoto(result_id) WHERE is_ocr_primary = 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FieldTestInboundEvent_Status' AND object_id = OBJECT_ID(N'FieldTest.InboundEvent'))
    CREATE INDEX IX_FieldTestInboundEvent_Status ON FieldTest.InboundEvent(status, next_retry_at, received_at);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_FieldTestOutboxEvent_Status' AND object_id = OBJECT_ID(N'FieldTest.OutboxEvent'))
    CREATE INDEX IX_FieldTestOutboxEvent_Status ON FieldTest.OutboxEvent(status, next_retry_at, created_at);

DECLARE @v002 char(64) = CONVERT(char(64), HASHBYTES('SHA2_256', N'V002_EventQueuesAndIndexes_FieldTest_1.0'), 2);
IF NOT EXISTS (SELECT 1 FROM FieldTest.SchemaMigration WHERE migration_id = N'V002_EventQueuesAndIndexes')
    INSERT INTO FieldTest.SchemaMigration(migration_id, checksum_sha256, description) VALUES(N'V002_EventQueuesAndIndexes', @v002, N'Inbound/Outbox and idempotency indexes');

COMMIT;
GO

/* ============================================================
   V003_ProviderAppViews
   ============================================================ */
IF OBJECT_ID(N'FieldTest.v_ProviderApp_TestResult', N'V') IS NOT NULL DROP VIEW FieldTest.v_ProviderApp_TestResult;
GO
CREATE VIEW FieldTest.v_ProviderApp_TestResult AS
SELECT
    r.result_id,
    r.provider,
    r.tenant_id,
    r.org_id,
    r.plant_id,
    r.plant_code,
    r.source_shipment_key,
    r.source_key_hash_sha256,
    r.source_result_key,
    r.source_result_key_hash_sha256,
    r.shipment_date,
    r.shipment_no,
    r.site_id,
    r.site_name,
    r.siken_kubun,
    r.is_tatewari,
    r.group_no,
    r.data_kubun,
    r.slump_text,
    r.slump_value,
    r.flow1_text,
    r.flow1_value,
    r.flow2_text,
    r.flow2_value,
    r.air_text,
    r.air_value,
    r.concrete_temperature_text,
    r.concrete_temperature_value,
    r.unit_volume_mass_text,
    r.unit_volume_mass_value,
    r.chloride1_text,
    r.chloride1_value,
    r.chloride2_text,
    r.chloride2_value,
    r.chloride3_text,
    r.chloride3_value,
    r.unit_water_text,
    r.unit_water_value,
    r.witness,
    r.placement_location,
    r.remarks,
    r.result_status,
    r.confirmed_at,
    r.confirmed_by_user_id,
    r.updated_at,
    (SELECT COUNT(1) FROM FieldTest.TestPhoto p WHERE p.result_id = r.result_id) AS photo_count,
    (SELECT TOP(1) p.photo_id FROM FieldTest.TestPhoto p WHERE p.result_id = r.result_id AND p.is_ocr_primary = 1 ORDER BY p.created_at DESC) AS ocr_primary_photo_id,
    (SELECT TOP(1) o.ocr_status FROM FieldTest.OcrResult o WHERE o.result_id = r.result_id ORDER BY o.created_at DESC) AS ocr_status,
    (SELECT TOP(1) o.confidence FROM FieldTest.OcrResult o WHERE o.result_id = r.result_id ORDER BY o.created_at DESC) AS ocr_confidence
FROM FieldTest.TestResult r;
GO

IF OBJECT_ID(N'FieldTest.v_ProviderApp_TestPhoto', N'V') IS NOT NULL DROP VIEW FieldTest.v_ProviderApp_TestPhoto;
GO
CREATE VIEW FieldTest.v_ProviderApp_TestPhoto AS
SELECT
    p.photo_id,
    p.result_id,
    p.photo_kind,
    p.mime_type,
    p.file_size,
    p.sha256,
    p.storage_uri,
    p.local_file_path,
    p.is_ocr_primary,
    p.captured_at,
    p.created_at
FROM FieldTest.TestPhoto p;
GO

IF OBJECT_ID(N'FieldTest.v_ProviderApp_OcrResult', N'V') IS NOT NULL DROP VIEW FieldTest.v_ProviderApp_OcrResult;
GO
CREATE VIEW FieldTest.v_ProviderApp_OcrResult AS
SELECT
    o.ocr_result_id,
    o.result_id,
    o.photo_id,
    o.ocr_status,
    o.confidence,
    o.normalized_json,
    o.normalized_json_hash_sha256,
    o.confirmed_at,
    o.confirmed_by_user_id,
    o.created_at
FROM FieldTest.OcrResult o;
GO

IF OBJECT_ID(N'FieldTest.v_ProviderApp_ShipmentResultStatus', N'V') IS NOT NULL DROP VIEW FieldTest.v_ProviderApp_ShipmentResultStatus;
GO
CREATE VIEW FieldTest.v_ProviderApp_ShipmentResultStatus AS
SELECT
    r.provider,
    r.plant_id,
    r.plant_code,
    r.source_key_hash_sha256,
    r.source_shipment_key,
    MAX(r.shipment_date) AS shipment_date,
    MAX(r.shipment_no) AS shipment_no,
    MAX(r.site_name) AS site_name,
    COUNT(DISTINCT r.result_id) AS result_count,
    COUNT(DISTINCT p.photo_id) AS photo_count,
    SUM(CASE WHEN o.ocr_status = N'Confirmed' THEN 1 ELSE 0 END) AS confirmed_ocr_count,
    MAX(r.updated_at) AS last_result_updated_at
FROM FieldTest.TestResult r
LEFT JOIN FieldTest.TestPhoto p ON p.result_id = r.result_id
LEFT JOIN FieldTest.OcrResult o ON o.result_id = r.result_id
GROUP BY r.provider, r.plant_id, r.plant_code, r.source_key_hash_sha256, r.source_shipment_key;
GO

IF OBJECT_ID(N'FieldTest.v_CurrentTestResult', N'V') IS NOT NULL DROP VIEW FieldTest.v_CurrentTestResult;
GO
CREATE VIEW FieldTest.v_CurrentTestResult AS
SELECT * FROM FieldTest.v_ProviderApp_TestResult;
GO

BEGIN TRANSACTION;
DECLARE @v003 char(64) = CONVERT(char(64), HASHBYTES('SHA2_256', N'V003_ProviderAppViews_FieldTest_1.0'), 2);
IF NOT EXISTS (SELECT 1 FROM FieldTest.SchemaMigration WHERE migration_id = N'V003_ProviderAppViews')
    INSERT INTO FieldTest.SchemaMigration(migration_id, checksum_sha256, description) VALUES(N'V003_ProviderAppViews', @v003, N'Provider application read views');
COMMIT;
GO

/* ============================================================
   V004_AgentLeaseProcedures
   ============================================================ */
BEGIN TRANSACTION;

IF OBJECT_ID(N'FieldTest.AgentLease', N'U') IS NULL
BEGIN
    CREATE TABLE FieldTest.AgentLease(
        lease_id uniqueidentifier NOT NULL CONSTRAINT PK_FieldTestAgentLease PRIMARY KEY DEFAULT NEWID(),
        agent_id uniqueidentifier NOT NULL,
        resource_name nvarchar(200) NOT NULL,
        acquired_at datetime2(3) NOT NULL CONSTRAINT DF_FieldTestAgentLease_acquired_at DEFAULT SYSUTCDATETIME(),
        expires_at datetime2(3) NOT NULL,
        released_at datetime2(3) NULL
    );
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'UX_FieldTestAgentLease_Active' AND object_id = OBJECT_ID(N'FieldTest.AgentLease'))
    CREATE UNIQUE INDEX UX_FieldTestAgentLease_Active ON FieldTest.AgentLease(resource_name) WHERE released_at IS NULL;

DECLARE @v004 char(64) = CONVERT(char(64), HASHBYTES('SHA2_256', N'V004_AgentLeaseProcedures_FieldTest_1.0'), 2);
IF NOT EXISTS (SELECT 1 FROM FieldTest.SchemaMigration WHERE migration_id = N'V004_AgentLeaseProcedures')
    INSERT INTO FieldTest.SchemaMigration(migration_id, checksum_sha256, description) VALUES(N'V004_AgentLeaseProcedures', @v004, N'Agent lease table and procedures');

COMMIT;
GO

IF OBJECT_ID(N'FieldTest.usp_AcquireAgentLease', N'P') IS NOT NULL DROP PROCEDURE FieldTest.usp_AcquireAgentLease;
GO
CREATE PROCEDURE FieldTest.usp_AcquireAgentLease
    @agent_id uniqueidentifier,
    @resource_name nvarchar(200),
    @lease_seconds int = 300
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now datetime2(3) = SYSUTCDATETIME();
    DECLARE @expires_at datetime2(3) = DATEADD(SECOND, @lease_seconds, @now);

    BEGIN TRANSACTION;

    UPDATE l WITH (UPDLOCK, HOLDLOCK)
        SET released_at = @now
    FROM FieldTest.AgentLease l
    WHERE l.resource_name = @resource_name
      AND l.released_at IS NULL
      AND l.expires_at < @now;

    IF EXISTS (
        SELECT 1
        FROM FieldTest.AgentLease WITH (UPDLOCK, HOLDLOCK)
        WHERE resource_name = @resource_name
          AND released_at IS NULL
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51001, 'Active agent lease already exists.', 1;
    END;

    INSERT INTO FieldTest.AgentLease(agent_id, resource_name, acquired_at, expires_at)
    VALUES(@agent_id, @resource_name, @now, @expires_at);

    COMMIT TRANSACTION;
END;
GO

IF OBJECT_ID(N'FieldTest.usp_ReleaseAgentLease', N'P') IS NOT NULL DROP PROCEDURE FieldTest.usp_ReleaseAgentLease;
GO
CREATE PROCEDURE FieldTest.usp_ReleaseAgentLease
    @agent_id uniqueidentifier,
    @resource_name nvarchar(200)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE FieldTest.AgentLease
       SET released_at = SYSUTCDATETIME()
     WHERE agent_id = @agent_id
       AND resource_name = @resource_name
       AND released_at IS NULL;
END;
GO

/* 診断SQL: FieldTest必須オブジェクト確認 */
SELECT
    s.name AS schema_name,
    o.name AS object_name,
    o.type_desc
FROM sys.objects o
JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE s.name = N'FieldTest'
ORDER BY o.type_desc, o.name;
GO
