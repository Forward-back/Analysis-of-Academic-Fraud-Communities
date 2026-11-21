# 2023 外部治理证据

> 状态：P3 已完成
> 完成日期：2026-11-21
> 来源：10 个来源；13 条事实；6 个一级来源；4 个二级来源

## 证据口径

每条外部事实独立登记：

- 来源组织和来源类型。
- 发布日期与访问日期。
- 原始 URL 和可用归档 URL。
- 英文原文摘录。
- 与本地 2023 事件的对应位置。
- 解释边界和核验说明。

引用只保留支持事实所需的最短片段。未使用 AI 生成引用，未把新闻摘要当作出版社公告。

## 外部时间线

| 日期 | 事件 |
|---|---|
| 2023-03-20 | Clarivate 表示超过 50 个被标记期刊未通过质量标准并已去索引 |
| 2023-04-04 | Wiley 说明 19 个 Hindawi 期刊在本轮去索引中；此前已撤回 511 篇，并正在追加约 1,200 篇 |
| 2023-04-05 | Retraction Watch 报道追加撤回论文全部来自特刊，特刊被论文工厂针对性利用 |
| 2023-05-02 | Hindawi 关闭四个被论文工厂严重侵入的期刊 |
| 2023-06-21 | 本地最大同日 Hindawi 批次 465 篇 |
| 2023-06–08 | 本地出现连续大批次，月撤稿量分别 1,191、1,608、1,697 篇 |
| 2023-12-06 | Wiley 财报确认 Hindawi 暂停使 Research 季度收入减少约 1,800 万美元，并宣布停用 Hindawi 品牌 |
| 2023-12-12 | Wiley 白皮书称数千篇稿件需要调查 |
| 2023-12-19 | Retraction Watch 报道 Hindawi 在 2023 年已撤回超过 8,000 篇 |

## 与本地数据对应

- 2023 主分析事件论文：10,028。
- Hindawi：8,036，占 80.14%。
- 出版流程族：7,122，占 71.02%。
- 原论文发表于 2021–2022：85.93%。
- 最大同日同出版社批次：2023-06-21，Hindawi 465 篇。

外部治理行动与本地最大批次的时间顺序一致：去索引、特刊暂停、追加撤稿和期刊关闭
先于 6–8 月本地批量通知。时间顺序只支持事件解释，不证明单一行动造成后续批次。

## H4 判断

H4 状态：

> 支持“2023 峰值主要由出版社特刊治理和集中撤稿形成”，不支持解释为中国不端发生率变化。

该判断由四类证据共同支持：

1. 出版社官方披露特刊被论文工厂侵入。
2. Wiley 明确披露分批撤回和大规模调查。
3. 本地样本高度集中于 Hindawi 和出版流程族。
4. 同日批次集中在 Hindawi 期刊。

## 反事实边界

### 不估计国家不端率

撤稿通知不是问题论文完整普查，也没有完整总发表量分母。2023 峰值不能转化为中国
学术不端发生率。

### 不作中国特定因果归因

外部资料描述的是全球出版社、特刊和期刊治理事件。它不能解释为中国科研环境变化。

### 不把时间顺序当因果

期刊关闭和去索引早于本地大批次，但通知可滞后数月到数年。现有资料不能估计治理行动
对通知时间的因果效应。

### 不强行统一计数

本地 `8,036` 是 OpenAlex 链接和大陆确认后的 2023 主分析样本；
外部 `超过 8,000` 是 Hindawi 出版社年度撤稿口径；`10,028` 是本地事件样本。
三者不能直接相减或互相验证到个位数。

### 通知日期不等于问题日期

2023 批次主要对应 2021–2022 原论文队列。报告必须并列原论文发表年与撤稿通知年。

### 集中度不等于责任

Hindawi、期刊和同日批次集中度表示治理暴露和出版流程风险，不是作者、机构或个人责任判断。

## 来源质量

一级来源：

- Hindawi 官方公告。
- Wiley 研究负责人署名文章。
- Clarivate 官方声明。
- Wiley 官方财报 PDF。
- Wiley 官方白皮书。

二级来源：

- Retraction Watch 事件报道。
- Nature 同行评审新闻分析。

Hindawi 官方公告和 Wiley 白皮书实时页面触发安全验证，使用 Wayback Machine 快照。
Wiley 财报 PDF 直接下载并用 `pdftotext` 提取原文。

## 输出

- `data/reference/event_2023_external_sources.csv`
- `data/reference/event_2023_external_claims.csv`
- `data/outputs/audits/tables/event_2023_external_evidence.csv`
- `data/outputs/audits/tables/event_2023_external_timeline.csv`
- `data/outputs/audits/tables/event_2023_mechanism_map.csv`
- `data/outputs/audits/tables/event_2023_counterfactual_boundaries.csv`
- `data/outputs/audits/tables/event_2023_external_claim_quality.csv`
- `data/outputs/audits/tables/event_2023_external_validation.csv`
- `data/outputs/audits/tables/event_2023_hypothesis_evidence.csv`
- `data/external/snapshots/event_2023/manifest.json`
