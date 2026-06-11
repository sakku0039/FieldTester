# Labonity 仕様調査レポート - 縦割り対応確認

| 項目 | 内容 |
|---|---|
| 対象 | TP採取結果入力 / 出荷実績 / 出荷予定 / 現場マスター / 現場試験アプリ連携 |
| 調査目的 | 出荷実績に紐づく写真を、Labonity の TP採取結果入力から OCR 取込する設計が縦割りに対応できるか確認する。 |
| 結論 | 対応可能。クラウドは TP ID を持たず、出荷実績写真を `Shipment` に紐づける。Labonity 側で `syukka_id + renban + datakubun` を画面コンテキストとして扱えば、通常取り・縦割り・データ No.2 のいずれにも対応できる。 |

---

## 1. 結論

現行設計は、縦割りにも対応できる。

ただし、実装時の重要条件は次の 3 点である。

1. 写真はクラウド上で出荷実績 `Shipment.shipment_id` に紐づける。
2. Labonity 側では、対象行の `syukka_id` を使って写真を取得する。
3. OCR 反映先は、Labonity 画面上の `renban + datakubun` で決定する。

クラウドに TP ID を持たせる必要はない。TP は Labonity 側で作成・保存される業務データであり、クラウドは出荷実績・写真・OCR 実行だけを扱えばよい。

---

## 2. Labonity 仕様整理

### 2.1 出荷予定

`YoteiDataMain` は予定データのメインテーブルであり、主キーは `yotei_id` である。主要項目は次の通り。

| 項目 | カラム | 用途 |
|---|---|---|
| 予定ID | `yotei_id` | 出荷予定の主キー |
| 出荷予定日 | `syukka_yoteibi` | 日付検索 |
| 予定 No | `yotei_no` | 予定番号 |
| 予定時刻 | `yotei_zikoku` | 一覧表示 |
| 現場ID | `genba_id` | 現場との紐づけ |
| 工場ID | `kozyo_id` | 工場単位の一意性 |

予定 No は単独で一意ではなく、`syukka_yoteibi + yotei_no + kozyo_id` を一意キーとして扱う必要がある。

### 2.2 出荷実績

`SyukkaDataMain` は出荷実績のメインテーブルであり、主キーは `syukka_id` である。主要項目は次の通り。

| 項目 | カラム | 用途 |
|---|---|---|
| 出荷ID | `syukka_id` | 出荷実績の主キー |
| 出荷予定日 | `syukka_yoteibi` | 予定日との関係 |
| 予定ID | `yotei_id` | 予定データとの紐づけ |
| SEQ No | `seq_no` | 同一予定内の出荷順 |
| 出荷年月日 | `syukka_nengappi` | 実出荷日 |
| 出荷時刻 | `syukka_zikoku` | 実出荷時刻 |
| 車番 | `syaban` | OCR 照合候補 |
| 出荷量 | `syukkaryo` | 表示・確認 |
| 製造量 | `seizoryo` | 表示・確認 |
| 工場ID | `kozyo_id` | 工場スコープ |

写真はこの出荷実績に紐づけるのが最も自然である。

### 2.3 現場マスター

現場住所は `Genba`、出荷用現場名や緯度経度は `Genba_Syukka` を参照する。

| テーブル | 主要項目 | 用途 |
|---|---|---|
| `Genba` | `id`, `genba_mei1`, `genba_mei2`, `ryakusyo`, `zyusyo1`, `zyusyo2` | 現場名、略称、住所 |
| `Genba_Syukka` | `genba_id`, `syukka_genba_mei1`, `syukka_genba_mei2`, `ido`, `keido`, `gps_genba_mei` | 出荷用現場名、緯度経度 |

Google Maps 連携は、緯度経度があれば `Genba_Syukka.ido/keido` を優先し、なければ `Genba.zyusyo1/zyusyo2` を使う。

### 2.4 TP採取結果入力メイン

`TestPieceSaisyu_Main` は TP 採取結果入力のメインテーブルであり、主キーは `id` である。主要項目は次の通り。

| 項目 | カラム | 用途 |
|---|---|---|
| ID | `id` | TP 採取結果の主キー |
| 採取年月日 | `saisyunengappi` | 採取日 |
| 現場ID | `genba_id` | 現場 |
| 配合ID | `haigo_id` | 配合 |
| 試験区分 | `sikenkubun` | 製品・工程・代行など |
| 供試体区分 | `kyositaikubun` | 供試体パターン |
| 縦割り | `tatewari` | 通常取り / 縦割り制御 |

クラウドにこの TP ID を持たせる必要はない。

### 2.5 TP採取結果入力 - 出荷データ

`TestPieceSaisyu_SyukkaData` は、TP 採取結果と出荷実績を紐づけるテーブルである。

| 項目 | カラム |
|---|---|
| TP採取結果入力ID | `testpiecesaisyu_main_id` |
| 連番 | `renban` |
| 出荷ID | `syukka_id` |

通常取りでは `renban = 0` の出荷が対象となる。縦割りでは `renban = 0, 1, 2` にそれぞれ別の `syukka_id` が入る。

### 2.6 TP採取結果入力 - フレッシュ試験

`TestPieceSaisyu_FreshSiken` は、フレッシュ試験値を保持するテーブルである。キーは次の 3 要素で決まる。

