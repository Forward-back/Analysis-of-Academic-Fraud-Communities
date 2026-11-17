# 数据目录

本目录按数据生命周期与来源边界分层。原始数据只读，缓存与派生数据可重建。

| 路径 | 生态位 | 格式 |
|---|---|---|
| `raw/` | 冻结原始数据 | CSV |
| `cache/` | OpenAlex、Crossref 原始响应和请求日志 | JSON |
| `external/` | 第三方机构层级、行政区、别名与来源快照 | CSV、JSON、HTML |
| `reference/` | 项目自建并人工冻结的字段、原因与机构映射 | CSV、JSON |
| `interim/` | 清洗中间表 | RDS |
| `processed/` | 分析面板、作者长表、匹配组与网络 | RDS |
| `outputs/` | 按阶段输出的审计、表、图、模型摘要和应用数据 | CSV、JSON、PNG |

`external/` 与 `reference/` 的边界不可混用。自动分析只能写入 `interim/` 下的候选映射，
不得覆盖 `reference/` 中已冻结的文件。

## 当前数据

- 原始数据：`raw/retractions.csv`
- 字段字典：`reference/mappings/rwdb_field_dictionary_v1.csv`
- 原因映射：`reference/mappings/reason_dictionary_v1.csv`
- OpenAlex 压测缓存：`cache/openalex/pressure-tests/`
- 基线 EDA：`outputs/baseline/`

当前仅具备 Retraction Watch 基础 EDA 和 OpenAlex 压测结果，尚未生成全量 OpenAlex
作者、机构、匹配与非撤稿对照数据。

## 发布边界

原始 Retraction Watch CSV、API 缓存、清洗中间表和大型 RDS 不提交到 Git。
小型审计、基线表、最终聚合表、图、模型摘要和应用小表可以提交。
所有 manifest 使用项目相对路径，不记录用户名、临时目录或 API key。

原始 Retraction Watch 文件的许可条款仍需确认，不直接重新发布 CSV。
公开版本优先发布脚本、聚合结果、变量字典和派生指标。

完整契约见 [仓库文件与制品契约](../docs/decisions/0002-repository-file-contract.md)。
