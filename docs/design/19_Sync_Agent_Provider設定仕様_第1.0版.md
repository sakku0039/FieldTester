# 19_Sync_Agent_Provider設定仕様

版数: 第1.0版

## 本書の位置づけ

本書は、Sync Agentが保持するProvider設定JSON、解決結果モデル、失敗時の扱いを定義する。入口設定ファイルまでのパスはSync Agent設定を正とし、サンプルDB名や既定パスによる推測接続は行わない。

## 1. 設定JSON例

```json
{
  "provider": "Labonity",
  "tenantId": "00000000-0000-0000-0000-000000000000",
  "orgId": "00000000-0000-0000-0000-000000000000",
  "plantId": "00000000-0000-0000-0000-000000000000",
  "plantCode": "0001",
  "labonity": {
    "libLocalXmlPath": "C:/Labonity/Config/LibLocal.xml",
    "databaseSettingFileName": "LibertyDatabaseSetting.xml"
  },
  "liberty": {
    "libLocalIniPath": "C:/Liberty/Config/LIBLocal.Ini",
    "libctrlFileName": "LIBCTRL.ini"
  },
  "photoStorageMode": "FileReference",
  "enableSync": true,
  "updateChannel": "stable"
}
```

Windowsパスをバックスラッシュで記述する場合は、JSON仕様に従い`C:\\Labonity\\Config\\LibLocal.xml`のようにエスケープする。資料内の例は可読性のためスラッシュ形式を正とする。Providerに一致しない設定ブロックは保持してよいが、実行時には参照しない。`FieldTest`スキーマ名は固定であり、設定JSONでは変更しない。

## 2. 解決結果モデル

|項目|内容|
|---|---|
|provider|`Labonity`または`Liberty`。|
|entryConfigPath|Sync Agent設定で指定された入口設定ファイルの完全パス。|
|derivedConfigPath|Labonityでは`LibertyDatabaseSetting.xml`、Libertyでは`LIBCTRL.ini`の解決後パス。|
|sqlProviderName|SQLOLEDB等。|
|sqlServerName|設定ファイルから取得したSQL Server名。空欄・空白のみの場合は`CFG-DB-001`で停止し、補完しない。|
|sqlUserId|設定ファイルまたは資格情報ストアから取得する。監査ではマスクする。|
|masterDatabaseName|Labonityは`p_マスターデータベース名`、Libertyは`共通マスタＤＢ名`。|
|shippingDatabaseName|Labonityは`p_出荷管理データベース名`、Libertyは`出荷データＤＢ名`。|
|settingsDatabaseName|Labonityは`p_共通設定データベース名`。Libertyでは`LIBCTRL.ini`のシステム設定を設定情報として扱う。|
|plantCode|LabonityはSync Agent設定またはDB値、Libertyは`初期工場コード`から導出した値を既定とする。|
|resultWriteMode|`FieldTestSchema`。両Provider共通。|
|ignoredDatabaseNames|設定ファイルに存在しても第1.0版OCR同期で接続・同期対象にしないDB名。例: 品質DB、写真台帳DB、販売DB。|

## 3. OCR同期で使用するDB

|Provider|読取DB|登録DB|使わないDB|
|---|---|---|---|
|Labonity|マスターDB、出荷管理DB|出荷管理DBの`FieldTest`スキーマ|品質管理DB、販売管理DB、動荷重DB|
|Liberty|共通マスタDB、出荷データDB|出荷データDBの`FieldTest`スキーマ|品管データDB、品管データ2DB、写真台帳DB、販売DB、受払DB|

## 4. 失敗時の扱い

設定ファイルが存在しない、文字コードが読めない、必須キーがない、SQL Server名が空欄、DBへ接続できない、Migration診断に失敗した場合は設定エラーとして停止する。Providerの推測や自動切替は行わない。SQL Server名については`localhost`、`.`、端末名、既定インスタンス、サンプル値、他Provider設定値による補完を禁止する。品質DBや写真台帳DBの未設定・未接続は、第1.0版OCR同期の停止条件にしない。


## 5. 設定エラーコード

|コード|発生条件|処理|
|---|---|---|
|CFG-001|入口設定ファイルパスが未設定または存在しない|Provider診断を失敗させ同期停止。|
|CFG-002|派生設定ファイルを解決できない|Provider診断を失敗させ同期停止。|
|CFG-003|設定ファイルの文字コードまたはXML構造が不正|Provider診断を失敗させ同期停止。|
|CFG-DB-001|SQL Server名が空欄または空白のみ|補完せず同期停止。|
|CFG-DB-002|出荷DB名またはマスターDB名が空欄|補完せず同期停止。|
|CFG-SEC-001|秘密値を安全に取得できない|同期停止。|
