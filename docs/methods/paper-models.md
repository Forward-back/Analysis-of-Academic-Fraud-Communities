# 论文层模型

> 状态：计划

## 分析样本

- 匹配非撤稿论文与已确认中国大陆撤稿论文。
- 机构层级和地理结果使用机构完整子集。
- 团队人数可使用全部 `CN` 确认论文。
- 主分析允许作者重叠。

## 结果变量

| 变量 | 类型 | 模型 |
|---|---|---|
| `cross_tier` | 二元 | 混合 logistic |
| `domestic_cross_province` | 二元 | 混合 logistic |
| `international` | 二元 | 混合 logistic |
| `n_authors` | 计数 | 负二项或对数线性混合 |
| `median_geo_distance_km` | 连续正数 | log 后线性混合 |

地理四分类主要用于描述图，不以难以收敛的多分类混合模型作为唯一主结果。

## 主要解释变量

- `family_publication_process`
- `family_image_integrity`
- `family_plagiarism_authorship`
- 探索性 `family_data_integrity`
- 参照 `family_error_control`

每个原因族单独运行，允许同篇论文进入多个族。

## 控制变量

- 原论文发表年份平滑项。
- OpenAlex 学科 `field` 或 `primary_topic`。
- 文献类型。
- 期刊或出版社随机效应。
- 团队人数用于机构构成和距离模型。
- 匹配组随机截距。

## 模型选择

- 主模型优先 `glmmTMB` 或 `lme4`，以实际收敛和诊断为准。
- 随机效应过复杂时，先简化随机效应，再考虑稳健标准误。
- 模型不收敛时记录原因，不使用不透明调参制造结果。
- 条件 logistic 仅作方向稳健性。

## 报告内容

- 固定效应、区间和效应量。
- 随机效应方差。
- 样本量与匹配完整性。
- 模型诊断和收敛信息。
- FDR 校正结果。
- 全样本、批次剔除和作者重叠排除的稳健性。
