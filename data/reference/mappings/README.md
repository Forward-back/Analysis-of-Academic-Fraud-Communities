# 冻结映射

本目录保存人工确认后冻结的项目映射。

| 文件 | 作用 | 当前版本 |
|---|---|---|
| `reason_label_registry_v2.csv` | 112 个原因标签的证据状态和复核理由 | `2.0-frozen` |
| `reason_domain_map_v2.csv` | 原因标签到问题领域的多标签映射 | `2.0-frozen` |
| `reason_context_map_v2.csv` | 调查、法律和行政背景标签 | `2.0-frozen` |
| `analysis_family_domains_v2.csv` | 问题领域到分析族的预设映射 | `2.0-frozen` |
| `reason_dictionary_v1.csv` | 旧版单族映射，仅保留历史 | `1.0-frozen` |
| `rwdb_field_dictionary_v1.csv` | Retraction Watch 字段说明 | `1.0-frozen` |
| `provenance.json` | 来源、冻结日期和文件哈希 | `2.0` |

`R/90_baseline_eda.R` 读取 v2 注册表和映射表，不再生成或覆盖单一族字典。
分类原则见 [原因映射 v2 ADR](../../../docs/decisions/0003-reason-taxonomy-v2.md)。
