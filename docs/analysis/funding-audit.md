# 资助可追溯性审计

> 状态：样本冻结、同源基线、官方项目核验和 P4 结果图完成
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

## 同源基线

为避免审计样本使用 OpenAlex+Crossref、而对照只使用 OpenAlex 的口径不对称，补充查询
匹配对照和未入选候选论文的 Crossref 资助元数据。

冻结比较组：

| 组 | 论文 | 说明 |
|---|---:|---|
| 审计簇样本 | 250 | 25 个固定审计簇的分层样本 |
| 匹配非撤稿对照 | 494 | 与审计样本案例同匹配组 |
| 未入选候选论文 | 87 | 不属于 25 个审计簇，且排除与审计样本重叠的论文 |

原 P4A 未入选组为 88 篇，其中 `paper_008182` 同时属于入选组件和未入选组件。P4B
改为“论文不在 250 篇入选样本中”，内部基线因此为 87 篇。修正后 831 个记录对应
831 个唯一 DOI，组间无重复 DOI。

Crossref 查询 831 个唯一 DOI，HTTP 200 为 831，HTTP 404 为 0，网络或 JSON 失败
为 0。

| 来源 | 审计簇样本 | 匹配对照 | 未入选候选论文 |
|---|---:|---:|---:|
| OpenAlex 任一资助 | 62.4% | 67.0% | 32.2% |
| Crossref 任一资助 | 38.0% | 45.1% | 13.8% |
| 合并两来源 | 65.2% | 68.4% | 34.5% |

合并来源的 Wilson 95% 区间：

- 审计簇样本：`59.1%–70.8%`。
- 匹配对照：`64.2%–72.4%`。
- 未入选候选论文：`25.3%–44.9%`。

同源后，审计簇样本的资助覆盖比匹配对照低 `3.2` 个百分点，比未入选候选论文高
`30.7` 个百分点。此前“审计样本 OpenAlex 覆盖略低于对照”的方向保持，但不能把
审计簇写成资助记录更完整或更异常。

来源一致性显示记录并非等价：

| 组 | 两来源均有 | 仅 OpenAlex | 仅 Crossref | 两来源均无 |
|---|---:|---:|---:|---:|
| 审计簇样本 | 88 | 68 | 7 | 87 |
| 匹配对照 | 216 | 115 | 7 | 156 |
| 未入选候选论文 | 10 | 18 | 2 | 57 |

## 官方项目核验

前 25 个复用项目编号中：

- 官方结题项目记录已核验：10。
- 国家自然科学基金公开结题库未返回：7。
- 其他非 NSFC 编号未找到可公开检索的单项官方项目记录：8。

已核验的 10 项均来自国家自然科学基金官方结题项目库，记录包含项目名称、项目类别、
负责人、依托单位、批准年度、结题年度和官方资助经费。官方查询结果没有提供可核验的
月级起止日期，因此 `start_year` 和 `end_year` 留空，不按批准/结题年度推算。

| 批准号 | 项目名称 | 依托单位 | 负责人 | 批准/结题 | 官方经费 |
|---|---|---|---|---|---:|
| `50571048` | 变形镁合金电致塑性的应用基础研究 | 清华大学 | 唐国翌 | 2005/2008 | 25.0 万元 |
| `81271225` | 毛蕊异黄酮改善高胆固醇饲喂致小鼠神经记忆损伤的机制 | 江苏师范大学 | 陆军 | 2012/2016 | 70.0 万元 |
| `81171012` | 内质网应激介导的代谢综合症致脑损伤的分子机制及花青素干预的研究 | 江苏师范大学 | 郑元林 | 2011/2015 | 60.0 万元 |
| `30950031` | 甘薯花青素对衰老脑组织炎症损伤干预的分子机制研究 | 江苏师范大学 | 郑元林 | 2009/2010 | 10.0 万元 |
| `31201039` | 紫薯花青素调控内皮细胞老化的分子机制研究 | 江苏师范大学 | 孙春辉 | 2012/2015 | 23.0 万元 |
| `31700432` | 基于生态因子调控废水处理中光合细菌能量与聚-β-羟丁酸（PHB）合成途径促进胞内PHB累积的研究 | 大连民族大学 | 吴盼 | 2017/2020 | 21.0 万元 |
| `31400386` | 我国东北森林典型树种氮吸收偏好及其对氮沉降的响应 | 中国科学院沈阳应用生态研究所 | 朱飞飞 | 2014/2017 | 23.0 万元 |
| `31470550` | 邻苯二甲酸二丁酯（DBP）胁迫的黄瓜生态毒理学响应及表达差异蛋白质组学研究 | 东北农业大学 | 张颖 | 2014/2018 | 86.0 万元 |
| `51778114` | 基于Hopf分叉理论和ASMs模型的多级环流MBR处理β-内酰胺类抗生素及中间体废水的多重稳态性调控机制研究 | 大连民族大学 | 陈兆波 | 2017/2021 | 62.0 万元 |
| `81500493` | GJ的Ca2+传递引起钙稳态失衡诱导内质网应激在肝移植术后急性肾损伤中的作用研究 | 中山大学 | 王艳玲 | 2015/2018 | 18.0 万元 |

