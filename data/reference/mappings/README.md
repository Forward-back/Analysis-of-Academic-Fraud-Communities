# 冻结映射

本目录保存人工确认后冻结的项目映射。

| 文件 | 作用 | 当前版本 |
|---|---|---|
| `reason_dictionary_v1.csv` | Retraction Watch 原始原因标签到项目原因族 | `1.0-frozen` |
| `rwdb_field_dictionary_v1.csv` | Retraction Watch 字段说明 | `1.0-frozen` |
| `provenance.json` | 来源、冻结日期和文件哈希 | `1.0` |

`R/90_baseline_eda.R` 只生成
`data/interim/mappings/reason_dictionary_candidate.csv`，不会覆盖本目录中的冻结文件。
