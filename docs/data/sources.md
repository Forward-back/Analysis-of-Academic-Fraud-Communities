# 数据来源

> 状态：主数据、机构、事件和可访问官方资助记录已冻结

## 核心组合

| 来源 | 作用 | 不可替代性 | 当前状态 |
|---|---|---|---|
| Retraction Watch Database | 撤稿事实、原因、期刊、出版社、原论文 DOI | 原因标签主表 | 已取得冻结 CSV |
| OpenAlex | 作者 ID、ORCID、机构、国家、地理、学科、来源、资助元数据 | 作者和机构主表 | P0 与主样本机构全量解析完成 |
| Crossref | DOI 更新关系、资助元数据、期刊年度发表量 | 核验与分母 | 2023 年度分母和 P4 同源资助补充完成 |
| ROR | 机构稳定标识与别名 | OpenAlex 内嵌，后置核验 | 5,720 所主样本机构已完成 OpenAlex ID 映射 |
| 公开 985/211 与双一流名单 | 中国机构层级 | 中国情境变量 | 快照、候选和冻结注册表完成 |
| 公开行政区映射 | 城市、省份、港澳台 | 地理分类 | 快照和主样本机构映射完成 |
| 出版社公告、期刊页面、公共研究 | 2023 事件机制证据 | 外部解释 | 已获得初步公开来源 |
| 基金官方项目库 | 项目编号与金额核验 | 资助专项证据 | 10/25 高频项目有官方结题记录 |

## Retraction Watch

- 仓库：<https://gitlab.com/crossref/retraction-watch-data>
- 冻结文件：`data/raw/retractions.csv`
- 观察日期：2026-11-04
- 文件大小：67,942,450 字节
- SHA-256：`eefbe08a9ecfa75308951fb7b03d265e9ccd8431eca32d9727b7ddc8c4b70faa`
- 通知记录：73,597
- Retraction：68,155
- 唯一原因标签：112

原始文件版本构建标识未可靠取得。项目只使用这一份冻结副本，不通过删除记录制造另一版本。

## OpenAlex

- 官网：<https://openalex.org/>
- API：<https://api.openalex.org/>
- 许可：CC0
- 关键字段：
  - `authorships[].author.id`
  - `authorships[].author.orcid`
  - `authorships[].institutions[]`
  - `authorships[].countries[]`
  - `primary_location.source`
  - `primary_topic`
  - `funders`
  - `awards`

OpenAlex `is_retracted` 只用于覆盖审计，不能替代 Retraction Watch 原因标签。

## Crossref

- API：<https://api.crossref.org/>
- 用途：更新关系、资助机构、期刊年度分母和抽样核验。
- Crossref `funder` 字段实测只有资助机构信息，不包含金额。
- 期刊年度分母只用于 2023 事件专项。
- 资助分析使用 OpenAlex + Crossref 同源口径；无记录不等于无资助。

## ROR 与公开名单

- ROR：<https://ror.org/>
- 机构层级采用发表年份对应的 985/211 或双一流名单。
- 所有公开名单需要保存原始快照、来源 URL、获取日期、哈希和清洗版本。
- 机构别名优先连接 ROR 和 OpenAlex ID，不以中文名称直接建边。

第三方网页、名单和 API 快照放入 `data/external/`。项目根据这些来源人工整理的
字段、原因和机构映射放入 `data/reference/`。自动脚本只能生成候选映射到
`data/interim/`，不得覆盖已冻结的参考映射。

当前冻结映射见 [映射说明](../../data/reference/mappings/README.md)。

## 外部事件资料

2023 专项优先使用：

- 出版社公告与年度报告。
- 期刊处理或 Clarivate 收录状态公开记录。
- 撤稿通知和期刊特刊页面。
- Retraction Watch、Nature 等公开报道。
- 论文工厂与特刊治理的同行评审研究。

外部资料必须保留标题、作者或机构、日期、URL 和引用原文。AI 生成的引用不能直接使用。
