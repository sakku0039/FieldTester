# 現場試験アプリ Sync Agent
# 設定ファイル自動解決・旧 Liberty 対応・自動更新設計 第2.4版

| 項目 | 内容 |
|---|---|
| 文書区分 | 第2.2版統合設計に対する追加・置換設計 |
| 対象 | Sync Agent / Labonity / 旧 Liberty / SQL Server / 自動更新機構 |
| 版 | 2.4 |
| 目的 | 選択された基幹システムごとに既存設定ファイルを起点として、サーバーフォルダ、SQL Server、データベース名、工場コードを自動解決する。併せて、業務同期APIを変更せずに Sync Agent の自動更新を可能にする。 |
| 適用優先順位 | 本書の内容は、第2.2版の Sync Agent 設定解決に関する記載より優先する。特に、詳細設計書第1分冊の 20.10〜20.17、設定例、および「Labonity のみを前提とした起動時検証」を本書で拡張する。 |

---

## 1. 結論

Sync Agent の設定画面または `appsettings.json` で、ローカル基幹システムを次のいずれかから明示選択する。

| 表示名 | 内部値 | 起点ファイル |
|---|---|---|
| Labonity | `Labonity` | `LibLocal.xml` |
| Liberty（旧システム） | `LegacyLiberty` | `LIBLocal.Ini` |

自動判定は行わない。設定ファイルの内容から別プロバイダーへ自動フォールバックすることも禁止する。

```text
Labonity
  LibLocal.xml
    └─ p_サーバーフォルダパス
         └─ LibertyDatabaseSetting.xml
              └─ SQL Server / MsDat / NaDat / ExDat / LibertySettings 等

Liberty（旧システム）
  LIBLocal.Ini
    └─ [端末設定] サーバーパス
         └─ LIBCTRL.ini
              ├─ [コントロールマスター]
              │    ├─ SQL Server / SQL認証
              │    ├─ LMASTER / LSYUDAT / LHINDAT 等
              │    └─ 初期工場コード
              └─ [システム設定]
                   └─ 工場コード使用 等
```

ローカル設定解決後は、どちらのプロバイダーも共通の `ResolvedLocalSystemSettings` を生成する。以後の同期処理は共通 DTO と既存クラウド同期 API を利用するため、クラウドとの業務同期契約は変更しない。

---

## 2. 対象範囲

### 2.1 本書に含む

- Labonity の `LibLocal.xml` 起点設定解決
- 旧 Liberty の `LIBLocal.Ini` → `LIBCTRL.ini` 設定解決
- INI の文字コード、全角キー、コメント、重複キー、パス正規化
- SQL Server 接続設定の正規化
- 論理DB名の共通モデルへの割当
- 工場コードの解決
- 設定変更の安全な再読込
- 設定診断、エラーコード、ログマスキング
- Sync Agent 自動更新時の設定保持とロールバック
- 受入試験条件

### 2.2 本書に含まない

- 旧 Liberty の全業務テーブルの詳細項目マッピング
- 旧 PowerApps 画面の変更
- SQL Server の利用者パスワード変更手順
- クラウド API の新規業務エンドポイント

---

## 3. 共通構成

```text
Sync Agent Windows Service
  ├─ LocalSystemSettingResolver
  │    ├─ LabonitySettingResolver
  │    └─ LegacyLibertySettingResolver
  ├─ LocalBusinessDataProvider
  │    ├─ LabonityProvider
  │    └─ LegacyLibertyProvider
  ├─ CanonicalModelMapper
  ├─ CloudSyncClient              既存業務同期APIを使用
  ├─ HealthCheckService
  └─ AgentUpdateCoordinator       自動更新状態を連携

Sync Agent Updater
  ├─ ReleaseManifestClient
  ├─ PackageSignatureVerifier
  ├─ ServiceController
  ├─ BackupAndRollbackManager
  └─ PostUpdateHealthChecker
```

### 3.1 責務分離