官方结题库未返回批准号不表示项目不存在。NSFC 批准项目查询需要交互式完成验证码，
未绕过该限制；其他 8 个编号也没有找到可直接定位的公开单项官方项目页。

## H5 判断

H5 状态：

> 对“待核查社群在簇内重复资助机构和项目编号”提供探索性支持；官方记录核验为部分
> 完成，不能把重复项目号解释为不端、动机或风险分数。

支持点：

- 合并资助覆盖 65.2%。
- 国家自然科学基金跨 17 个审计簇重复出现。
- 多个项目编号在同一审计簇内重复 5–10 次。
- 10 个高频项目编号的一一对应官方结题记录已完成。
- 官方核验项目关联 26 个唯一 DOI 论文、3 个审计簇。

未支持部分：

- 项目编号跨不同审计簇重复为 0。
- 仍有 15 个高频项目编号缺少可公开核验的单项官方记录。
- 官方查询没有提供月级项目起止日期。
- 26 个官方核验论文只来自 3 个审计簇，不能外推到 25 个簇。
- 资助重复不能解释为造假动机或风险分数。

## 官方核验队列

已按样本内复用次数冻结前 25 个项目编号，并记录：

- 官方项目名称。
- 项目负责人和承担单位。
- 立项与结题年份。
- 可核验金额、币种和官方 URL。
- 官方记录与论文署名的一致性。

未核实项目不补零、不插补、不分摊金额。官方金额只保留在项目级证据表，不进入社群
排序或论文层模型。

## 当前边界

- 匹配对照和未入选候选论文已补充 Crossref；内部基线为 87 篇。
- 未入选候选论文覆盖较低，区间较宽。
- OpenAlex 与 Crossref 对项目编号的编码不同，不能直接按字符串合并。
- 无资助记录不等于无资助。
- 同一项目编号可合法支持多篇论文，重复本身不是异常。
- 7 个 NSFC 编号未出现在公开结题库，8 个其他编号没有可定位的公开单项记录。
- 资助覆盖在同源后仍低于匹配对照，不能把审计簇写成资助更集中或更完整。
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
- `data/outputs/audits/tables/funding_source_symmetric_comparison_works.csv`
- `data/outputs/audits/tables/funding_source_symmetric_group_coverage.csv`
- `data/outputs/audits/tables/funding_source_symmetric_agreement.csv`
- `data/outputs/audits/tables/funding_source_symmetric_contrasts.csv`
- `data/outputs/audits/tables/funding_official_project_verification.csv`
- `data/outputs/audits/tables/funding_project_paper_evidence.csv`
- `data/outputs/audits/tables/funding_award_doi_reuse_verified.csv`
- `data/outputs/audits/tables/funding_h5_final_evidence.csv`
- `data/outputs/audits/figures/p4_funding_coverage_source_symmetric.svg`
- `data/outputs/audits/figures/p4_funding_source_agreement.svg`
- `data/outputs/audits/figures/p4_funding_official_verification_status.svg`
- `data/external/snapshots/funding_audit_v1/manifest.json`
- `data/external/snapshots/funding_source_symmetric_v1/frozen_comparison_manifest.json`
- `data/external/snapshots/funding_official_verification_v1/manifest.json`
