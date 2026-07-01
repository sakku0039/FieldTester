# 22_Provider別設定ファイル解決仕様

版数: 第1.0版

## 本書の位置づけ

本書は、Provider別の入口設定ファイルパス、派生設定ファイル、DB名解決、診断結果を定義する。Labonityは`LibLocal.xml`から`LibertyDatabaseSetting.xml`を、Libertyは`LIBLocal.Ini`から`LIBCTRL.ini`を解決する。品質系DB・写真台帳DB等は第1.0版OCR同期の必須接続先にしない。

## 1. 入口設定ファイルパス

両Providerとも、入口設定ファイルまでのパスはSync Agent設定に保持する。環境ごとのインストール先や共有フォルダ構成を推測せず、管理者が指定したパスを正とする。

|Provider|Sync Agent設定項目|入口設定ファイル|役割|
|---|---|---|---|
|Labonity|`labonity.libLocalXmlPath`|`LibLocal.xml`|サーバーフォルダを取得する。|
|Liberty|`liberty.libLocalIniPath`|`LIBLocal.Ini`|サーバーパスを取得する。|

## 2. Labonity解決仕様

Labonity Providerは、Sync Agent設定の`labonity.libLocalXmlPath`から`LibLocal.xml`を読み取る。XML要素`p_サーバーフォルダパス`の値を取得し、パス正規化、存在確認、読取権限確認を行う。次に、そのフォルダ配下にある`LibertyDatabaseSetting.xml`を読み取る。

|XML要素|Sync Agent内部項目|第1.0版OCR同期での扱い|
|---|---|---|
|`p_SQLプロバイダー名`|sqlProviderName|使用する。|
|`p_SQLサーバー名`|sqlServerName|必須。空欄・空白のみの場合は`CFG-DB-001`で停止し、補完しない。|
|`p_SQLユーザーID`|sqlUserId|使用する。監査ではマスクする。|
|`p_SQLパスワード`|sqlPasswordSecret|使用する。ログへ出さない。|
|`p_マスターデータベース名`|masterDatabaseName|使用する。|
|`p_出荷管理データベース名`|shippingDatabaseName|使用する。`FieldTest`スキーマ作成先。|
|`p_品質管理データベース名`|ignoredDatabaseNames.quality|使用しない。必須接続先にしない。|
|`p_販売管理データベース名`|ignoredDatabaseNames.sales|使用しない。|
|`p_動荷重データベース名`|ignoredDatabaseNames.dynamicLoad|使用しない。|
|`p_共通設定データベース名`|settingsDatabaseName|設定・診断用に保持する。|

## 3. Liberty解決仕様

Liberty Providerは、Sync Agent設定の`liberty.libLocalIniPath`から`LIBLocal.Ini`をCP932として読み取る。`[端末設定]`の`サーバーパス`を取得し、パス正規化、存在確認、読取権限確認を行う。次に、そのフォルダ配下にある`LIBCTRL.ini`をCP932として読み取る。

|INIキー|Sync Agent内部項目|第1.0版OCR同期での扱い|
|---|---|---|
|`ＳＱＬプロバイダー名`|sqlProviderName|使用する。|
|`ＳＱＬサーバー名`|sqlServerName|必須。空欄・空白のみの場合は`CFG-DB-001`で停止し、補完しない。|
|`ＳＱＬユーザーＩＤ`|sqlUserId|使用する。監査ではマスクする。|
|`ＳＱＬパスワード`|sqlPasswordSecret|使用する。ログへ出さない。|
|`共通マスタＤＢ名`|masterDatabaseName|使用する。現場等の読取元。|
|`出荷データＤＢ名`|shippingDatabaseName|使用する。`FieldTest`スキーマ作成先。|
|`初期工場コード`|defaultPlantCode|使用する。plantCode未指定時の既定値。|
|`工場コード使用`|plantCodeUsage|工場コード正規化に使用する。|
|`品管データＤＢ名`|ignoredDatabaseNames.quality|使用しない。必須接続先にしない。|
|`品管データ2ＤＢ名`|ignoredDatabaseNames.quality2|使用しない。|
|`写真台帳データＤＢ名`|ignoredDatabaseNames.photoLedger|使用しない。|
|`販売データＤＢ名` / `受払データＤＢ名`等|ignoredDatabaseNames.other|使用しない。|

## 4. 禁止事項

- 設定ファイルが存在しない場合に既定パスを総当たりしない。
- Labonity設定からLiberty設定へ、またはLiberty設定からLabonity設定へ自動切替しない。
- サンプルDB名を固定値として接続しない。
- 品質DBや写真台帳DBを出荷DBの代替として推測利用しない。
- パスワードをログに出力しない。

## 5. 診断結果

設定解決結果には、Provider、入口設定ファイルパス、派生設定ファイルパス、更新日時、解決した出荷DB名、マスターDB名、診断状態、エラーコード、秘密値マスク状態、未使用DB名を保持する。秘密値そのものは保持しない。


## 6. SQL Server名空欄時の扱い

SQL Server名は両Providerとも必須である。空欄、空白のみ、XML要素またはINIキー欠落の場合は`CFG-DB-001`として設定診断を失敗させる。Sync Agentは、次のいずれも行わない。

- `localhost`、`.`、`(local)`、端末名、既定インスタンスへの補完。
- サンプルDB名、過去接続履歴、別ProviderのSQL Server名の利用。
- SQL Server名が空欄のままDB名だけで接続する処理。

この診断はMigrationより前に実施する。
