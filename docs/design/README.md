# 現場試験アプリ 設計資料一式 第1.0版

このフォルダは、現場試験アプリの第1.0版設計資料一式である。

ProviderはSync Agent設定で`Labonity`または`Liberty`を明示選択する。両Providerとも入口設定ファイルまでの完全パスをSync Agent設定で指定し、解決した出荷DB内の固定スキーマ`FieldTest`へ結果、写真、OCR、同期状態を登録する。

Labonityでは`LibLocal.xml`から`LibertyDatabaseSetting.xml`を解決する。Libertyでは`LIBLocal.Ini`から`LIBCTRL.ini`を解決する。SQL Server名が空欄の場合は設定エラーとして停止し、補完やfallbackは行わない。

品質系DB、写真台帳DB、販売DB等は第1.0版OCR同期の必須接続先・同期対象に含めない。source key、Migration、API契約、Providerアプリ参照View、受入条件を第1.0版の初期仕様として定義する。

共通基本原則は、00・01・02・99の各資料に全文を掲載する。詳細設計書、対応表、チェックリストでは、各資料に関係する原則だけを短く示す。
