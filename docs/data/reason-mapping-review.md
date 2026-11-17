# 原因映射版本复核

> 状态：已解决，采用 v2.0
> 复核日期：2026-11-17

## 发现

当前冻结文件 `data/reference/mappings/reason_dictionary_v1.csv` 只有 7 个标签。
基础 EDA 生成的候选文件
`data/interim/mappings/reason_dictionary_candidate.csv` 包含当前数据中的全部
112 个唯一标签。

v1 的单一族结构混合了问题领域、证据强度、调查状态和覆盖残差。v1 文件保留为历史版本，
不再作为当前分析输入。

## 差异概览

| 原因族 | 当前冻结标签数 | 候选标签数 | 候选新增 |
|---|---:|---:|---:|
| 出版流程操纵 | 1 | 6 | 5 |
| 图像完整性 | 0 | 3 | 3 |
| 剽窃/署名 | 2 | 9 | 7 |
| 数据完整性 | 0 | 5 | 5 |
| 错误/信息不足 | 1 | 12 | 11 |
| 未归类 | 3 | 77 | 74 |
| 合计 | 7 | 112 | 105 |

## 已采用的修正

- 112 个标签全部进入人工复核注册表 `reason_label_registry_v2.csv`。
- 标签到问题领域改为多对多长表 `reason_domain_map_v2.csv`。
- 调查、法律、沟通和行政状态进入独立上下文表 `reason_context_map_v2.csv`。
- 分析族使用 `analysis_family_domains_v2.csv`，不再由单一族字段直接定义。
- `error_control` 改为论文层派生参照。
- `unclassified` 改为覆盖说明，不再是原因族。
- 主分析采用实质发现窄定义；疑虑和错误标签只进入宽定义敏感性分析。

完整决策见 [原因映射 v2 ADR](../decisions/0003-reason-taxonomy-v2.md)。
