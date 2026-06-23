/*
  現場試験アプリ - 既存出荷管理DB FieldTestスキーマ連携テーブル
  参考DDL 第2.2版 / 2026-06-23

  IMPORTANT:
  - 新しい物理DBは作成しない。LibertyDatabaseSetting.xml の
    p_出荷管理データベース名で解決した既存出荷管理DBに実行する。
  - Sync Agent が p_出荷管理データベース名から解決したDBへ接続した状態で実行する。
  - DB設定XMLに新しい項目を追加する必要はない。
  - FieldTestスキーマ、12テーブル、主要インデックスを冪等に作成する。
  - 本番適用前に照合順序、命名規則、サービスアカウント権限、保持、
    バックアップ、配布方式を確認する。
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
BEGIN
  THROW 51000, N'出荷管理データベースへ接続した状態で実行してください。システムDBには適用できません。', 1;
END;
GO

IF SCHEMA_ID(N'FieldTest') IS NULL
BEGIN
  EXEC(N'CREATE SCHEMA [FieldTest] AUTHORIZATION [dbo]');
END;
GO

BEGIN TRY
  BEGIN TRANSACTION;

  IF OBJECT_ID(N'[FieldTest].[FieldPhotoReference]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldPhotoReference](
      photo_reference_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldPhotoReference_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      photo_asset_id uniqueidentifier NOT NULL,
      photo_asset_target_id uniqueidentifier NOT NULL,
      target_type nvarchar(30) NOT NULL CONSTRAINT DF_FieldPhotoReference_TargetType DEFAULT N'shipment',
      target_local_id uniqueidentifier NOT NULL,
      target_cloud_id uniqueidentifier NOT NULL,
      taken_at datetimeoffset(7) NULL,
      source_type nvarchar(20) NOT NULL,
      capture_purpose nvarchar(50) NOT NULL,
      thumbnail_blob_path nvarchar(1000) NULL,
      original_blob_path nvarchar(1000) NULL,
      local_thumbnail_path nvarchar(1500) NULL,
      local_original_path nvarchar(1500) NULL,
      cache_status nvarchar(30) NOT NULL CONSTRAINT DF_FieldPhotoReference_CacheStatus DEFAULT N'not_cached',
      cache_updated_at datetimeoffset(7) NULL,
      cache_error nvarchar(1000) NULL,
      is_primary bit NOT NULL CONSTRAINT DF_FieldPhotoReference_IsPrimary DEFAULT (0),
      display_order int NOT NULL CONSTRAINT DF_FieldPhotoReference_DisplayOrder DEFAULT (0),
      ocr_usage nvarchar(50) NULL,
      is_ocr_primary bit NOT NULL CONSTRAINT DF_FieldPhotoReference_IsOcrPrimary DEFAULT (0),
      file_hash nvarchar(100) NULL,
      quality_warnings_json nvarchar(max) NULL,
      deleted_at datetimeoffset(7) NULL,
      event_sequence bigint NOT NULL,
      synced_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldPhotoReference_SyncedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldPhotoReference PRIMARY KEY CLUSTERED(photo_reference_id),
      CONSTRAINT CK_FieldPhotoReference_SourceType CHECK(source_type IN (N'camera',N'library')),
      CONSTRAINT CK_FieldPhotoReference_Purpose CHECK(capture_purpose IN (N'general',N'fresh_test_ocr_blackboard'))
    );
  END;

  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldPhotoReference]') AND name=N'UX_FieldPhotoReference_AssetTarget')
    CREATE UNIQUE INDEX UX_FieldPhotoReference_AssetTarget ON [FieldTest].[FieldPhotoReference](tenant_id,plant_id,photo_asset_id,photo_asset_target_id) WHERE deleted_at IS NULL;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldPhotoReference]') AND name=N'IX_FieldPhotoReference_Target')
    CREATE INDEX IX_FieldPhotoReference_Target ON [FieldTest].[FieldPhotoReference](tenant_id,plant_id,target_type,target_local_id,is_primary DESC,display_order,taken_at,photo_asset_id) INCLUDE(capture_purpose,ocr_usage,is_ocr_primary,cache_status,local_original_path) WHERE deleted_at IS NULL;

  IF OBJECT_ID(N'[FieldTest].[FieldPhotoLocalFile]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldPhotoLocalFile](
      local_file_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldPhotoLocalFile_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      photo_reference_id uniqueidentifier NOT NULL,
      photo_asset_id uniqueidentifier NOT NULL,
      photo_asset_target_id uniqueidentifier NOT NULL,
      target_type nvarchar(30) NOT NULL CONSTRAINT DF_FieldPhotoLocalFile_TargetType DEFAULT N'shipment',
      target_local_id uniqueidentifier NOT NULL,
      variant nvarchar(30) NOT NULL,
      local_root_key nvarchar(50) NOT NULL CONSTRAINT DF_FieldPhotoLocalFile_Root DEFAULT N'default',
      relative_path nvarchar(1000) NOT NULL,
      local_file_path nvarchar(1500) NOT NULL,
      file_name nvarchar(255) NOT NULL,
      mime_type nvarchar(100) NOT NULL,
      size_bytes bigint NULL,
      width int NULL,
      height int NULL,
      sha256_hash nvarchar(100) NULL,
      jpeg_quality int NULL,
      materialize_status nvarchar(30) NOT NULL CONSTRAINT DF_FieldPhotoLocalFile_Status DEFAULT N'queued',
      materialize_priority int NOT NULL CONSTRAINT DF_FieldPhotoLocalFile_Priority DEFAULT (50),
      attempt_count int NOT NULL CONSTRAINT DF_FieldPhotoLocalFile_Attempt DEFAULT (0),
      last_error_code nvarchar(100) NULL,
      last_error_message nvarchar(1000) NULL,
      source_event_sequence bigint NOT NULL,
      materialized_at datetimeoffset(7) NULL,
      verified_at datetimeoffset(7) NULL,
      deleted_at datetimeoffset(7) NULL,
      synced_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldPhotoLocalFile_SyncedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldPhotoLocalFile PRIMARY KEY CLUSTERED(local_file_id),
      CONSTRAINT FK_FieldPhotoLocalFile_Reference FOREIGN KEY(photo_reference_id) REFERENCES [FieldTest].[FieldPhotoReference](photo_reference_id),
      CONSTRAINT CK_FieldPhotoLocalFile_Status CHECK(materialize_status IN (N'queued',N'downloading',N'converting',N'ready',N'failed',N'deleted'))
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldPhotoLocalFile]') AND name=N'UX_FieldPhotoLocalFile_PhotoVariant')
    CREATE UNIQUE INDEX UX_FieldPhotoLocalFile_PhotoVariant ON [FieldTest].[FieldPhotoLocalFile](tenant_id,plant_id,photo_asset_id,photo_asset_target_id,variant,local_root_key) WHERE deleted_at IS NULL;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldPhotoLocalFile]') AND name=N'IX_FieldPhotoLocalFile_Target')
    CREATE INDEX IX_FieldPhotoLocalFile_Target ON [FieldTest].[FieldPhotoLocalFile](tenant_id,plant_id,target_type,target_local_id,variant,materialize_status,materialized_at DESC) INCLUDE(local_file_path,size_bytes,sha256_hash) WHERE deleted_at IS NULL;

  IF OBJECT_ID(N'[FieldTest].[FieldPhotoMaterializeJob]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldPhotoMaterializeJob](
      materialize_job_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldPhotoMaterializeJob_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      photo_reference_id uniqueidentifier NOT NULL,
      photo_asset_id uniqueidentifier NOT NULL,
      target_local_id uniqueidentifier NOT NULL,
      job_type nvarchar(30) NOT NULL,
      priority int NOT NULL,
      status nvarchar(30) NOT NULL CONSTRAINT DF_FieldPhotoMaterializeJob_Status DEFAULT N'queued',
      not_before datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldPhotoMaterializeJob_NotBefore DEFAULT SYSDATETIMEOFFSET(),
      attempt_count int NOT NULL CONSTRAINT DF_FieldPhotoMaterializeJob_Attempt DEFAULT (0),
      last_error_code nvarchar(100) NULL,
      last_error_message nvarchar(1000) NULL,
      created_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldPhotoMaterializeJob_CreatedAt DEFAULT SYSDATETIMEOFFSET(),
      updated_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldPhotoMaterializeJob_UpdatedAt DEFAULT SYSDATETIMEOFFSET(),
      finished_at datetimeoffset(7) NULL,
      CONSTRAINT PK_FieldPhotoMaterializeJob PRIMARY KEY CLUSTERED(materialize_job_id),
      CONSTRAINT FK_FieldPhotoMaterializeJob_Reference FOREIGN KEY(photo_reference_id) REFERENCES [FieldTest].[FieldPhotoReference](photo_reference_id),
      CONSTRAINT CK_FieldPhotoMaterializeJob_Status CHECK(status IN (N'queued',N'running',N'succeeded',N'retry_wait',N'failed',N'cancelled'))
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldPhotoMaterializeJob]') AND name=N'IX_FieldPhotoMaterializeJob_Dequeue')
    CREATE INDEX IX_FieldPhotoMaterializeJob_Dequeue ON [FieldTest].[FieldPhotoMaterializeJob](status,not_before,priority,created_at) INCLUDE(tenant_id,plant_id,photo_asset_id,target_local_id);

  IF OBJECT_ID(N'[FieldTest].[FieldPhotoExportConfig]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldPhotoExportConfig](
      config_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NULL,
      local_root_key nvarchar(50) NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_RootKey DEFAULT N'default',
      writer_root_path nvarchar(1000) NOT NULL,
      labonity_visible_root_path nvarchar(1000) NOT NULL,
      enabled bit NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_Enabled DEFAULT (1),
      folder_template nvarchar(1000) NOT NULL,
      file_name_template nvarchar(500) NOT NULL,
      include_general_original bit NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_General DEFAULT (1),
      include_ocr_original bit NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_Ocr DEFAULT (1),
      include_thumbnail bit NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_Thumb DEFAULT (1),
      include_metadata_json bit NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_Meta DEFAULT (1),
      jpeg_quality int NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_Quality DEFAULT (90),
      thumbnail_long_side int NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_ThumbSide DEFAULT (640),
      max_original_long_side int NULL,
      max_full_path_length int NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_MaxPath DEFAULT (240),
      delete_policy nvarchar(30) NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_DeletePolicy DEFAULT N'keep_with_deleted_marker',
      retention_days int NULL,
      created_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_CreatedAt DEFAULT SYSDATETIMEOFFSET(),
      updated_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldPhotoExportConfig_UpdatedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldPhotoExportConfig PRIMARY KEY CLUSTERED(config_id),
      CONSTRAINT CK_FieldPhotoExportConfig_Quality CHECK(jpeg_quality BETWEEN 1 AND 100),
      CONSTRAINT CK_FieldPhotoExportConfig_MaxPath CHECK(max_full_path_length BETWEEN 120 AND 32000)
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldPhotoExportConfig]') AND name=N'UX_FieldPhotoExportConfig_Scope')
    CREATE UNIQUE INDEX UX_FieldPhotoExportConfig_Scope ON [FieldTest].[FieldPhotoExportConfig](tenant_id,plant_id,local_root_key);

  IF OBJECT_ID(N'[FieldTest].[FieldOcrResultReference]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldOcrResultReference](
      ocr_result_reference_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldOcrResultReference_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      ocr_import_job_id uniqueidentifier NOT NULL,
      ocr_import_result_id uniqueidentifier NOT NULL,
      syukka_id uniqueidentifier NOT NULL,
      shipment_id uniqueidentifier NOT NULL,
      photo_asset_id uniqueidentifier NOT NULL,
      photo_asset_target_id uniqueidentifier NOT NULL,
      ocr_usage nvarchar(50) NOT NULL,
      schema_version nvarchar(100) NOT NULL,
      status nvarchar(30) NOT NULL,
      is_current bit NOT NULL,
      overall_confidence decimal(5,4) NULL,
      min_field_confidence decimal(5,4) NULL,
      quality_score decimal(5,4) NULL,
      validation_score decimal(5,4) NULL,
      field_count int NOT NULL CONSTRAINT DF_FieldOcrResultReference_FieldCount DEFAULT (0),
      low_confidence_count int NOT NULL CONSTRAINT DF_FieldOcrResultReference_LowCount DEFAULT (0),
      needs_review_count int NOT NULL CONSTRAINT DF_FieldOcrResultReference_ReviewCount DEFAULT (0),
      image_quality_json nvarchar(max) NULL,
      validation_results_json nvarchar(max) NULL,
      extracted_values_json nvarchar(max) NULL,
      confidence_json nvarchar(max) NULL,
      warnings_json nvarchar(max) NULL,
      local_photo_path nvarchar(1500) NULL,
      local_thumbnail_path nvarchar(1500) NULL,
      processed_at datetimeoffset(7) NULL,
      event_sequence bigint NOT NULL,
      synced_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldOcrResultReference_SyncedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldOcrResultReference PRIMARY KEY CLUSTERED(ocr_result_reference_id),
      CONSTRAINT CK_FieldOcrResultReference_Status CHECK(status IN (N'completed',N'needs_review',N'failed',N'superseded'))
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldOcrResultReference]') AND name=N'UX_FieldOcrResultReference_CloudId')
    CREATE UNIQUE INDEX UX_FieldOcrResultReference_CloudId ON [FieldTest].[FieldOcrResultReference](tenant_id,plant_id,ocr_import_result_id);
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldOcrResultReference]') AND name=N'UX_FieldOcrResultReference_Current')
    CREATE UNIQUE INDEX UX_FieldOcrResultReference_Current ON [FieldTest].[FieldOcrResultReference](tenant_id,plant_id,syukka_id,ocr_usage) WHERE is_current=1 AND status IN (N'completed',N'needs_review');

  IF OBJECT_ID(N'[FieldTest].[FieldOcrResultFieldReference]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldOcrResultFieldReference](
      ocr_result_field_reference_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldOcrResultFieldReference_Id DEFAULT NEWSEQUENTIALID(),
      ocr_result_reference_id uniqueidentifier NOT NULL,
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      syukka_id uniqueidentifier NOT NULL,
      canonical_key nvarchar(100) NOT NULL,
      display_order int NOT NULL,
      label_text nvarchar(200) NULL,
      raw_text nvarchar(500) NULL,
      normalized_value nvarchar(500) NULL,
      numeric_value decimal(18,5) NULL,
      value_type nvarchar(30) NOT NULL,
      unit nvarchar(50) NULL,
      confidence decimal(5,4) NULL,
      needs_review bit NOT NULL CONSTRAINT DF_FieldOcrResultFieldReference_Review DEFAULT (0),
      review_reason_codes nvarchar(max) NULL,
      warnings_json nvarchar(max) NULL,
      candidates_json nvarchar(max) NULL,
      bounding_polygon_json nvarchar(max) NULL,
      synced_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldOcrResultFieldReference_SyncedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldOcrResultFieldReference PRIMARY KEY CLUSTERED(ocr_result_field_reference_id),
      CONSTRAINT FK_FieldOcrResultFieldReference_Result FOREIGN KEY(ocr_result_reference_id) REFERENCES [FieldTest].[FieldOcrResultReference](ocr_result_reference_id) ON DELETE CASCADE
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldOcrResultFieldReference]') AND name=N'UX_FieldOcrResultFieldReference_Key')
    CREATE UNIQUE INDEX UX_FieldOcrResultFieldReference_Key ON [FieldTest].[FieldOcrResultFieldReference](ocr_result_reference_id,canonical_key);

  IF OBJECT_ID(N'[FieldTest].[FieldOcrImportAudit]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldOcrImportAudit](
      ocr_import_audit_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldOcrImportAudit_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      ocr_import_result_id uniqueidentifier NOT NULL,
      ocr_result_reference_id uniqueidentifier NOT NULL,
      syukka_id uniqueidentifier NOT NULL,
      testpiecesaisyu_main_id uniqueidentifier NULL,
      renban tinyint NOT NULL,
      datakubun tinyint NOT NULL,
      photo_asset_id uniqueidentifier NOT NULL,
      ocr_values_json nvarchar(max) NOT NULL,
      ocr_confidence_json nvarchar(max) NULL,
      ocr_warnings_json nvarchar(max) NULL,
      before_values_json nvarchar(max) NULL,
      applied_values_json nvarchar(max) NULL,
      corrected_fields_json nvarchar(max) NULL,
      saved_values_json nvarchar(max) NULL,
      status nvarchar(30) NOT NULL,
      created_by nvarchar(100) NOT NULL,
      created_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldOcrImportAudit_CreatedAt DEFAULT SYSDATETIMEOFFSET(),
      updated_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldOcrImportAudit_UpdatedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldOcrImportAudit PRIMARY KEY CLUSTERED(ocr_import_audit_id),
      CONSTRAINT FK_FieldOcrImportAudit_Result FOREIGN KEY(ocr_result_reference_id) REFERENCES [FieldTest].[FieldOcrResultReference](ocr_result_reference_id),
      CONSTRAINT CK_FieldOcrImportAudit_Status CHECK(status IN (N'applied_to_screen',N'saved',N'save_failed',N'discarded'))
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldOcrImportAudit]') AND name=N'IX_FieldOcrImportAudit_DuplicateCheck')
    CREATE INDEX IX_FieldOcrImportAudit_DuplicateCheck ON [FieldTest].[FieldOcrImportAudit](tenant_id,plant_id,ocr_import_result_id,testpiecesaisyu_main_id,renban,datakubun,status,created_at DESC);

  IF OBJECT_ID(N'[FieldTest].[FieldOcrValidationRule]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldOcrValidationRule](
      validation_rule_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldOcrValidationRule_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NULL,
      canonical_key nvarchar(100) NOT NULL,
      value_type nvarchar(30) NOT NULL,
      unit nvarchar(50) NULL,
      min_numeric_value decimal(18,5) NULL,
      max_numeric_value decimal(18,5) NULL,
      max_length int NULL,
      decimal_scale int NULL,
      warning_threshold decimal(5,4) NULL,
      block_on_type_error bit NOT NULL CONSTRAINT DF_FieldOcrValidationRule_Type DEFAULT (1),
      block_on_length_error bit NOT NULL CONSTRAINT DF_FieldOcrValidationRule_Length DEFAULT (1),
      range_outcome nvarchar(20) NOT NULL CONSTRAINT DF_FieldOcrValidationRule_Range DEFAULT N'needs_review',
      enabled bit NOT NULL CONSTRAINT DF_FieldOcrValidationRule_Enabled DEFAULT (1),
      mapping_json nvarchar(max) NULL,
      created_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldOcrValidationRule_CreatedAt DEFAULT SYSDATETIMEOFFSET(),
      updated_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldOcrValidationRule_UpdatedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldOcrValidationRule PRIMARY KEY CLUSTERED(validation_rule_id)
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldOcrValidationRule]') AND name=N'UX_FieldOcrValidationRule_ScopeKey')
    CREATE UNIQUE INDEX UX_FieldOcrValidationRule_ScopeKey ON [FieldTest].[FieldOcrValidationRule](tenant_id,plant_id,canonical_key);

  IF OBJECT_ID(N'[FieldTest].[FieldSyncCheckpoint]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldSyncCheckpoint](
      checkpoint_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldSyncCheckpoint_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      sync_kind nvarchar(50) NOT NULL,
      source_table nvarchar(100) NULL,
      last_source_version nvarchar(200) NULL,
      last_event_sequence bigint NULL,
      last_success_at datetimeoffset(7) NULL,
      last_error_at datetimeoffset(7) NULL,
      last_error_code nvarchar(100) NULL,
      last_error_message nvarchar(1000) NULL,
      updated_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldSyncCheckpoint_UpdatedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldSyncCheckpoint PRIMARY KEY CLUSTERED(checkpoint_id)
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldSyncCheckpoint]') AND name=N'UX_FieldSyncCheckpoint_Kind')
    CREATE UNIQUE INDEX UX_FieldSyncCheckpoint_Kind ON [FieldTest].[FieldSyncCheckpoint](tenant_id,plant_id,sync_kind,source_table);

  IF OBJECT_ID(N'[FieldTest].[FieldSyncLog]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldSyncLog](
      sync_log_id bigint IDENTITY(1,1) NOT NULL,
      tenant_id nvarchar(64) NULL,
      plant_id uniqueidentifier NULL,
      agent_id nvarchar(100) NULL,
      log_level nvarchar(20) NOT NULL,
      sync_kind nvarchar(50) NULL,
      event_id uniqueidentifier NULL,
      photo_asset_id uniqueidentifier NULL,
      ocr_import_result_id uniqueidentifier NULL,
      code nvarchar(100) NULL,
      message nvarchar(2000) NOT NULL,
      details_json nvarchar(max) NULL,
      retryable bit NULL,
      created_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldSyncLog_CreatedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldSyncLog PRIMARY KEY CLUSTERED(sync_log_id)
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldSyncLog]') AND name=N'IX_FieldSyncLog_Search')
    CREATE INDEX IX_FieldSyncLog_Search ON [FieldTest].[FieldSyncLog](tenant_id,plant_id,created_at DESC,log_level) INCLUDE(agent_id,sync_kind,code,message);

  IF OBJECT_ID(N'[FieldTest].[FieldSyncAgentHealth]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldSyncAgentHealth](
      health_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      agent_id nvarchar(100) NOT NULL,
      agent_status nvarchar(30) NOT NULL,
      last_heartbeat_at datetimeoffset(7) NOT NULL,
      last_token_success_at datetimeoffset(7) NULL,
      last_import_success_at datetimeoffset(7) NULL,
      last_event_pull_success_at datetimeoffset(7) NULL,
      last_photo_materialize_success_at datetimeoffset(7) NULL,
      pending_photo_event_count int NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_PhotoEvent DEFAULT (0),
      pending_ocr_event_count int NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_OcrEvent DEFAULT (0),
      queued_materialize_count int NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_Queued DEFAULT (0),
      failed_materialize_count int NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_Failed DEFAULT (0),
      oldest_materialize_queued_at datetimeoffset(7) NULL,
      photo_local_file_failed_count int NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_FileFailed DEFAULT (0),
      disk_free_bytes bigint NULL,
      disk_warning bit NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_DiskWarning DEFAULT (0),
      last_error_code nvarchar(100) NULL,
      last_error_message nvarchar(1000) NULL,
      updated_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldSyncAgentHealth_UpdatedAt DEFAULT SYSDATETIMEOFFSET(),
      CONSTRAINT PK_FieldSyncAgentHealth PRIMARY KEY CLUSTERED(health_id)
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldSyncAgentHealth]') AND name=N'UX_FieldSyncAgentHealth_Agent')
    CREATE UNIQUE INDEX UX_FieldSyncAgentHealth_Agent ON [FieldTest].[FieldSyncAgentHealth](tenant_id,plant_id,agent_id);

  IF OBJECT_ID(N'[FieldTest].[FieldSyncAgentLease]', N'U') IS NULL
  BEGIN
    CREATE TABLE [FieldTest].[FieldSyncAgentLease](
      lease_id uniqueidentifier NOT NULL CONSTRAINT DF_FieldSyncAgentLease_Id DEFAULT NEWSEQUENTIALID(),
      tenant_id nvarchar(64) NOT NULL,
      plant_id uniqueidentifier NOT NULL,
      agent_id nvarchar(100) NOT NULL,
      lease_token uniqueidentifier NOT NULL CONSTRAINT DF_FieldSyncAgentLease_Token DEFAULT NEWID(),
      acquired_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldSyncAgentLease_AcquiredAt DEFAULT SYSDATETIMEOFFSET(),
      renewed_at datetimeoffset(7) NOT NULL CONSTRAINT DF_FieldSyncAgentLease_RenewedAt DEFAULT SYSDATETIMEOFFSET(),
      expires_at datetimeoffset(7) NOT NULL,
      released_at datetimeoffset(7) NULL,
      machine_name nvarchar(128) NULL,
      process_id int NULL,
      CONSTRAINT PK_FieldSyncAgentLease PRIMARY KEY CLUSTERED(lease_id)
    );
  END;
  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'[FieldTest].[FieldSyncAgentLease]') AND name=N'UX_FieldSyncAgentLease_Active')
    CREATE UNIQUE INDEX UX_FieldSyncAgentLease_Active ON [FieldTest].[FieldSyncAgentLease](tenant_id,plant_id) WHERE released_at IS NULL;

  COMMIT TRANSACTION;
END TRY
BEGIN CATCH
  IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO

-- Optional initial validation rules. Confirm operational ranges before production.
IF NOT EXISTS (SELECT 1 FROM [FieldTest].[FieldOcrValidationRule] WHERE tenant_id=N'*' AND plant_id IS NULL AND canonical_key=N'slump')
BEGIN
  INSERT [FieldTest].[FieldOcrValidationRule](tenant_id,plant_id,canonical_key,value_type,unit,min_numeric_value,max_numeric_value,max_length,decimal_scale,warning_threshold,range_outcome)
  VALUES
    (N'*',NULL,N'slump',N'number',N'cm',0,30,NULL,1,0.80,N'needs_review'),
    (N'*',NULL,N'air',N'number',N'%',0,15,NULL,1,0.80,N'needs_review'),
    (N'*',NULL,N'concrete_temperature',N'number',N'℃',0,50,NULL,1,0.80,N'needs_review'),
    (N'*',NULL,N'outside_temperature',N'number',N'℃',-20,50,6,1,0.80,N'needs_review'),
    (N'*',NULL,N'unit_volume_mass',N'number',N'kg/m3',1500,2800,NULL,1,0.80,N'needs_review'),
    (N'*',NULL,N'unit_water',N'number',N'kg/m3',100,250,NULL,1,0.80,N'needs_review'),
    (N'*',NULL,N'remarks',N'string',NULL,NULL,NULL,10,NULL,0.80,N'needs_review');
END;
GO

/* 起動前確認用: 12テーブルとスキーマの存在 */
SELECT
  DB_NAME() AS shipping_database_name,
  SCHEMA_NAME(t.schema_id) AS schema_name,
  t.name AS table_name
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID(N'FieldTest')
ORDER BY t.name;
GO

/*
  権限付与例（実環境のサービスアカウント名に合わせて実施）

  IF DATABASE_PRINCIPAL_ID(N'FieldTestSyncAgentRole') IS NULL
    CREATE ROLE [FieldTestSyncAgentRole];

  GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::[FieldTest]
    TO [FieldTestSyncAgentRole];

  -- 既存の予定・出荷テーブルは必要最小限のSELECTのみを個別付与する。
  GRANT SELECT ON [dbo].[YoteiDataMain] TO [FieldTestSyncAgentRole];
  GRANT SELECT ON [dbo].[SyukkaDataMain] TO [FieldTestSyncAgentRole];
*/
