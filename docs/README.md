# 项目文档索引

本目录是项目的当前有效文档入口。`archive/legacy/` 只保留历史稿件，不参与当前执行。

## 按问题查阅

| 我想了解 | 入口 |
|---|---|
| 项目为什么值得做、最终交付什么 | [研究定位](research/research-brief.md) |
| 研究范围、问题和假设 | [范围与假设](research/scope-and-hypotheses.md) |
| 解释边界和伦理要求 | [边界与伦理](research/boundaries-and-ethics.md) |
| 数据来自哪里 | [数据来源](data/sources.md) |
| 每个变量是什么 | [数据字典](data/dictionary.md) |
| 数据怎样清洗 | [清洗规则](data/cleaning-rules.md) |
| 非撤稿对照怎样匹配 | [匹配设计](data/matching-design.md) |
| 当前数据质量如何 | [质量审计](data/quality-audit.md) |
| 原因映射版本有何差异 | [映射复核](data/reason-mapping-review.md) |
| 整体分析路径 | [分析计划](methods/analysis-plan.md) |
| 论文层模型 | [论文模型](methods/paper-models.md) |
| 网络和社群方法 | [网络方法](methods/network-methods.md) |
| 2023 峰值如何拆解 | [2023 事件方法](methods/event-2023-method.md) |
| 资助专项如何做 | [资助审计方法](methods/funding-audit-method.md) |
| 当前有哪些数据发现 | [基线 EDA](analysis/baseline-eda.md) |
| 匹配是否平衡、对照缺什么 | [匹配平衡与对照机构缺口](analysis/matching-balance.md) |
| 后续模型使用哪些样本 | [分析样本冻结与选择审计](analysis/analysis-samples.md) |
| 网络与重复合作基线 | [作者网络基线](analysis/network-baseline.md) |
| 重复合作是否超过团队构成基线 | [网络零模型](analysis/network-null.md) |
| 固定待核查审计簇 | [25 个审计簇](analysis/audit-clusters.md) |
| 2023 峰值怎样构成 | [2023 本地事件拆解](analysis/event-2023-local.md) |
| 2023 期刊年度分母与相对量级 | [Crossref 分母](analysis/event-2023-crossref.md) |
| 项目跑到哪里了 | [当前进度](progress/current-status.md) |
| 后续挖掘和分析按什么顺序做 | [后续挖掘与分析优先级](operations/analysis-priority.md) |
| 已经遇到哪些惊奇发现和边界 | [探索发现与边界日志](progress/exploration-findings.md) |
| 每个里程碑何时完成 | [里程碑](progress/milestones.md) |
| 如何复现 | [复现说明](operations/reproduction.md) |
| 报告、Shiny 和汇报包含什么 | [交付规格](specs/README.md) |
| 文件、制品和发布边界 | [仓库契约](decisions/0002-repository-file-contract.md) |
| 如何提交 PR | [贡献与 PR 规范](../CONTRIBUTING.md) |
| 哪些设计已经冻结 | [关键决策](decisions/README.md) |

## 文档分工

- `research/` 回答研究为什么成立。
- `data/` 回答数据是什么、怎样得到。
- `methods/` 回答证据怎样生成。
- `analysis/` 记录已经得到或尚待得到的发现。
- `operations/` 记录计划、复现、风险和 AI 使用。
- `specs/` 约定报告、应用和汇报应满足的结构。
- `progress/` 记录里程碑、当前状态和日期日志。
- `decisions/` 保存不易回退的设计选择。
- `archive/legacy/` 保存已被替代的原始文档。

## 状态标记

文档中的状态统一使用：

- `已冻结`：后续分析必须遵守。
- `进行中`：正在实现，允许小范围调整。
- `计划`：尚未执行，不能写成已完成结果。
- `已废弃`：只在归档中保留。
