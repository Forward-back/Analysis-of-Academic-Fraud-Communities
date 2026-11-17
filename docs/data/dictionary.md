# 数据字典

> 状态：核心分析口径已冻结，派生字段随实现补充

## 三层计数

| 层级 | 唯一键 | 当前数量 |
|---|---|---:|
| 更新通知 | `Record ID` | 73,597 |
| Retraction 通知 | `Record ID` | 68,155 |
| 核心窗口 Retraction 记录 | `Record ID` | 52,638 |
| 中国大陆候选唯一 DOI | 规范化 DOI | 26,526 |

## 核心论文变量

| 变量 | 类型 | 定义 |
|---|---|---|
| `doi_canonical` | character | 规范化原论文 DOI |
| `rwdb_record_ids` | list | 对应通知记录 |
| `retraction_year_first` | integer | 合并后最早撤稿年份 |
| `reason_labels` | list | 原始多标签原因 |
| `family_*` | logical | 原因族标志 |
| `openalex_work_id` | character | OpenAlex 作品 ID |
| `match_status` | character | exact、not_found、invalid、failed |
| `confirmed_mainland` | logical | OpenAlex 至少一个 `CN` 机构 |
| `institution_complete` | logical | 全部作者均有机构 ID |
| `n_authors` | integer | 去重 OpenAlex 作者 ID |
| `n_institutions` | integer | 去重机构 ID |
| `n_countries` | integer | 去重国家代码 |
| `cross_tier` | logical | 同时存在国家重点与非国家重点机构 |
| `geo_level` | factor | single_city、same_province_multi_city、domestic_cross_province、international |
| `median_geo_distance_km` | numeric | 机构间中位球面距离 |
| `max_geo_distance_km` | numeric | 最大机构距离 |

## 原因映射 v2

原因标签不再直接映射到单一 `reason_family`，而使用三个正交字段：

| 字段 | 定义 |
|---|---|
| `evidence_status` | 实质发现、疑虑、错误/不可靠、信息不足或非适用背景 |
| `issue_domains` | 一个或多个待核查问题领域，可多值 |
| `context_tags` | 调查、法律、行政、沟通等非原因背景 |

完整定义见 [原因映射 v2 ADR](../decisions/0003-reason-taxonomy-v2.md)。

### 问题领域

| 代码 | 中文名 | 核查能力 |
|---|---|---|
| `publication_peer_review` | 出版与同行评审 | 编辑流程、同行评审和论文工厂 |
| `image_integrity` | 图像完整性 | 图像取证与重复检测 |
| `data_results_integrity` | 数据与结果完整性 | 数据、分析、结果和重复性核查 |
| `textual_reuse` | 文本复用与归属 | 文本相似度、引用和归属核查 |
| `authorship_affiliation` | 作者身份与单位归属 | 作者身份、署名和单位核验 |
| `research_ethics_compliance` | 研究伦理与合规 | IRB/IACUC、知情同意、动物/人体福利和利益冲突 |
| `materials_methods_integrity` | 材料与方法完整性 | 材料、细胞系、方法和实验条件 |
| `unspecified_integrity` | 未具体化诚信问题 | 无法归入单一核查领域的总体不端或投诉 |

### 分析族

| 代码 | 组成领域 | 分析角色 |
|---|---|---|
| `publication_process` | `publication_peer_review` | 主推断 |
| `image_integrity` | `image_integrity` | 主推断 |
| `plagiarism_authorship` | `textual_reuse` + `authorship_affiliation` | 主推断复合族 |
| `data_integrity` | `data_results_integrity` | 探索 |
| `research_ethics_compliance` | `research_ethics_compliance` | 探索 |
| `materials_methods_integrity` | `materials_methods_integrity` | 探索 |
| `error_control` | 无窄定义实质族且有错误/信息不足标签 | 派生参照 |
| `unclassified` | 未进入上述分析族或参照组 | 覆盖说明 |

主族默认使用 `substantive_finding` 标签。宽定义敏感性分析加入疑虑和错误标签。
`plagiarism_authorship` 是主推断复合族，文本复用和署名分别作为次级分析。

## 网络变量

| 变量 | 定义 |
|---|---|
| `author_id` | OpenAlex 作者节点 |
| `paper_id` | 规范化 DOI |
| `edge_weight` | 共同撤稿论文数 |
| `repeat_edge` | 作者对至少共同出现于两篇撤稿论文 |
| `cross_tier_edge` | 国家重点与非国家重点机构作者连接 |
| `cross_province_edge` | 不同省份机构作者连接 |
| `international_edge` | 不同国家机构作者连接 |

## 文件格式

- 内部大型对象：RDS。
- 审计、表格与对外数据：CSV。
- manifest、缓存元数据和日志：JSON。
- 图表：PNG。

详细原始字段见 `data/reference/mappings/rwdb_field_dictionary_v1.csv`。
该字段字典属于项目参考数据；第三方来源快照位于 `data/external/snapshots/`。
