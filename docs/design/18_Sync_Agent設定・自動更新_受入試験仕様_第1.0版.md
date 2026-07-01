# 18_Sync_Agent設定・自動更新_受入試験仕様

版数: 第1.0版

## 本書の位置づけ

本書は、Sync Agent設定、自動更新、Provider診断に関する受入試験を定義する。受入試験では、入口設定ファイルパス指定、FieldTest登録、非使用DBの扱い、秘密値マスク、Provider自動切替禁止を確認する。

## 1. 受入条件一覧

|ID|分類|条件|重要度|
|---|---|---|---|
|A-001|Provider|ProviderがLabonityまたはLibertyとして明示設定され、自動判定されない。|必須|
|A-002|Provider|Provider不一致設定があっても実行Provider以外の入口設定ファイルを参照しない。|必須|
|A-003|Labonity|LibLocal.xmlの完全パスをSync Agent設定で指定できる。|必須|
|A-004|Labonity|LibLocal.xmlからp_サーバーフォルダパスを取得できる。|必須|
|A-005|Labonity|LibertyDatabaseSetting.xmlからマスターDB、出荷管理DB、共通設定DBを取得できる。|必須|
|A-006|Liberty|LIBLocal.Iniの完全パスをSync Agent設定で指定できる。|必須|
|A-007|Liberty|LIBLocal.Iniからサーバーパスを取得できる。|必須|
|A-008|Liberty|LIBCTRL.iniから共通マスタDB、出荷データDB、初期工場コードを取得できる。|必須|
|A-009|DB範囲|品質系DBが未接続でもOCR同期が開始できる。|必須|
|A-010|DB範囲|出荷DBにFieldTestスキーマを作成できる。|必須|
|A-011|DB範囲|FieldTest Migrationが再実行安全である。|必須|
|A-012|DB範囲|両Providerで同一FieldTest DDLを適用できる。|必須|
|A-013|読取|予定データをDTOへ変換できる。|必須|
|A-014|読取|出荷実績データをDTOへ変換できる。|必須|
|A-015|読取|現場マスターをDTOへ変換できる。|必須|
|A-016|登録|TestResultをFieldTestへ登録できる。|必須|
|A-017|登録|TestPhotoをFieldTestへ登録できる。|必須|
|A-018|登録|OcrResultをFieldTestへ登録できる。|必須|
|A-019|登録|同一eventId再送時に重複登録しない。|必須|
|A-020|登録|OCR主写真は同一resultで1件に制限される。|必須|
|A-021|写真|写真本体をBase64文字列のDB正本にしない。|必須|
|A-022|写真|写真SHA-256を記録できる。|必須|
|A-023|写真|保存先URIまたはローカルパスを記録できる。|必須|
|A-024|同期|通信断時にローカルキューへ保持できる。|必須|
|A-025|同期|復旧時に順序性を保って送信できる。|必須|
|A-026|同期|SyncStateにcursorとlast_synced_atを保存できる。|必須|
|A-027|監査|設定解決結果を監査できる。|必須|
|A-028|監査|秘密値をマスクできる。|必須|
|A-029|監査|登録、更新、エラーを監査できる。|必須|
|A-030|更新|manifest署名を検証できる。|必須|
|A-031|更新|SHA-256検証後に更新できる。|必須|
|A-032|更新|失敗時に前回安定版へ戻せる。|必須|
|A-033|セキュリティ|Agent credentialと個人アカウントを分離できる。|必須|
|A-034|セキュリティ|SQLパスワードをログに出さない。|必須|
|A-035|運用|Provider診断結果をヘルスチェックに出せる。|必須|
|A-036|運用|DB名は設定ファイル値を正として扱う。|必須|
|A-037|運用|サンプルDB名を固定接続値にしない。|必須|
|A-038|Providerアプリ|ProviderアプリはFieldTestスキーマ参照で結果を取得できる。|必須|
|A-039|境界|Sync AgentはProviderアプリの画面実装に依存しない。|必須|
|A-040|受入|要件と受入条件が追跡表で確認できる。|必須|

## 2. 試験データ

- Labonity: `LibLocal.xml`、`LibertyDatabaseSetting.xml`、代表出荷DB、代表マスターDB、FieldTest Migration適用先。
- Liberty: `LIBLocal.Ini`、`LIBCTRL.ini`、代表出荷DB、代表マスターDB、FieldTest Migration適用先。
- 共通: 写真1件、OCR結果1件、試験結果1件、同一eventId再送1件、Provider設定エラー1件。

## 3. 合否基準

必須条件がすべて合格し、秘密値がログに平文出力されず、Providerの自動切替が発生せず、登録結果が`FieldTest`スキーマに確認できること。


## 6. 設定診断受入試験

|ID|条件|期待結果|
|---|---|---|
|AT-DB-001|Labonityの`p_SQLサーバー名`が空欄|`CFG-DB-001`で停止し、`localhost`等へ補完しない。|
|AT-DB-002|Libertyの`ＳＱＬサーバー名`が空欄|`CFG-DB-001`で停止し、他Provider設定へfallbackしない。|
|AT-MIG-001|FieldTestが未作成|Migrationが適用され、`SchemaMigration`へ記録される。|
|AT-MIG-002|FieldTestの列型が互換不能|Migrationは停止し、`MIG-001`を監査する。|
|AT-IDEMP-001|同一eventIdを再送|重複登録せず成功扱い。|
|AT-IDEMP-002|別eventIdで同一source_result_keyを再送|重複登録せず成功扱い。|
|AT-PHOTO-001|別eventIdで同一result_id・photo_kind・sha256を再送|重複写真を作成しない。|
|AT-LEASE-001|期限切れleaseが存在|`usp_AcquireAgentLease`が同一トランザクションで旧leaseを解放扱いにし、新leaseを取得する。|