`LocalSystemSettingResolver` は設定ファイルの読取と正規化だけを担当する。SQL クエリやクラウド同期は行わない。

`LocalBusinessDataProvider` は、正規化済みの接続情報を受け取り、各基幹システムの予定・出荷・現場を共通 DTO に変換する。

`CloudSyncClient` はデータの取得元を意識しない。

---

## 4. Sync Agent 設定

### 4.1 共通設定モデル

```json
{
  "SyncAgent": {
    "SourceSystem": {
      "Provider": "Labonity",
      "LocalSettingFilePath": "C:\\Labonity\\Settings\\LibLocal.xml",
      "FailOnAutoDetection": true,
      "ReloadOnSettingChanged": true,
      "ReloadPollSeconds": 60,
      "ReloadDebounceSeconds": 5,
      "SqlClient": {
        "Encrypt": true,
        "TrustServerCertificate": false,
        "ConnectTimeoutSeconds": 15,
        "CommandTimeoutSeconds": 60
      }
    }
  }
}
```

### 4.2 設定項目

| 項目 | 必須 | 内容 |
|---|---:|---|
| `Provider` | ○ | `Labonity` または `LegacyLiberty`。 |
| `LocalSettingFilePath` | ○ | Provider に対応する起点ファイルの絶対パス。 |
| `FailOnAutoDetection` | ○ | 常に `true`。設定ファイル内容による自動判定を禁止する。 |
| `ReloadOnSettingChanged` | ○ | 設定ファイル変更を安全に再読込するか。既定 `true`。 |
| `ReloadPollSeconds` | ○ | FileSystemWatcher の取りこぼし対策用ポーリング周期。 |
| `ReloadDebounceSeconds` | ○ | ファイル書込み途中の読込みを避ける待機時間。 |
| `SqlClient.Encrypt` | ○ | SQL Client の暗号化設定。設定ファイル内のプロバイダー文字列からは決めない。 |
| `SqlClient.TrustServerCertificate` | ○ | 証明書検証を緩和する場合のみ明示的に `true`。 |

### 4.3 禁止事項

- `Provider` 未指定時にファイル拡張子から推測しない。
- `Labonity` で失敗したときに `LegacyLiberty` を試さない。
- `LegacyLiberty` で失敗したときに既定DB名へフォールバックしない。
- SQL パスワードを Sync Agent の JSON 設定へ複写しない。
- 解決結果を平文キャッシュファイルへ保存しない。

---

## 5. Labonity 設定解決

### 5.1 起点ファイル

`Provider = Labonity` の場合、`LocalSettingFilePath` は `LibLocal.xml` を指定する。

例:

```xml
<?xml version="1.0"?>
<BasicServerFolder xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                   xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <p_サーバーフォルダパス>\\server\LabonityDat</p_サーバーフォルダパス>
</BasicServerFolder>
```

### 5.2 解決手順

1. `LocalSettingFilePath` が絶対パスであることを検証する。
2. ファイルが存在し、Sync Agent サービスアカウントで読み取れることを確認する。
3. XML を安全設定で読み込む。
   - DTD を禁止する。
   - 外部エンティティを解決しない。
   - `XmlResolver = null` とする。
4. ルート要素が `BasicServerFolder` であることを確認する。
5. `p_サーバーフォルダパス` を1件だけ取得する。
6. 値をトリムし、末尾区切りを正規化する。
7. 相対パスは拒否する。
8. サーバーフォルダへ到達できることを確認する。
9. `Path.Combine(serverFolder, "LibertyDatabaseSetting.xml")` を設定ファイルパスとする。
10. `LibertyDatabaseSetting.xml` を読み込み、共通モデルへ変換する。

### 5.3 `LibertyDatabaseSetting.xml` の割当

