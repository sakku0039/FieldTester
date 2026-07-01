# 26_FieldTest参照ビュー仕様

版数: 第1.0版

## 本書の位置づけ

本書は、Providerアプリケーションが参照する`FieldTest`スキーマのViewを定義する。Sync AgentはView提供までを担当し、Providerアプリの画面・帳票・検索実装には依存しない。

## 1. View一覧

|View|用途|
|---|---|
|`FieldTest.v_ProviderApp_TestResult`|試験結果一覧・詳細表示。|
|`FieldTest.v_ProviderApp_TestPhoto`|写真一覧・写真参照。|
|`FieldTest.v_ProviderApp_OcrResult`|OCR候補、確認結果、信頼度表示。|
|`FieldTest.v_ProviderApp_ShipmentResultStatus`|出荷単位の試験結果有無、写真件数、OCR状態表示。|

## 2. `v_ProviderApp_TestResult`

|列|内容|
|---|---|
|result_id|FieldTest試験結果ID。|
|provider|`Labonity`または`Liberty`。|
|plant_id / plant_code|拠点識別。|
|source_shipment_key / hash|既存出荷対応キー。|
|source_result_key / hash|試験結果自然キー。|
|shipment_date / shipment_no|出荷日・番号。|
|site_id / site_name|現場ID・現場名。|
|siken_kubun / is_tatewari / group_no|試験区分、縦割、グループ。|
|slump_text / slump_value|スランプ。|
|flow1_text / flow1_value / flow2_text / flow2_value|フロー。|
|air_text / air_value|空気量。|
|concrete_temperature_text / concrete_temperature_value|コンクリート温度。|
|result_status|Confirmed等。|
|photo_count / ocr_primary_photo_id|写真件数・OCR主写真。|
|ocr_status / ocr_confidence|OCR確認状態・信頼度。|
|confirmed_at / updated_at|確認日時・更新日時。|

## 3. `v_ProviderApp_TestPhoto`

写真の`photo_id`、`result_id`、`photo_kind`、`mime_type`、`file_size`、`sha256`、`storage_uri`、`local_file_path`、`is_ocr_primary`、`captured_at`を返す。写真本体をDB内Base64文字列として返さない。

## 4. `v_ProviderApp_OcrResult`

OCR確認結果の`ocr_result_id`、`result_id`、`photo_id`、`ocr_status`、`confidence`、`normalized_json`、`confirmed_at`、`confirmed_by_user_id`を返す。Providerアプリは必要に応じて`normalized_json`を展開する。

## 5. `v_ProviderApp_ShipmentResultStatus`

出荷単位に、試験結果件数、写真件数、OCR確認済件数、最終更新日時を返す。Providerアプリ側の一覧画面はこのViewを使うことで、試験結果の有無を出荷一覧へ付加できる。

## 6. 権限

Providerアプリ用DBユーザーには、原則として`FieldTest.v_ProviderApp_*`へのSELECT権限のみを付与する。直接テーブル更新はSync Agent専用権限とする。
