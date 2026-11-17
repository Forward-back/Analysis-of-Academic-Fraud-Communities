# 0002：仓库文件与制品契约

- 状态：已接受
- 日期：2026-11-17
- 决策范围：文件归属、制品发布、构建边界与复核流程

## 背景

项目同时包含研究设计、统计分析、外部数据、报告和 Shiny 应用。如果只按文件名
或临时需要放置文件，外部数据、派生映射、分析输出和最终交付物会相互混杂，
导致无法判断哪个版本可以引用、哪些文件可以提交以及哪条命令能重建结果。

本决策不改变研究样本、原因族定义、匹配规则或质量门槛。它只规定文件与制品边界。

## 决策

### 数据与映射

1. `data/raw/` 只存冻结原始文件。
2. `data/cache/` 只存 API 原始响应、请求参数和重试日志。
3. `data/external/` 只存第三方来源、公开名单和原始快照。
4. `data/reference/` 保存项目自建、人工复核并冻结的字段、原因和机构映射。
5. `data/interim/` 和 `data/processed/` 保存可再生中间表与分析面板。
6. 自动脚本不得覆盖 `data/reference/`；候选映射写入 `data/interim/mappings/`，
   经人工复核后以新版本进入 `data/reference/`。

### 分析输出

`data/outputs/` 按阶段优先组织：

```text
audits/{tables,figures}/
baseline/{tables,figures}/
final/{tables,figures,models}/
app/{tables}/
```

- 每个冻结阶段在阶段根目录保存 `manifest.json`。
- manifest 使用项目相对路径，并记录输入哈希、生成时间、版本和输出文件清单。
- 小型表格、图、审计结果和模型摘要进入 Git。
- 原始 CSV、API 缓存、大型 RDS、临时文件和密钥不进入 Git。

### 文档、报告与应用

- `docs/specs/` 定义交付物应满足的要求。
- `docs/research/`、`docs/data/`、`docs/methods/` 和 `docs/operations/` 定义研究及执行规则。
- `reports/` 只保存最终报告、最终汇报和构建后的报告素材。
- `data/outputs/app/` 是应用数据的唯一源目录。
- `scripts/build_deliverables.R` 将应用数据同步到可独立部署的 `app/data/`，
  将最终图同步到 `reports/assets/figures/`，并分别生成构建 manifest。
- 禁止手工维护与 `data/outputs/` 不一致的应用或报告副本。

### 版本控制与变更复核

- 主分支为 `main`；功能、修复和文档改造使用短生命周期分支。
- 涉及研究口径、匹配、样本、原因族或结论的修改必须新建 ADR 并在 PR 中单独说明。
- 涉及目录边界、构建方式或发布范围的修改必须同步更新本 ADR 和对应目录 README。
- PR 必须使用 `.github/pull_request_template.md`。
- 原始数据、缓存、密钥和本机路径不得进入提交历史。

## 后果

- 目录比“所有结果放一个 outputs 文件夹”略深，但每个文件的归属和生命周期明确。
- 原因字典修改需要人工复核和版本升级，不能靠重跑脚本自动覆盖。
- 应用和报告发布前必须运行构建脚本，因此可独立部署，但 Git 仓库中的
  `app/data/` 不作为权威数据源。
- 新成员需要先阅读 `CONTRIBUTING.md`、本 ADR 和 `docs/operations/reproduction.md`。