| XML項目 | 共通モデル | 用途 |
|---|---|---|
| `p_SQLプロバイダー名` | `Sql.ProviderName` | 診断情報。直接接続には使用しない。 |
| `p_SQLサーバー名` | `Sql.ServerName` | SQL Server インスタンス名。 |
| `p_SQLユーザーID` | `Sql.UserId` | SQL認証ユーザー。 |
| `p_SQLパスワード` | `Sql.Password` | メモリ内のみ保持。ログ・画面・DBへ保存しない。 |
| `p_マスターデータベース名` | `Databases.Master` | 通常 `MsDat`。現場マスター等。 |
| `p_出荷管理データベース名` | `Databases.ShippingData` | 通常 `NaDat`。予定・出荷・FieldTest。 |
| `p_品質管理データベース名` | `Databases.QualityData` | 通常 `ExDat`。TP採取結果等。 |
| `p_販売管理データベース名` | `Databases.SalesData` | 必要機能のみ。 |
| `p_動荷重データベース名` | `Databases.DynamicLoadData` | 必要機能のみ。 |
| `p_共通設定データベース名` | `Databases.CommonSettings` | 共通設定。 |

### 5.4 Labonity 固有検証

- `LibLocal.xml` と `LibertyDatabaseSetting.xml` の最終更新日時を記録する。
- DB設定XMLのルート、必要要素、重複要素を検証する。
- `Master`、`ShippingData`、`QualityData` は空欄不可とする。
- `ShippingData` 内に `YoteiDataMain`、`SyukkaDataMain` が存在することを確認する。
- `Master` 内に `Genba` が存在することを確認する。
- `QualityData` 内に必要な `TestPieceSaisyu_*` テーブルが存在することを確認する。

---

## 6. 旧 Liberty 設定解決

### 6.1 起点ファイル

`Provider = LegacyLiberty` の場合、`LocalSettingFilePath` は `LIBLocal.Ini` を指定する。

例:

```ini
[端末設定]
;サーバーパス=\\old-server\Dat2\
サーバーパス=D:\Dat2\
```

