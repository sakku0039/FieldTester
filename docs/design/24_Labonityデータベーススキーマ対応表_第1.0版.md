# 24_Labonityデータベーススキーマ対応表

版数: 第1.0版

## 本書の位置づけ

本書は、Labonity Providerにおける既存DB読取元、共通DTO、FieldTest登録先の対応を定義する。Labonity ProviderはSync Agent設定で指定した`LibLocal.xml`から`LibertyDatabaseSetting.xml`を解決し、SQL Server名、マスターDB、出荷管理DB、共通設定DBを取得する。`p_SQLサーバー名`が空欄の場合は設定エラーとして停止する。

## 1. DB解決

|項目|設定要素|内部項目|扱い|
|---|---|---|---|
|SQL Server|`p_SQLサーバー名`|sqlServerName|必須。空欄は`CFG-DB-001`。|
|マスターDB|`p_マスターデータベース名`|masterDatabaseName|現場マスター等の読取元。|
|出荷管理DB|`p_出荷管理データベース名`|shippingDatabaseName|予定・出荷読取元、および`FieldTest`登録先。|
|共通設定DB|`p_共通設定データベース名`|settingsDatabaseName|設定診断用に保持。|
|品質管理DB|`p_品質管理データベース名`|ignoredDatabaseNames.quality|第1.0版OCR同期では非使用。|

## 2. 予定データ読取

|共通DTO|Labonity読取元|変換|
|---|---|---|
|provider|固定値`Labonity`|文字列固定。|
|plantId|Sync Agent設定|GUID。|
|plantCode|Sync Agent設定またはProvider値|表示・工場識別用。|
|source_yotei_id|`NaDat.YoteiDataMain.yotei_id`|GUIDとして保持。|
|shipment_date|`NaDat.YoteiDataMain.syukka_yoteibi`|dateへ正規化。|
|shipment_no|`NaDat.YoteiDataMain.yotei_no`|文字列化。|
|site_id|`NaDat.YoteiDataMain.genba_id`|GUIDとして保持。|
|site_name|`kozi_mei1` + `kozi_mei2`|空白を整理して連結。|

## 3. 出荷実績読取

|共通DTO|Labonity読取元|変換|
|---|---|---|
|source_syukka_id|`NaDat.SyukkaDataMain.syukka_id`|GUIDとして保持。|
|source_yotei_id|`NaDat.SyukkaDataMain.yotei_id`|予定との紐づけ。|
|shipment_date|`NaDat.SyukkaDataMain.syukka_yoteibi`|dateへ正規化。|
|shipment_no|`NaDat.SyukkaDataMain.seq_no`|表示用文字列へ変換。|
|shipment_quantity|`NaDat.SyukkaDataMain.syukkaryo`|decimalへ変換。|
|production_quantity|`NaDat.SyukkaDataMain.seizoryo`|decimalへ変換。|
|mix_text|伝票印字・配合表系|第1.0版では表示補助。|

## 4. 現場マスター読取

|共通DTO|Labonity読取元|変換|
|---|---|---|
|site_id|`MsDat.Genba.id`|GUID。|
|site_name|`genba_mei1` + `genba_mei2`|検索・表示用。|
|site_short_name|`ryakusyo`|任意。|
|address|`zyusyo1` + `zyusyo2`|任意。|
|phone|`denwabangou`|任意。|
|latitude|`ido`|存在する場合のみ使用。|
|longitude|`keido`|存在する場合のみ使用。|

## 5. FieldTest登録先

|登録対象|登録DB|スキーマ|テーブル|
|---|---|---|---|
|出荷対応|解決した出荷管理DB|FieldTest|SourceShipmentMap|
|試験結果|解決した出荷管理DB|FieldTest|TestResult|
|写真メタデータ|解決した出荷管理DB|FieldTest|TestPhoto|
|OCR結果|解決した出荷管理DB|FieldTest|OcrResult|
|同期状態|解決した出荷管理DB|FieldTest|SyncState|
|受信イベント|解決した出荷管理DB|FieldTest|InboundEvent|
|送信イベント|解決した出荷管理DB|FieldTest|OutboxEvent|

## 6. Labonity source key生成

`source_shipment_key`は次のcanonical JSONから生成する。プロパティ順序、日付形式、NULL表現を固定し、UTF-8のSHA-256を保存する。

```json
{
  "provider": "Labonity",
  "sourceKeyVersion": 1,
  "plantId": "<GUID>",
  "plantCode": "<plantCode>",
  "shippingDatabase": "<p_出荷管理データベース名>",
  "yoteiId": "<YoteiDataMain.yotei_id>",
  "syukkaId": "<SyukkaDataMain.syukka_id or null>",
  "shipmentDate": "YYYY-MM-DD",
  "yoteiNo": "<YoteiDataMain.yotei_no>",
  "seqNo": "<SyukkaDataMain.seq_no or null>"
}
```

`source_result_key`は、上記に`sikenKubun`、`isTatewari`、`groupNo`、`dataKubun`を追加して生成する。

## 7. 品質DBとの境界

`ExDat`のTP採取、供試体、強度試験系テーブルは第1.0版OCR同期の読取元・登録先にしない。OCR確認値は出荷管理DB内`FieldTest`で完結する。
