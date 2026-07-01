# 27_Migration・冪等性・Lease詳細仕様

版数: 第1.0版

## 本書の位置づけ

本書は、FieldTest Migration、source key生成、再送安全、Agent lease取得手順を定義する。両Providerとも出荷DB内の固定スキーマ`FieldTest`を使用する。

## 1. Migration単位

|Migration|内容|
|---|---|
|V001_CoreSchema|SchemaMigration、ProviderConfigSnapshot、SourceShipmentMap、SyncState、TestResult、TestPhoto、OcrResult、AuditEventを作成する。|
|V002_EventQueuesAndIndexes|InboundEvent、OutboxEvent、冪等性index、写真重複防止index、OCR主写真一意indexを作成する。|
|V003_ProviderAppViews|Providerアプリ参照Viewを作成する。|
|V004_AgentLeaseProcedures|AgentLease、lease取得・解放procedureを作成する。|

各Migrationは`SchemaMigration`へ`migration_id`、`checksum_sha256`、`applied_at`、`description`を記録する。既存オブジェクトの列・型・制約・indexが互換不能な場合は、黙って続行せず`MIG-001`として停止する。

## 2. source_shipment_key

source keyは、Provider別既存キーをcanonical JSONに変換して生成する。canonical JSONは次の規則を守る。

- UTF-8でSHA-256を計算する。
- プロパティ順序を仕様書の順序で固定する。
- 日付は`YYYY-MM-DD`、日時はUTC ISO-8601に統一する。
- NULLはJSONの`null`で表す。
- 文字列は前後空白を除去し、内部空白は原則保持する。
- `sourceKeyVersion`を必ず含める。

## 3. source_result_key

source_result_keyは、source_shipment_keyのcanonical JSONに、`sikenKubun`、`isTatewari`、`groupNo`、`dataKubun`を追加して生成する。これにより、同一出荷に複数試験結果が存在しても一意に識別できる。

## 4. 冪等性

|対象|冪等条件|
|---|---|
|TestResult|`event_id`、または`provider + plant_id + source_result_key_version + source_result_key_hash_sha256`が一致。|
|TestPhoto|`event_id`、または`result_id + photo_kind + sha256`が一致。|
|OcrResult|`event_id`、または`result_id + photo_id + ocr_status + normalized_json_hash`が一致。|
|InboundEvent|`event_id`が一致。|
|OutboxEvent|`event_id`が一致。|

同一自然キーで内容が異なる場合は、上書きせず競合として監査する。上書きが必要な運用は、Providerアプリまたは管理機能の明示操作として扱う。

## 5. Agent lease

Agent leaseは、`FieldTest.usp_AcquireAgentLease`で取得する。procedureは同一トランザクション内で、期限切れactive leaseに`released_at`を設定し、同じ`resource_name`のactive leaseが存在しないことを確認して新leaseを挿入する。`UPDLOCK`と`HOLDLOCK`で競合を抑止する。直接INSERTによるlease取得は禁止する。

## 6. SQL Server名空欄時の停止

設定診断においてSQL Server名が空欄の場合は、DB接続、Migration、lease取得の前に停止する。補完、推測、fallbackは行わない。
