# 2023 本地事件拆解

> 状态：本地构成拆解完成，Crossref 分母和外部证据未完成  
> 样本：OpenAlex 确认大陆且通过标题链接审计的 2023 撤稿论文

## 样本规模

- 2023 主分析论文：10,028。
- 撤稿通知记录：10,028。
- 出版社：69。
- 期刊：482。
- 日期范围：2023-01-02 至 2023-12-31。

候选 RWDB 样本中的 10,697 条记录与本表的 OpenAlex 主分析样本口径不同，不能混用。

## 出版社与期刊

- Hindawi：8,036 篇，占 80.14%。
- Elsevier：481 篇，占 4.80%。
- SAGE：208 篇，占 2.07%。
- 前 20 期刊全部为 Hindawi 期刊，单刊最高 847 篇。

## 时间与原论文年份

- 6 月：1,191 篇。
- 7 月：1,608 篇。
- 8 月：1,697 篇。
- 10 月：1,085 篇。
- 12 月：1,642 篇。
- 原论文发表于 2021：2,124 篇。
- 原论文发表于 2022：6,493 篇。
- 2021–2022 队列合计占 85.93%。

最大同日同出版社批次为 2023-06-21 的 Hindawi 465 篇。

## 原因构成

- 出版流程：7,122 篇，占 71.02%。
- 图像完整性：673 篇，占 6.71%。
- 剽窃/署名：432 篇，占 4.31%。
- 研究伦理与合规：1,439 篇，占 14.35%。
- 严格错误参照：1,686 篇，占 16.81%。

原因族多标签，比例不能相加。

## 输出

- `data/outputs/audits/tables/event_2023_summary.csv`
- `data/outputs/audits/tables/event_2023_monthly.csv`
- `data/outputs/audits/tables/event_2023_publisher.csv`
- `data/outputs/audits/tables/event_2023_journal_top.csv`
- `data/outputs/audits/tables/event_2023_original_year.csv`
- `data/outputs/audits/tables/event_2023_reason_family.csv`
- `data/outputs/audits/tables/event_2023_same_day_batches.csv`

## 解释边界

本地构成支持“出版社集中治理与批量撤稿”的事件解释。Crossref 期刊年度分母和外部治理资料尚未加入，不能据此计算不端发生率或作因果解释。
