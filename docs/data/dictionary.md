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

## 原因族代码

| 代码 | 中文名 | 分析角色 |
|---|---|---|
| `publication_process` | 出版流程操纵 | 主推断 |
| `image_integrity` | 图像完整性 | 主推断 |
| `plagiarism_authorship` | 剽窃/署名 | 主推断 |
| `data_integrity` | 数据完整性 | 探索 |
| `error_control` | 错误/信息不足 | 参照 |
| `unclassified` | 未归类 | 覆盖说明 |

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
