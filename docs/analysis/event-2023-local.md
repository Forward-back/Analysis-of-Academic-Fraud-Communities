# 2023 本地事件拆解

> 状态：P3 本地构成、Crossref 分母和外部治理证据完成
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

## Crossref 期刊年度分母

### 口径

2023 撤稿论文先按原论文发表年份分层，再匹配同一期刊、同一原论文年份的 Crossref
年度发表量。不得用 2023 撤稿论文数直接除以 2023 发表量。

Crossref `total-results` 表示 Crossref 中该 ISSN 在指定发表日期区间内的记录数，
不保证等同于完整论文数或出版社会计口径。

### 覆盖

前 20 高频期刊的 2018–2025 年度记录量已补齐，20 个 ISSN、160 个期刊年度请求
全部成功。2021 和 2022 原论文队列分别覆盖 1,575 和 5,555 篇事件论文。

- 2023 撤稿年份相关前 20 期刊：20。
- 有 ISSN：20。
- 年度请求与成功返回：`160/160`。
- 2023 撤稿论文覆盖：`7,397/7,397`。

BioMed Research International 使用较新的 ISSN `2314-6133`，避免旧 ISSN 的
2023 Crossref 计数为零。SAGE 期刊通过期刊名别名映射到 `0020-7209`。

### 原论文年份队列

- 2021：事件论文 1,575；Crossref 分母 15,459；每千篇约 101.88。
- 2022：事件论文 5,555；Crossref 分母 25,790；每千篇约 215.39。

这些比率只描述撤稿论文数相对 Crossref 记录量的比例，不等同于学术不端发生率。

## 输出

- `data/outputs/audits/tables/event_2023_summary.csv`
- `data/outputs/audits/tables/event_2023_monthly.csv`
- `data/outputs/audits/tables/event_2023_publisher.csv`
- `data/outputs/audits/tables/event_2023_journal_top.csv`
- `data/outputs/audits/tables/event_2023_original_year.csv`
- `data/outputs/audits/tables/event_2023_reason_family.csv`
- `data/outputs/audits/tables/event_2023_same_day_batches.csv`
- `data/outputs/audits/tables/event_2023_journal_annual_denominators.csv`
- `data/outputs/audits/tables/event_2023_journal_identifiers.csv`
- `data/outputs/audits/tables/event_2023_crossref_coverage.csv`
- `data/outputs/audits/tables/event_2023_journal_original_year_rates.csv`

## 解释边界

本地构成和原论文年份分母支持“出版社集中治理与批量撤稿”的事件解释。Crossref
记录量包含的记录类型和发表时间口径须在报告方法中说明。外部治理资料已补入
[2023 外部治理证据](event-2023-external.md)。仍不能据此计算不端发生率或作因果解释。