コメント行は無視する。上記では `D:\Dat2\` が有効値となる。

### 6.2 `LIBLocal.Ini` の解決手順

1. `LocalSettingFilePath` が絶対パスであることを検証する。
2. `LIBLocal.Ini` を文字コード規則に従って読み込む。
3. `[端末設定]` セクションを取得する。
4. `サーバーパス` の有効行を取得する。
5. 値の前後空白と引用符を除去する。
6. `/` を Windows の `\` として正規化する。
7. 末尾の `\` は内部表現では除去し、表示時に必要に応じて付加する。
8. 相対パスは拒否する。
9. サーバーパスへ到達できることを確認する。
10. `Path.Combine(serverPath, "LIBCTRL.ini")` をコントロール設定パスとする。
11. `LIBCTRL.ini` を読み、共通モデルへ変換する。

### 6.3 ローカルドライブと UNC

| サーバーパス | 解釈 |
|---|---|
| `D:\Dat2\` | Sync Agent が稼働しているコンピューターのローカル `D:`。別PCの `D:` ではない。 |
| `\\server\Dat2\` | UNC共有。Sync Agent サービスアカウントに共有権限とNTFS権限が必要。 |

`D:\Dat2\` が設定されている場合、Sync Agent は旧 Liberty のサーバーと同一コンピューターへ配置することを標準とする。別コンピューターへ配置する場合は、`LIBLocal.Ini` のサーバーパスを UNC に変更する。

### 6.4 `LIBCTRL.ini` の解決対象

#### 6.4.1 必須セクション

- `[コントロールマスター]`
- `[システム設定]`

#### 6.4.2 必須キー

| INIキー | 共通モデル | 備考 |
|---|---|---|
| `初期工場コード` | `Factory.InitialFactoryCode` | 先頭ゼロを保持する文字列。 |
| `ＳＱＬプロバイダー名` | `Sql.ProviderName` | 診断用。NFKC正規化後は `SQLプロバイダー名`。 |
| `ＳＱＬサーバー名` | `Sql.ServerName` | SQL Server インスタンス。 |
| `ＳＱＬユーザーＩＤ` | `Sql.UserId` | SQL認証ユーザー。 |
| `ＳＱＬパスワード` | `Sql.Password` | メモリ内のみ。絶対にログへ出さない。 |
| `共通マスタＤＢ名` | `Databases.Master` | 旧現場マスター `Genba` 等。 |
| `出荷データＤＢ名` | `Databases.ShippingData` | `Yotei1/2/3`、`Syukka1/2/3`、`SyukkaFresh*`。 |
| `工場コード使用` | `Factory.FactoryCodeEnabled` | `[システム設定]` から取得。 |

#### 6.4.3 任意キー

| INIキー | 共通モデル | 初期対応での扱い |
|---|---|---|
| `品管マスタＤＢ名` | `Databases.QualityMaster` | 将来利用。接続確認は設定で選択。 |
| `出荷マスタＤＢ名` | `Databases.ShippingMaster` | コード名称解決で必要な場合に利用。 |
| `販売マスタＤＢ名` | `Databases.SalesMaster` | 初期同期では未使用。 |
| `品管データＤＢ名` | `Databases.QualityData` | 旧品質データを連携する場合に利用。 |
| `品管データ2ＤＢ名` | `Databases.QualityData2` | 同上。 |
| `出荷ワークデータＤＢ名` | `Databases.ShippingWork` | 初期同期では未使用。 |
| `販売データＤＢ名` | `Databases.SalesData` | 初期同期では未使用。 |
| `販売ワークデータＤＢ名` | `Databases.SalesWork` | 初期同期では未使用。 |
| `受払マスタＤＢ名` | `Databases.InventoryMaster` | 初期同期では未使用。 |
| `受払データＤＢ名` | `Databases.InventoryData` | 初期同期では未使用。 |
| `試験場データＤＢ名` | `Databases.TestSiteData` | 必要時のみ。 |
| `動荷重データＤＢ名` | `Databases.DynamicLoadData` | 空欄可。 |
| `写真台帳データＤＢ名` | `Databases.PhotoLedger` | 旧写真台帳との連携を有効化した場合のみ。 |
| `汎用１〜４データＤＢ名` | `Databases.General1..4` | 空欄可。初期同期では未使用。 |

### 6.5 全角キーの正規化

旧 INI には `ＳＱＬ`、`ＩＤ`、`ＤＢ` など全角英数字が含まれる。

キー検索時だけ Unicode Normalization Form KC（NFKC）を適用する。

```text
ＳＱＬユーザーＩＤ
  ↓ NFKC
SQLユーザーID
```

値には NFKC を適用しない。パスワード、サーバー名、DB名、会社名などが変化することを防止する。

### 6.6 工場コードの解決

| `工場コード使用` | 行データの工場コード | 採用値 |
|---:|---|---|
| `0` | 空欄 | `初期工場コード` を採用。 |
| `0` | 非空欄 | 行データ値を採用し、初期工場コードとの差異を警告ログへ記録。 |
| `1` | 空欄 | エラーとして同期対象外。 |
| `1` | 非空欄 | 行データ値を採用。 |

採用した旧工場コードは、Sync Agent 設定の `PlantMappings` によってクラウドの `tenant_id` / `plant_id` へ明示対応させる。未登録工場を推測で割り当てない。

### 6.7 旧 Liberty DB の初期利用範囲

| 共通データ | DB | 代表テーブル |
|---|---|---|
| 現場 | `共通マスタＤＢ名` | `Genba` |
| 予定 | `出荷データＤＢ名` | `Yotei1/2/3` |
| 出荷 | `出荷データＤＢ名` | `Syukka1/2/3` |
| フレッシュ試験 | `出荷データＤＢ名` | `SyukkaFresh`（初期は読取または無効） |
| 旧写真 | `出荷データＤＢ名` | `SyukkaFreshPicture`（Base64互換は初期無効） |
| Sync Agent連携テーブル | `出荷データＤＢ名` | `FieldTest.*` |
| 旧テーブル共通化ビュー | `出荷データＤＢ名` | `FieldTestSource.*` |

---

## 7. INI 読取仕様

### 7.1 文字コード

次の優先順で判定する。

1. UTF-8 BOM
2. UTF-16 LE BOM
3. UTF-16 BE BOM
4. BOMなしの場合は Windows-31J / CP932

CP932 として不正なバイト列がある場合、置換文字で継続せず設定エラーとする。

### 7.2 構文

- 空行を無視する。
- 行頭の空白を除去後、先頭が `;` または `#` の行をコメントとする。
- セクションは `[セクション名]` とする。
- キーと値は最初の `=` で分割する。
- 値内の2個目以降の `=` は値の一部とする。
- キー前後の空白は除去する。
- 値前後の空白は除去する。
- 値全体が同じ引用符で囲まれている場合のみ、外側引用符を除去する。
- インラインコメントは解釈しない。パスワードや値に `;` が含まれる可能性があるためである。