```text
testpiecesaisyu_main_id + renban + datakubun
```

`renban` は通常取りでは 0、縦割りでは 0〜2 を使う。`datakubun` は `0=データ1 メインデータ`, `1=データ2 裏データ` である。

OCR 反映対象となる主な項目は次の通り。

| 項目 | カラム | 型の注意 |
|---|---|---|
| 車番 | `syaban` | `nchar(6)` |
| 外気温 | `gaikion` | `nchar(6)` |
| 試験時間 | `sikenzikan` | `nchar(6)` |
| スランプ | `slump` | `money` |
| フロー1 | `flow1` | `money` |
| フロー2 | `flow2` | `money` |
| 空気量 | `air` | `money` |
| コンクリート温度 | `concrete_ondo` | `money` |
| 単位容積質量 | `taniyosekisituryo` | `money` |
| 塩化物量1 | `enkabuturyo1` | `money` |
| 塩化物量2 | `enkabuturyo2` | `money` |
| 塩化物量3 | `enkabuturyo3` | `money` |
| 単位水量 | `tanisuiryo` | `money` |
| 備考 | `biko` | `nvarchar(10)` |
| 材料分離目視確認 | `zairyobunrimokusikakunin` | `0=空白, 1=有, 2=無` |

---

## 3. 縦割り対応の判断

### 3.1 Labonity の縦割り構造

縦割りでは、出荷実績を最大 3 件まで選択し、各出荷を `renban = 0, 1, 2` に割り当てる。

```text
renban 0 -> 1 台目の syukka_id -> 1 台目の写真候補 -> FreshSiken renban 0
renban 1 -> 2 台目の syukka_id -> 2 台目の写真候補 -> FreshSiken renban 1
renban 2 -> 3 台目の syukka_id -> 3 台目の写真候補 -> FreshSiken renban 2
```

このため、写真選択 OCR は「TP全体」ではなく、「現在の出荷行 / 現在の `renban`」を起点にする必要がある。

### 3.2 対応できる理由

今回の設計では、写真は出荷実績に紐づく。縦割り時も、各 `renban` は `TestPieceSaisyu_SyukkaData` で特定の `syukka_id` と結びつく。

つまり、Labonity 側で次の流れにすればよい。

1. ユーザーが縦割り行を選ぶ。
2. その行の `renban` を取得する。
3. `renban` から対応する `syukka_id` を取得する。
4. `FieldPhotoReference.target_local_id = syukka_id` で写真を検索する。
5. OCR 結果を `TestPieceSaisyu_FreshSiken.renban = 対象 renban` かつ `datakubun = 現在のデータ区分` の入力欄へ流し込む。

この構造なら、クラウド側に TP ID は不要である。

### 3.3 注意点

実装時に混線しやすい点は次である。

| 注意点 | 対応 |
|---|---|
| 縦割り時に全出荷写真を混ぜて表示してしまう | 現在行の `renban` から対象 `syukka_id` を引いて写真検索する。 |
| データ No.2 表示中にデータ1へ反映してしまう | `datakubun` を画面状態から取得し、`0/1` を明示する。 |
| 新規未保存 TP で TP ID がない | 画面上の `syukka_id + renban + datakubun` だけで OCR 可能にする。 |
| 出荷実績未同期 | 現場アプリ側で仮紐づけし、出荷同期後に `Shipment` へ解決する。 |
| `syukka_id` と `shipment_id` の混同 | クラウド ID とローカル ID を分離し、Labonity は `target_local_id = syukka_id` を使う。 |

---

## 4. 設計への反映内容

設計書 v1.0 では、縦割り対応として次を反映した。

- TP ID はクラウドへ持たせない。
- OCR API の `tpSamplingId` 必須を廃止する。
- OCR リクエストは `shipmentId`, `shipmentSourceLocalId`, `photoAssetIds`, `targetContext` を送る。
- `targetContext` に `renban`, `datakubun`, `clientContextId` を含める。
- クラウドは `renban` / `datakubun` を永続的な外部キーにしない。
- Labonity 画面側で `renban + datakubun` の入力欄へ反映する。
- 縦割りでは、現在行の `renban` に対応する `syukka_id` の写真だけを候補表示する。
- データ No.2 では `datakubun = 1` へ反映する。
- 既存 TP テーブルは変更しない。

---

## 5. 参照した資料・コード

- `予定.pdf`: `YoteiDataMain`、予定ID、出荷予定日、予定No、現場ID、工場ID、一意制約。
- `出荷.pdf`: `SyukkaDataMain`、出荷ID、予定ID、SEQ No、出荷時刻、車番、出荷量、工場ID。
- `現場マスター.pdf`: `Genba`、`Genba_Syukka`、住所、出荷用現場名、緯度、経度。
- `tp.pdf`: `TestPieceSaisyu_Main`、`TestPieceSaisyu_FreshSiken`、`TestPieceSaisyu_SyukkaData`、`renban`、`datakubun`、縦割り仕様。
- `LabonityDev-master`: `Examiner/Ex3010` 配下の TP 採取結果入力ソース。特に `SyukkaDataSelectForm.cs`, `DetailForm.cs`, `DetailFormMethods.cs`, `TestPieceSaisyuDto.cs`, `TestPieceSaisyuFreshSikenDto.cs`, `TestPieceSaisyuSyukkaDataDto.cs`。
