# 2023 期刊年度分母

> 状态：首轮 Crossref 分母完成

## 口径

2023 撤稿论文先按原论文发表年份分层，再匹配同一期刊、同一原论文年份的 Crossref
年度发表量。不得用 2023 撤稿论文数直接除以 2023 发表量。

Crossref `total-results` 作为期刊年度记录量，表示 Crossref 中该 ISSN 在指定
发表日期区间内的记录数，不保证等同于完整论文数或出版社会计口径。

## 覆盖

- 2023 撤稿年份相关的前 20 期刊：20 个。
- 有 ISSN：20 个。
- 年度请求：160。
- 成功返回：160。
- 2023 撤稿论文覆盖：7,397 / 7,397。

BioMed Research International 使用较新的 ISSN `2314-6133`，避免旧 ISSN 的
2023 Crossref 计数为零。SAGE 期刊通过期刊名别名映射到 `0020-7209`。

## 原论文年份队列

2021 和 2022 是事件主要原论文队列：

- 2021：事件论文 1,575；Crossref 分母 15,459；每千篇约 101.88。
- 2022：事件论文 5,555；Crossref 分母 25,790；每千篇约 215.39。

这些比率只描述撤稿论文数相对 Crossref 记录量的比例，不等同于学术不端发生率。

## 输出

- `data/outputs/audits/tables/event_2023_journal_identifiers.csv`
- `data/outputs/audits/tables/event_2023_crossref_coverage.csv`
- `data/outputs/audits/tables/event_2023_journal_annual_denominators.csv`
- `data/outputs/audits/tables/event_2023_journal_original_year_rates.csv`

## 边界

- Crossref 记录量包含的记录类型和发表时间口径需在报告方法中说明。
- 2023 峰值仍由 2021–2022 原论文队列和出版社批量清理主导，不能直接解释为
  同期国家不端率变化。
- 外部出版社治理资料尚未完成，机制解释仍是待核验证据。