### 7.3 重複キー

同一セクションに同じ正規化キーが複数回存在する場合は、最後の有効行を採用し、`configuration_warning` を記録する。

秘密値については行番号だけを記録し、値は記録しない。

### 7.4 セクション・キー比較

- セクション名: 前後空白除去後、NFKCして比較。
- キー名: 前後空白除去後、NFKCして比較。
- 値: 前後空白除去のみ。

---

## 8. 共通解決結果

```text
ResolvedLocalSystemSettings
  Provider
  EntrySettingFilePath
  EntrySettingLastWriteUtc
  ServerFolderPath
  SecondarySettingFilePath
  SecondarySettingLastWriteUtc

  Sql
    ProviderName
    ServerName
    AuthenticationMode
    UserId
    Password                  SecretString / SecureBuffer
    Encrypt
    TrustServerCertificate

  Databases
    Master
    ShippingMaster
    ShippingData
    ShippingWork
    QualityMaster
    QualityData
    QualityData2
    SalesMaster
    SalesData
    SalesWork
    InventoryMaster
    InventoryData
    TestSiteData
    DynamicLoadData
    PhotoLedger
    CommonSettings
    General1..4

  Factory
    InitialFactoryCode
    FactoryCodeEnabled

  Diagnostics
    SourceEncoding
    Warnings[]
    ConfigurationFingerprint
```

### 8.1 ConfigurationFingerprint

パスワードを除いた次の情報から SHA-256 を生成する。

- Provider
- サーバーフォルダ
- SQL Server名
- DB名一覧
- 初期工場コード
- 工場コード使用
- 起点・二次設定ファイルの最終更新日時

パスワード自体は fingerprint へ含めない。パスワード変更検知は、プロセス内の秘密値ハッシュを用い、ログやDBには保存しない。

---

## 9. SQL 接続文字列生成

### 9.1 方針

旧設定の `SQLOLEDB` は既存アプリの接続方式を表す診断値として保持する。

Sync Agent は .NET の `Microsoft.Data.SqlClient` を使用し、OLE DB Provider文字列をそのまま接続文字列へ使用しない。

### 9.2 SQL認証

ユーザーIDとパスワードの両方が設定されている場合、SQL認証を使用する。

```text
Server={Sql.ServerName};
Initial Catalog={DatabaseName};
User ID={Sql.UserId};
Password={secret};
Encrypt={config};
TrustServerCertificate={config};
Application Name=FieldTester.SyncAgent;
```

### 9.3 Windows認証

将来、ユーザーID・パスワードが空欄で、明示設定 `AuthenticationMode=Integrated` の場合のみ Windows認証を利用する。

空欄だから自動的にWindows認証へ切り替えることは禁止する。

### 9.4 接続プール

DBごとに接続文字列を生成するが、SQL Server・認証情報・暗号化設定は共通化する。秘密値を含む完全な接続文字列をログへ出さない。

---

