# 0003：原因映射 v2.0

- 状态：已接受
- 日期：2026-11-17
- 决策范围：Retraction Watch 原因标签、证据状态、处理背景和分析族
- 替代：原因映射 v1 的单一 `reason_family` 结构

## 背景

v1 将每个原因标签直接映射到一个原因族，并把 `error_control` 与 `unclassified`
当作其他原因族平级。实际复核发现：

- 原因标签混合了问题领域、证据强度、调查状态和行政状态。
- `error_control` 包含错误、不可靠、信息不足和日期缺失。
- `unclassified` 包含大量调查主体和行政状态，并不是原因未知。
- “剽窃/署名”混合了文本复用核查与作者身份核查。
- 一个标签可能需要多个核查领域，例如 `Plagiarism of Image`。

因此 v2 不再使用单一平面分类，而采用三个正交字段和多标签映射。

## 标签注册表

`data/reference/mappings/reason_label_registry_v2.csv` 为每个原始 `Reason`
标签保存一行：

| 字段 | 含义 |
|---|---|
| `reason_label` | Retraction Watch 原始标签 |
| `evidence_status` | 标签表达的是实质发现、疑虑、错误或信息不足 |
| `mapping_status` | `reviewed` 或 `unmapped` |
| `rationale` | 简短分类理由 |
| `mapping_version` | 固定为 `2.0-frozen` |

`evidence_status` 取值：

- `substantive_finding`：标签直接陈述操纵、伪造、重复、剽窃、流程受损等实质发现。
- `concern_allegation`：标签表达问题或疑虑，但未直接陈述实质核查结果。
- `error_unreliable`：标签描述错误、不可靠或不可重复。
- `insufficient_information`：通知、材料或元数据不足。
- `not_applicable`：标签主要是调查、法律、行政或沟通背景。

## 问题领域

`reason_domain_map_v2.csv` 用长表记录标签到问题领域的多对多关系。允许值为：

- `publication_peer_review`
- `image_integrity`
- `data_results_integrity`
- `textual_reuse`
- `authorship_affiliation`
- `research_ethics_compliance`
- `materials_methods_integrity`
- `unspecified_integrity`

问题领域表示“需要哪类核查能力”，不表示作者责任或不端概率。

## 处理背景

`reason_context_map_v2.csv` 记录不构成原因领域的背景信息：

- `investigation`
- `legal`
- `administrative_status`
- `communication`
- `third_party`
- `external_complaint`
- `objection`
- `data_availability`
- `institutional_authorization`
- `metadata_limitation`
- `unclear`

调查主体、法律程序、撤稿状态更新不得被解释为具体撤稿原因。

## 分析族

`analysis_family_domains_v2.csv` 定义从问题领域到分析族的预设映射：

| 分析族 | 问题领域 | 角色 |
|---|---|---|
| `publication_process` | `publication_peer_review` | 主推断 |
| `image_integrity` | `image_integrity` | 主推断 |
| `plagiarism_authorship` | `textual_reuse` + `authorship_affiliation` | 主推断复合族 |
| `data_integrity` | `data_results_integrity` | 探索 |
| `research_ethics_compliance` | `research_ethics_compliance` | 探索 |
| `materials_methods_integrity` | `materials_methods_integrity` | 探索 |

主推断和数据分析族默认使用 `substantive_finding` 标签，称为窄定义。
将同一领域的疑虑和错误标签加入后称为宽定义，只用于预指定敏感性分析。
研究伦理和材料方法族默认使用任一相关标签，并另报仅实质发现子集。

`plagiarism_authorship` 保留为主推断复合族，以维持 H1-H3 的解释连续性。
`textual_reuse` 和 `authorship_affiliation` 分别作为预指定次级分析。

## 派生状态

- `error_control` 不再由标签直接映射。论文只有在没有任何窄定义实质族，
  且至少有一个 `error_unreliable` 或 `insufficient_information` 标签时，
  才进入严格参照组。
- `unclassified` 只表示论文没有进入分析族或严格参照组，不是原因族。
- `mapping_status = unmapped` 是覆盖审计字段，不进入模型。
- `context_only` 表示论文只有调查、法律或行政背景标签。

## 数据文件

```text
data/reference/mappings/
├─ reason_label_registry_v2.csv
├─ reason_domain_map_v2.csv
├─ reason_context_map_v2.csv
└─ analysis_family_domains_v2.csv
```

### 已知取舍

- 多领域标签会让分析族重叠增加，不能把族计数相加得到总论文数。
- 宽定义会显著扩大数据、图像和文本相关族，不能替代窄定义主结果。
- `Computer-Aided Content` 暂归出版流程领域；若后续证据显示其主要涉及图像或数据，
  通过新版本调整并做敏感性分析。
- `Concerns/Issues about Referencing/Attributions` 归入宽定义文本复用领域，
  不直接视为确认剽窃。
