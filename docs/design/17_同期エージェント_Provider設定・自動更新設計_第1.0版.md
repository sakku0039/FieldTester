# 17_同期エージェント_Provider設定・自動更新設計

版数: 第1.0版

## 本書の位置づけ

本書は、Sync AgentのProvider設定、設定診断、自動更新、ロールバックを定義する。Providerは明示選択とし、選択Providerに対応する入口設定ファイルのみを読み取る。更新前後の診断に失敗した場合は同期を開始しない。

## 1. Sync Agent設定項目

|項目|型|必須|内容|
|---|---|---|---|
|provider|enum|○|`Labonity`または`Liberty`。|
|tenantId|guid|○|クラウドテナントID。|
|orgId|guid|○|組織ID。|
|plantId|guid|○|工場ID。|
|plantCode|string|△|Provider別工場コード。未指定時はProvider設定から導出する。|
|labonity.libLocalXmlPath|path|Labonity時○|Labonity用の入口設定ファイル`LibLocal.xml`までの完全パス。|
|labonity.databaseSettingFileName|string|Labonity時○|通常は`LibertyDatabaseSetting.xml`。|
|liberty.libLocalIniPath|path|Liberty時○|Liberty用の入口設定ファイル`LIBLocal.Ini`までの完全パス。|
|liberty.libctrlFileName|string|Liberty時○|通常は`LIBCTRL.ini`。|
|photoStorageMode|enum|○|FileReference、BlobReference、Hybrid。|
|sqlSecretStorage|enum|○|設定ファイル値を使用するか、OS資格情報ストアへ移管するか。|
|enableSync|bool|○|同期有効状態。|
|updateChannel|enum|○|stable、pilot、disabled。|

## 2. Labonity設定解決

1. `labonity.libLocalXmlPath`を読み取る。
2. `LibLocal.xml`の`p_サーバーフォルダパス`を取得する。
3. サーバーフォルダ配下の`LibertyDatabaseSetting.xml`を解決する。
4. SQL Server名、SQLユーザーID、SQLパスワード、マスターDB、出荷管理DB、共通設定DBを取得する。
5. 出荷管理DBへ接続し、`FieldTest` Migrationを確認する。
6. 品質管理DB名が存在しても第1.0版OCR同期では接続・同期・登録の必須対象にしない。

## 3. Liberty設定解決

1. `liberty.libLocalIniPath`をCP932として読み取る。
2. `[端末設定]`の`サーバーパス`を取得する。
3. サーバーパス配下の`LIBCTRL.ini`を解決する。
4. SQL Server名、SQLユーザーID、SQLパスワード、共通マスターDB、出荷データDB、初期工場コードを取得する。
5. 出荷データDBへ接続し、`FieldTest` Migrationを確認する。
6. 品管データDB名、品管データ2DB名、写真台帳データDB名が存在しても第1.0版OCR同期では接続・同期・登録の必須対象にしない。

## 4. 自動更新

自動更新はProviderに依存しない。manifest取得、署名検証、SHA-256検証、ファイル展開、サービス停止、差替、起動、ヘルスチェック、ロールバックを順に実行する。更新前後でProvider診断を実行し、同じProvider・同じ入口設定ファイルパスで起動できることを確認する。


## 7. DB名・SQL Server名の診断

Sync AgentはProvider解決時にSQL Server名、出荷DB名、マスターDB名を必須診断する。SQL Server名が空欄または空白のみの場合は`CFG-DB-001`として停止し、補完やfallbackを行わない。品質系DB名や写真台帳DB名は取得できても第1.0版OCR同期の必須接続先にしない。