## 10. 設定変更の自動再読込

### 10.1 監視対象

| Provider | 監視対象 |
|---|---|
| Labonity | `LibLocal.xml`、解決された `LibertyDatabaseSetting.xml` |
| LegacyLiberty | `LIBLocal.Ini`、解決された `LIBCTRL.ini` |

### 10.2 再読込フロー

```text
ファイル変更検知
  ↓ debounce
新設定を別オブジェクトへ読込
  ↓ 構文・必須項目検証
DB接続・必要テーブル検証
  ↓
現在の同期サイクル終了待ち
  ↓
設定をアトミックに切替
  ↓
新設定で heartbeat と同期再開
```

### 10.3 再読込失敗

- 現在の正常設定を維持する。
- 新設定へ部分的に切り替えない。
- Agent状態を `degraded` とする。
- エラーコード、対象ファイル、キー名、行番号を記録する。
- パスワード値は記録しない。
- 一定間隔で再検証する。

### 10.4 DB切替

SQL Server名または主要DB名が変わった場合、通常再読込より重大な変更として扱う。

- 新DBの全ヘルスチェックを行う。
- 同期 checkpoint の移行可否を検証する。
- `source_instance_id` が変わる場合は自動切替せず、管理者承認を要求する。
- 旧DBと新DBが同時に書込対象にならないよう、旧接続を閉じてから新接続へ切り替える。

---

## 11. 起動時ヘルスチェック

### 11.1 共通

1. Providerが許可値である。
2. 起点ファイルパスが絶対パスである。
3. 起点ファイルが存在し読取可能である。
4. サーバーフォルダが存在し到達可能である。
5. 二次設定ファイルが存在し読取可能である。
6. SQL Server名が取得できる。
7. 必須DB名が取得できる。
8. SQL接続に成功する。
9. 必要テーブル・ビュー・FieldTestスキーマが存在する。
10. 工場コードと `plant_id` のマッピングが成立する。
11. 同一 `tenant_id + plant_id` の別Agentがactiveでない。
12. クラウド用 Agent credential が有効である。

### 11.2 Labonity追加検証

- XML外部エンティティが無効である。
- `p_サーバーフォルダパス` が1件だけ存在する。
- `LibertyDatabaseSetting.xml` が期待形式である。

### 11.3 旧 Liberty追加検証

- INIがCP932またはBOM付きUnicodeとして正常に読める。
- `[端末設定] サーバーパス` が存在する。
- `LIBCTRL.ini` がサーバーパス直下に存在する。
- `[コントロールマスター]` と `[システム設定]` が存在する。
- 全角SQLキーを正規化して取得できる。
- `共通マスタＤＢ名`、`出荷データＤＢ名` が空欄でない。
- `工場コード使用` が `0` または `1` である。

---

## 12. 診断表示

管理画面または診断コマンドでは次を表示する。

| 項目 | 表示内容 |
|---|---|
| Provider | `Labonity` / `LegacyLiberty` |
| 起点設定 | パス、存在、文字コード、最終読込日時 |
| サーバーフォルダ | 解決値、ローカル/UNC、到達可否 |
| 二次設定 | ファイル名、存在、文字コード、最終読込日時 |
| SQL | サーバー名、認証方式、Provider名。パスワード非表示 |
| DB | 利用するDB名と接続結果 |
| 工場 | 初期工場コード、工場コード使用、PlantMapping結果 |
| 設定状態 | valid / degraded / error |
| 設定fingerprint | 先頭12文字のみ |
| Agent version | 現在版、利用可能版、自動更新状態 |

---

## 13. ログ・セキュリティ

### 13.1 秘密情報

次は絶対にログ、例外メッセージ、画面、DB、テレメトリへ出さない。

- `ＳＱＬパスワード`
- `p_SQLパスワード`
- 完全なSQL接続文字列
- Agent credential
- 更新パッケージ署名用秘密鍵

### 13.2 権限

