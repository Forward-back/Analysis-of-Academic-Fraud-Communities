# 中国大陆撤稿原因与合作资源位势网络

> 基于 Retraction Watch、OpenAlex 与 Crossref 的出版治理数据研究  
> 当前状态：机构层级与 1:2 对照匹配已完成；等待 OpenAlex 额度恢复后补齐对照机构地理元数据

## 项目在回答什么问题

撤稿不是一种同质事件。数据操纵、图像问题、论文工厂、同行评审操纵和署名争议，对出版社意味着不同的核查能力与治理流程。

本项目以中国大陆关联撤稿论文为主样本，将撤稿原因族与作者合作结构连接起来，重点观察团队机构层级、合作地理和跨论文重复合作，并与匹配的非撤稿论文比较。

项目不建立个人“风险排行榜”。它试图回答一个更接近编辑决策的问题：

> 当研究诚信资源有限时，出版社是否应根据不同撤稿原因对应的合作结构与资源位势，配置不同的数据、图像、同行评审和署名核查能力？

## 分析方向

### 1. 原因族与资源位势

比较出版流程操纵、图像完整性和剽窃/署名三类撤稿论文，相对匹配非撤稿论文是否具有不同的国家重点高校参与、跨层级合作、跨省合作和国际合作结构。

### 2. 跨论文重复合作

从 OpenAlex 作者 ID 构建合作网络，使用保持论文团队构成的置换零模型识别重复合作超额，筛选 25 个待核查社群。

### 3. 2023 年撤稿峰

2023 年中国大陆关联记录中约 80.6% 来自 Hindawi，且多数论文发表于 2021 至 2022 年。项目将这一峰值作为出版社特刊治理与批量撤稿事件拆解，而不是中国学术不端发生率上升的证据。

### 4. 待核查社群的资助组合

对固定筛选的待核查社群进行第二阶段审计，观察资助机构多样性和项目编号重叠。金额只采用官方可核验记录，不参与社群筛选，也不分摊到论文。

## 项目价值

- **从撤稿数量走向治理结构**：不只统计多少论文被撤，而是解释不同原因对应的合作资源组合。
- **使用匹配基线降低混杂**：按原论文发表年、期刊、文献类型和学科层级匹配非撤稿论文。
- **正面对待中国制度背景**：引入 985/211、双一流、省级地理和国内机构层级。
- **区分常规结构与批量事件**：将 2023 年出版社清理行动从长期趋势中独立出来。
- **保持方法透明**：多标签原因、机构缺失、作者 ID 冲突和资助覆盖均作为研究限制报告。

## 预计效果

项目最终应交付一条可复核的证据链：

1. 中国大陆撤稿样本、原因族和 OpenAlex 覆盖的透明审计。
2. 不同原因族的机构层级与合作地理结构画像。
3. 具有跨论文重复合作超额的待核查社群清单。
4. 2023 年批量撤稿事件的本地数据与外部资料证据表。
5. 少量待核查社群的资助组合审计与官方金额覆盖说明。
6. 用于编辑部资源配置的筛查线索，而不是个人或机构责任判断。
7. 可交互 Shiny 仪表盘、Markdown 报告、汇报提纲和可复跑 R 管道。

## 当前数据基座

| 指标 | 当前值 |
|---|---:|
| Retraction Watch 通知记录 | 73,597 |
| Retraction 主事件 | 68,155 |
| 2012–2025 核心记录 | 52,638 |
| 中国大陆候选唯一 DOI | 26,526 |
| 严格错误/信息不足对照唯一 DOI | 4,728 |
| 原因映射未登记标签 | 0 |
| OpenAlex 500 DOI 压测匹配率 | 100% |
| OpenAlex 确认中国大陆 | 92.6% |
| 论文全部作者有机构 ID | 81.6% |
| 资助机构记录覆盖 | 32.4% |

这些数字是当前数据的审计结果，不是最终研究结论。详细口径见 [数据质量审计](docs/data/quality-audit.md)。

## 核心方法

- 原因层：112 个标签按问题领域、证据状态和处理背景三轴编码，多标签允许重叠。
- 论文层：匹配非撤稿论文与混合效应模型。
- 网络层：作者合作网络、重复合作超额与置换零模型。
- 社群层：Leiden 社群检测与稳定性筛选。
- 稳健性：条件 logistic、机构口径替代、排除作者重叠对照和批次剔除。
- 事件层：2023 年时间批次拆解与 Crossref 期刊年度分母。
- 资助层：第二阶段官方资助记录核验。

## 项目结构

```text
.
├─ README.md
├─ CONTEXT.md
├─ CONTRIBUTING.md
├─ .github/         # PR 模板与 GitHub 协作配置
├─ .Rprofile        # 自动激活 renv
├─ renv/            # renv 引导与设置
├─ renv.lock        # 当前依赖版本
├─ config/          # 项目参数、分析口径和环境模板
├─ data/
│  ├─ raw/          # 不可修改原始数据
│  ├─ cache/        # API 原始响应
│  ├─ external/     # 第三方来源与快照
│  ├─ reference/    # 项目自建并冻结的映射
│  ├─ interim/      # 清洗中间表
│  ├─ processed/    # 分析面板与网络对象
│  └─ outputs/      # audits、baseline、final 与 app 阶段制品
├─ R/               # 编号化分析管道
├─ scripts/         # 环境检查与运行入口
├─ docs/            # 研究、数据、方法、运营与交付规格
├─ app/             # Shiny 应用
├─ reports/         # 最终报告、汇报和构建素材
└─ tests/           # 数据口径与关键数字回归测试
```

## 快速开始

```powershell
# 检查依赖
Rscript scripts/check_environment.R

# 重跑基础 EDA
powershell -ExecutionPolicy Bypass -File scripts/run_initial_eda.ps1

# 运行结构测试
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1

# 构建应用数据和报告素材
powershell -ExecutionPolicy Bypass -File scripts/build_deliverables.ps1
```

项目位于 ASCII 路径时，可用 `Rscript -e "renv::restore()"` 恢复锁文件环境。当前项目位于中文路径，R 正式执行使用 ASCII 暂存运行器；详见 [复现说明](docs/operations/reproduction.md)。

OpenAlex API key 通过环境变量提供：

```powershell
$env:OPENALEX_API_KEY = "..."
```

不要把 key、邮箱或缓存响应写入公开代码。

## 文档入口

- [文档总索引](docs/README.md)
- [研究定位与问题](docs/research/research-brief.md)
- [数据来源与口径](docs/data/sources.md)
- [分析计划](docs/methods/analysis-plan.md)
- [当前进度](docs/progress/current-status.md)
- [里程碑](docs/progress/milestones.md)
- [复现说明](docs/operations/reproduction.md)
- [关键决策](docs/decisions/README.md)
- [仓库文件与制品契约](docs/decisions/0002-repository-file-contract.md)
- [贡献与 PR 规范](CONTRIBUTING.md)

## 解释边界

- 原因标签表示撤稿通知中的问题，不等同于正式学术不端裁决。
- 共同署名不表示共同造假。
- 匹配比较是观察性关联，不提供因果识别。
- 不以撤稿记录数除以总发表量推断国家或机构不端率。
- 不展示个人作者撤稿排行榜。
- Retraction Watch 原始数据的再发布权利仍待确认，公开版本优先提供脚本、聚合结果和派生指标。
