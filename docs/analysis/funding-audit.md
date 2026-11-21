# 资助可追溯性审计

> 状态：样本冻结、OpenAlex 与 Crossref 覆盖完成；官方项目记录核验待继续
> 完成日期：2026-11-21
> 样本：25 个审计簇；250 篇唯一论文

## 样本冻结

每个审计簇最多抽取 20 篇论文，按撤稿年份和出版社分层随机抽样。抽样在查询资助
官方记录前完成。

- 候选审计簇论文：308。
- 冻结样本：250 篇唯一论文。
- 审计簇：25。
- 单簇最大样本：20。
- 全局随机种子：`20261117`。
- 每簇使用独立固定种子。

样本清单、分层计数和哈希 manifest 已冻结。

## OpenAlex 覆盖

| 样本 | 论文 | 有资助机构 | 覆盖率 |
|---|---:|---:|---:|
| 审计簇样本 | 250 | 156 | 62.40% |
| 匹配非撤稿对照 | 494 | 331 | 67.00% |
| 未入选候选簇 | 88 | 28 | 31.82% |

审计样本的 OpenAlex 95% 覆盖率区间为 `56.25%–68.17%`。

OpenAlex 奖项字段覆盖 121/250，低于资助机构字段覆盖。资助机构覆盖率通过 50%
质量门槛，但奖项字段仍明显不完整。

## Crossref 补充

Crossref 对 250 个 DOI 的请求全部成功：

- HTTP 200：250。
- HTTP 404：0。
- 网络或 JSON 失败：0。
- 有资助机构：95。
- 有项目编号：85。

OpenAlex 与 Crossref 合并后：

- 任一资助记录覆盖：65.2%。
- 资助机构覆盖：65.2%。
- 项目编号覆盖：52.4%。

因此资助分析可以进入主结果链，但必须等待官方项目记录核验后才可解释具体项目组合。

## 资助机构

OpenAlex 共出现 103 个资助机构 ID，成功解析 102 个名称。

| 资助机构 | 样本论文 | 审计簇 |
|---|---:|---:|
| 国家自然科学基金委员会 | 117 | 20 |
| 江苏省人民政府 | 13 | 1 |
| 江苏师范大学 | 13 | 1 |
| 江苏高校优势学科建设工程 | 13 | 1 |

国家自然科学基金在 OpenAlex 的覆盖面很广，但这属于元数据关联，不是资金来源证明。

Crossref 中，国家自然科学基金出现在 64 篇样本、17 个审计簇。Crossref 对项目署名
来自出版社提交元数据，通常比 OpenAlex 的更接近论文声明。

## 项目编号复用

Crossref 项目编号显示明显的簇内重复：

- 最多重复的项目编号出现在 10 篇样本论文中。
- 前四个最高复用项目均只出现在单一审计簇。
- Crossref 项目编号跨多个审计簇复用的数量为 0。

高频项目包括 `50571048`、`81271225`、`81400902` 和 `81571055`。

这说明资助组合重叠主要发生在同一审计簇内部，而不是不同审计簇共用一个项目编号。
项目编号重复可能来自共同资助团队、同一作者群、元数据模板或批量论文写作，当前不能
区分具体机制。

## H5 判断

H5 状态：

> 对“待核查社群具有重复资助机构或项目编号”提供探索性支持。

支持点：

- 合并资助覆盖 65.2%。
- 国家自然科学基金跨 17 个审计簇重复出现。
- 多个项目编号在同一审计簇内重复 5–10 次。

未支持部分：

- 项目编号跨不同审计簇重复为 0。
- 官方项目记录和金额尚未核验。
- 资助重复不能解释为造假动机或风险分数。

## 官方核验队列

已按样本内复用次数冻结前 25 个项目编号，等待：

- 官方项目名称。
- 项目负责人和承担单位。
- 立项与结题年份。
- 可核验金额、币种和官方 URL。
- 官方记录与论文署名的一致性。

未核实项目不补零、不插补、不分摊金额。

## 当前边界

- 匹配对照的 Crossref 补充尚未查询，当前对照覆盖为 OpenAlex 口径。
- 未入选候选簇样本仅 88 篇，内部基线覆盖较低。
- OpenAlex 与 Crossref 对项目编号的编码不同，不能直接按字符串合并。
- 无资助记录不等于无资助。
- 同一项目编号可合法支持多篇论文，重复本身不是异常。
- 资助组合不进入社群筛选排序。

## 输出

- `data/outputs/audits/tables/funding_audit_sample.csv`
- `data/outputs/audits/tables/funding_audit_sample_summary.csv`
- `data/outputs/audits/tables/funding_audit_sample_strata.csv`
- `data/outputs/audits/tables/funding_audit_group_coverage.csv`
- `data/outputs/audits/tables/funding_audit_funder_reuse.csv`
- `data/outputs/audits/tables/funding_audit_award_reuse.csv`
- `data/outputs/audits/tables/funding_funder_metadata.csv`
- `data/outputs/audits/tables/funding_funder_reuse_named.csv`
- `data/outputs/audits/tables/funding_crossref_paper_metadata.csv`
- `data/outputs/audits/tables/funding_crossref_funder_reuse.csv`
- `data/outputs/audits/tables/funding_crossref_award_reuse.csv`
- `data/outputs/audits/tables/funding_combined_paper_metadata.csv`
- `data/outputs/audits/tables/funding_audit_combined_decision.csv`
- `data/outputs/audits/tables/funding_hypothesis_evidence.csv`
- `data/outputs/audits/tables/funding_project_verification_queue.csv`
- `data/external/snapshots/funding_audit_v1/manifest.json`