- `LIBLocal.Ini`、`LIBCTRL.ini`、`LibLocal.xml`、`LibertyDatabaseSetting.xml` は Sync Agent サービスアカウントが読取可能であること。
- 一般利用者による変更権限は最小化する。
- Sync Agent は設定ファイルを書き換えない。
- SQLは可能な限り専用の最小権限ユーザーへ変更する。
- `sa` の常用を推奨しない。

### 13.3 パスワード取扱い

既存 INI/XML に平文パスワードがある場合、互換のため読取は行うが、次を必須とする。

- メモリ内だけで使用する。
- ダンプや診断バンドルへ含めない。
- 文字列の寿命を最小化する。
- 将来は Windows Credential Manager / DPAPI / Secret Store への移行を可能にする。

---

## 14. 自動アップデート

### 14.1 構成

Sync Agent本体が自分自身を上書きせず、独立した `FieldTester.SyncAgent.Updater` が更新を担当する。

### 14.2 更新フロー

1. 定期的に署名済み `manifest.json` を取得する。
2. 対象チャンネル、現在版、最低対応設定版を比較する。
3. 更新パッケージを一時フォルダへ取得する。
4. SHA-256とコード署名を検証する。
5. 現在のバイナリとサービス定義をバックアップする。
6. Sync Agentへdrain要求を出し、同期中ジョブを完了させる。
7. Windows Serviceを停止する。
8. バイナリだけを更新する。
9. 次の設定ファイルは上書きしない。
   - `appsettings.Production.json`
   - `LocalSettingFilePath` を含む環境別設定
   - Agent credential
   - `LIBLocal.Ini` / `LIBCTRL.ini`
   - `LibLocal.xml` / `LibertyDatabaseSetting.xml`
10. Serviceを起動する。
11. 起点設定解決、DB接続、クラウド接続のヘルスチェックを行う。
12. 失敗した場合は旧バイナリへ自動ロールバックする。

### 14.3 設定互換性

更新マニフェストは `minimumConfigurationSchemaVersion` を持つ。

Agent更新後に設定移行が必要な場合でも、基幹設定ファイルは変更せず、Sync Agent独自設定だけをバックアップ付きで移行する。

### 14.4 クラウド業務API

自動更新は配布用 Blob または更新専用APIを使用する。予定・出荷・現場・写真・OCRの既存業務同期APIは変更しない。

---

## 15. クラウドとの互換性

設定解決はローカル側で完結する。

```text
Labonity / LegacyLiberty 設定
  ↓
ResolvedLocalSystemSettings
  ↓
共通DTO
  FieldSite
  ShippingSchedule
  Shipment
  PhotoReference
  OcrResult
  ↓
既存CloudSyncClient
```

クラウドへ送るIDは、Labonityでは既存GUID、旧Libertyでは決定的GUIDを利用する。APIの型・エンドポイント・認証方式は共通のままとする。

---

## 16. エラーコード

| コード | 内容 |
|---|---|
| `CFG-COM-001` | Provider未指定または不正。 |
| `CFG-COM-002` | 起点ファイルパスが相対パス。 |
| `CFG-COM-003` | 起点ファイル参照不可。 |
| `CFG-LAB-001` | `LibLocal.xml` のXML構文不正。 |
| `CFG-LAB-002` | `p_サーバーフォルダパス` 不足または重複。 |
| `CFG-LAB-003` | `LibertyDatabaseSetting.xml` 不在。 |
| `CFG-LAB-004` | Labonity必須DB項目不足。 |
| `CFG-LIB-001` | `LIBLocal.Ini` の文字コードまたは構文不正。 |
| `CFG-LIB-002` | `[端末設定] サーバーパス` 不足。 |
| `CFG-LIB-003` | `LIBCTRL.ini` 不在。 |
| `CFG-LIB-004` | `[コントロールマスター]` 不足。 |
| `CFG-LIB-005` | SQL Serverまたは認証項目不足。 |
| `CFG-LIB-006` | `共通マスタＤＢ名` または `出荷データＤＢ名` 不足。 |
| `CFG-LIB-007` | 工場コード設定不正。 |
| `CFG-DB-001` | SQL Server接続失敗。 |
| `CFG-DB-002` | DB不存在。 |
| `CFG-DB-003` | 必要テーブルまたは権限不足。 |
| `UPD-001` | 更新マニフェスト署名不正。 |
| `UPD-002` | 更新パッケージハッシュ不一致。 |
| `UPD-003` | 更新後ヘルスチェック失敗、ロールバック実施。 |

