# 20_Libertyデータベーススキーマ対応表

版数: 第1.0版

## 本書の位置づけ

本書は、Liberty Providerにおける既存DB読取元と`FieldTest`登録先の対応を定義する。Liberty Providerでは`LIBLocal.Ini`から`LIBCTRL.ini`を解決し、出荷データDB内の`FieldTest`スキーマへ登録する。`SyukkaFresh`および`SyukkaFreshPicture`へSync Agentが直接書き込む仕様ではない。

## 1. Liberty ProviderのDB解決

Liberty Providerは、Sync Agent設定の`liberty.libLocalIniPath`で指定された`LIBLocal.Ini`を読み、`[端末設定] サーバーパス`から`LIBCTRL.ini`を解決する。`LIBCTRL.ini`の`共通マスタＤＢ名`を現場等の読取元、`出荷データＤＢ名`を予定・出荷の読取元および出荷データDBの`FieldTest`スキーマ登録先として使用する。

## 2. Liberty読取元

|用途|DB区分|代表DB名|代表テーブル|扱い|
|---|---|---|---|---|
|出荷予定|出荷データDB|LSYUDAT|Yotei1 / Yotei2 / Yotei3|読取|
|出荷実績|出荷データDB|LSYUDAT|Syukka1 / Syukka2 / Syukka3|読取|
|現場|共通マスタDB|LMASTER|Genba|読取|
|工場コード|LIBCTRL.ini|なし|初期工場コード|設定値|

実環境のDB名は`LIBCTRL.ini`の値を正とし、代表DB名を固定値として接続しない。

## 3. Liberty登録先

|用途|登録DB|スキーマ|テーブル|扱い|
|---|---|---|---|---|
|出荷識別対応|出荷データDB|FieldTest|SourceShipmentMap|登録・更新|
|フレッシュ試験結果|出荷データDB|FieldTest|TestResult|登録・更新|
|写真メタデータ|出荷データDB|FieldTest|TestPhoto|登録・更新|
|OCR結果|出荷データDB|FieldTest|OcrResult|登録・更新|
|同期状態|出荷データDB|FieldTest|SyncState|登録・更新|
|設定診断|出荷データDB|FieldTest|ProviderConfigSnapshot|登録・更新|

## 4. DTO変換

|FieldTest項目|Liberty由来|備考|
|---|---|---|
|provider|固定値`Liberty`|Provider識別。|
|plantCode|`初期工場コード`またはSync Agent設定|plantIdとは分離する。|
|sourceShipmentKey|出荷予定・出荷実績の複合キー|canonical JSONとSHA-256で保持する。|
|shipmentDate|予定日または出荷日|日付型へ正規化する。|
|shipmentNo|当日予定No、SEQ等|表示・検索用。|
|siteName|Genbaまたは出荷データの現場名|現場マスターが取得できない場合は出荷側名称を使用する。|
|slump / flow / air等|現場アプリ入力値またはOCR確認値|FieldTest.TestResultへ登録する。|
|photo metadata|クラウド写真情報|FieldTest.TestPhotoへ登録する。|

## 5. Providerアプリケーション連携

Liberty側アプリケーションは、出荷データDB内の`FieldTest`スキーマを参照して現場試験アプリの結果を取得する。Sync Agentは`FieldTest`登録、同期状態、監査までを担当し、Liberty側画面・帳票・参照SQLの実装には依存しない。

## 6. 既存フレッシュテーブル資料の扱い

既存フレッシュテーブル資料は、列名、試験区分、写真の持ち方、過去互換用語を理解するための参考資料として収録する。第1.0版のSync Agentは、既存フレッシュテーブルを正規登録先にしない。


## 7. Liberty source key生成

Libertyの`source_shipment_key`は、設定解決結果と既存出荷DB読取値から次のcanonical JSONを生成する。プロパティ順序、日付形式、NULL表現を固定し、UTF-8のSHA-256を`source_key_hash_sha256`へ保存する。

```json
{
  "provider": "Liberty",
  "sourceKeyVersion": 1,
  "plantId": "<GUID>",
  "plantCode": "<初期工場コードまたは出荷側工場コード>",
  "shippingDatabase": "<出荷データDB名>",
  "sourceTable": "Syukka1/Syukka2/Syukka3 または Yotei1/Yotei2/Yotei3",
  "syukkaYoteibi": "YYYY-MM-DD",
  "tozituYoteiNo": "<当日予定No>",
  "itinitiRenban": "<1日連番>",
  "syukkaSeqNo": "<出荷SEQまたはnull>"
}
```

試験結果の`source_result_key`は、上記に`sikenKubun`、`isTatewari`、`groupNo`、`dataKubun`を追加したcanonical JSONから生成する。
