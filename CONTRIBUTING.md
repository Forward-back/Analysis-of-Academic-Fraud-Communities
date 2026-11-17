# 贡献与 PR 规范

本文件规定如何修改代码、数据口径和交付物。目录与制品边界以
[仓库文件与制品契约](docs/decisions/0002-repository-file-contract.md) 为准。

## 开始前

1. 从最新 `main` 建立短生命周期分支。
2. 阅读与改动相关的 `CONTEXT.md`、ADR、方法文档和目录 README。
3. 确认改动属于代码、文档、数据口径、制品结构还是发布构建中的哪一类。

推荐分支名前缀：

```text
feat/       新功能或新分析阶段
fix/        缺陷修复
docs/       仅文档
refactor/   不改变研究口径的结构调整
data/       数据准备或映射更新
chore/      工具、依赖和仓库维护
```

## 提交信息

使用 Conventional Commits：

```text
feat(analysis): add DOI panel builder
fix(manifest): use project-relative source paths
docs(contract): clarify reference mapping ownership
refactor(outputs): organize artifacts by analysis stage
```

一个提交解决一个可解释的问题。不要混入无关格式化或删除用户文件。

## 变更分类

以下改动必须在 PR 中单列为“研究口径变更”，并先新增 ADR：

- 主样本、对照样本或分析单位。
- 原因族定义、匹配变量、匹配比例或退化规则。
- 机构层级、地理分类、网络零模型或质量门槛。
- 2023 事件、资助审计或结论解释边界。

以下改动必须在 PR 中单列为“架构或发布变更”：

- 移动 `data/`、`data/outputs/` 或 `docs/` 的目录边界。
- 改变 manifest、构建、忽略规则或 Git 发布范围。
- 改变报告和应用的数据来源。

## 禁止提交

- `data/raw/` 下的原始 CSV。
- `data/cache/` 下的 API 原始响应。
- `data/interim/` 和 `data/processed/` 下的大型中间对象。
- API key、邮箱、本机用户名、临时目录或绝对路径。
- 未注明来源和版本的手工映射。
- 手工复制的应用数据或报告图。

## 提交前验证

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
Rscript scripts/build_deliverables.R
```

如果本地没有原始数据，集成测试应自动跳过；单元测试仍必须通过，且 PR 中要明确
说明哪些验证基于完整本地数据完成。

## PR 要求

- 使用 [PR 模板](.github/pull_request_template.md)。
- 标题与提交信息使用同一类前缀。
- 说明问题、改动、影响范围和回滚方式。
- 报告命令、测试结果和关键输出文件。
- 涉及数据口径时提供旧口径、新口径、理由和影响样本。
- 涉及目录或发布结构时提供旧路径到新路径的映射。
- 不把“计划”写成“已完成结果”。
- 不在 PR 中提交个人榜单、未核验责任判断或未经许可的原始数据。

## 合并条件

- 单元测试通过。
- 本地有完整数据时，相关集成测试和分析输出通过。
- 有效 Markdown 链接可解析。
- manifest 不含绝对路径或敏感信息。
- 研究口径与 [CONTEXT.md](CONTEXT.md)、ADR、方法和质量门槛一致。
- 至少完成一次人工复核，并解决全部阻断性评论。