---

## 17. 受入条件

### 17.1 Labonity

1. `LibLocal.xml` の `p_サーバーフォルダパス` からサーバーフォルダを取得できる。
2. サーバーフォルダ直下の `LibertyDatabaseSetting.xml` を取得できる。
3. MsDat、NaDat、ExDat等を設定値から接続できる。
4. XMLのDTD・外部エンティティを処理しない。
5. DB設定不備時に旧Libertyへフォールバックしない。

### 17.2 旧 Liberty

1. `LIBLocal.Ini` のコメント行を無視して有効な `サーバーパス` を取得できる。
2. `D:\Dat2\` と UNC の双方を正しく処理できる。
3. サーバーパス直下の `LIBCTRL.ini` を取得できる。
4. CP932の日本語セクション・キーを正しく読める。
5. 全角 `ＳＱＬ`、`ＩＤ`、`ＤＢ` をキー検索時に正規化できる。
6. SQL Server名、ユーザーID、パスワード、LMASTER、LSYUDATを取得できる。
7. パスワードをログ・画面へ出さない。
8. `工場コード使用=0` の空欄行へ初期工場コードを適用できる。
9. 未登録工場を別工場へ推測割当しない。
10. 設定不足時に既定の `LMASTER` / `LSYUDAT` へフォールバックしない。

### 17.3 共通

1. Providerを変更しない限り、別形式の設定ファイルを読まない。
2. 設定変更は検証後にアトミックに切り替わる。
3. 新設定不正時は旧設定で継続し、状態を `degraded` とする。
4. 設定解決後の共通DTOとクラウドAPI契約はProvider間で同一である。
5. Agent自動更新後も `LocalSettingFilePath` と基幹設定ファイルを保持する。
6. 更新後ヘルスチェック失敗時に前バージョンへ戻る。

---

## 18. 導入手順

1. Sync Agentをインストールする。
2. Providerを選択する。
3. `LocalSettingFilePath` に、Labonityなら `LibLocal.xml`、旧Libertyなら `LIBLocal.Ini` を指定する。
4. サービスアカウントへ起点ファイル、サーバーフォルダ、二次設定ファイルの読取権限を付与する。
5. `PlantMappings` を設定する。
6. 設定診断コマンドを実行する。
7. SQL接続・必要テーブル・FieldTestスキーマを確認する。
8. クラウド Agent credential を登録する。
9. テスト同期を実行する。
10. 自動更新チャンネルとメンテナンス時間帯を設定する。
11. 更新・ロールバック試験を行う。

---

## 19. 実装上の注意

- `LIBLocal.Ini` のファイル名大小文字は Windows では区別しないが、診断表示では実際のファイル名を表示する。
- `LIBCTRL.ini` はサーバーパス直下のみを検索し、サブフォルダを再帰検索しない。
- 旧設定に書かれた `SQLOLEDB` は許容するが、Sync Agentは `Microsoft.Data.SqlClient` で接続する。
- `初期工場コード` は数値変換せず文字列として保持し、先頭ゼロを失わない。
- DB名はSQL識別子として安全に引用し、クエリ文字列へ直接連結しない。
- 設定ファイルを読み取るだけで、既存 Labonity / Liberty の設定内容を更新しない。
- 平文のSQL管理者パスワードが使用されている環境では、導入時に同期専用の最小権限ユーザーへ変更することを強く推奨する。
