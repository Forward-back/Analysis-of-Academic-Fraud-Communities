# 匹配平衡与对照机构缺口

> 状态：匹配平衡与对照机构缺口审计已完成
> 样本：24,974 篇大陆主分析论文；44,287 篇最终非撤稿对照

## 匹配覆盖

- 匹配到对照的案例：22,198。
- 可匹配层内零对照：2,462。
- 无匹配层：314。
- 主分析零对照合计：2,776。

## 匹配一致性

| 指标 | 结果 |
|---|---:|
| 发表年份一致率 | 100% |
| 文献类型一致率 | 100% |
| 期刊来源一致率 | 91.39% |
| 出版社一致率 | 99.83% |
| 学科 `field` 一致率 | 81.01% |
| 任一学科层级一致率 | 90.13% |

期刊来源率低于 100% 是出版社 fallback 的设计结果。`source_only` 层不要求学科一致。

## 团队规模

- 案例平均团队规模：4.45。
- 对照平均团队规模：5.45。
- 标准化均值差：`-0.307`，对照组团队规模更大。
- 出版社 fallback 和 `source_only` 层的偏差最大。

后续模型必须把团队规模作为控制变量，并报告按匹配层、原因族和团队规模分层的敏感性。

## 对照机构缺口

- 缺失机构元数据：3,767。
- 含缺失元数据的对照作品：4,684。
- 受影响匹配案例：4,267。
- 对照作品作者 ID 完整率：66.82%。
- 对照作品机构完整率：88.11%。

缺口不阻断年份、来源、学科和团队规模审计，但阻断对照片本的机构层级与地理主分析。

## 输出

- `data/outputs/audits/tables/match_balance_summary.csv`
- `data/outputs/audits/tables/match_balance_by_layer.csv`
- `data/outputs/audits/tables/match_balance_by_family.csv`
- `data/outputs/audits/tables/match_link_consistency_audit.csv`
- `data/outputs/audits/tables/p1_post_fetch_link_validation.csv`
- `data/outputs/audits/tables/match_selection_by_match_count.csv`
- `data/outputs/audits/tables/control_institution_gap_summary.csv`
- `data/outputs/audits/tables/control_institution_gap_by_family.csv`

## 待处理

- 已排除 1 条抓取后类型漂移对照。
- 补齐 3,767 个对照机构元数据，并完成对照片本层级与地理富化。
- 模型样本冻结、团队规模控制、匹配层和缺失敏感性已分别在 P0/P1 完成。
