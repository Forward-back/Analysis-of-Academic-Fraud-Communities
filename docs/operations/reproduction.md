# 复现说明

> 状态：仓库契约已建立，正式分析管道待实现

## 环境

- R 4.6.1 或项目锁文件记录的版本。
- `renv` 自动激活并恢复包环境；项目已包含 `.Rprofile` 和 `renv/activate.R`。
- Windows PowerShell 或兼容命令行。
- OpenAlex key 通过 `OPENALEX_API_KEY` 环境变量提供。

## 首次运行

```powershell
Rscript scripts/check_environment.R
powershell -ExecutionPolicy Bypass -File scripts/run_unit_tests.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_integration_tests.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_initial_eda.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
powershell -ExecutionPolicy Bypass -File scripts/build_deliverables.ps1
```

本项目当前位于中文 Windows 路径下，`readr` 与图形设备可能无法直接写入。正式入口
`scripts/run_in_ascii_stage.ps1` 会把代码、原始数据、第三方参考数据和冻结映射复制到
ASCII 暂存目录，运行成功后将 `data/outputs/`、`data/interim/` 等生成结果同步回项目。
直接运行 R 脚本只建议用于不写文件的检查。

`renv.lock` 记录当前依赖，`.Rprofile` 会在 R 启动时激活项目环境。由于 `renv`
在中文项目路径下创建项目库仍可能受到编码限制，完整恢复优先在 ASCII 路径或
ASCII 暂存环境中执行。非 ASCII 路径默认跳过自动激活并给出提示；当前机器上的
正式分析入口使用已安装系统包，并在每次新增核心依赖后更新锁文件。

`scripts/build_deliverables.ps1` 在 ASCII 暂存目录执行，并将 `app/data/` 与
`reports/assets/` 构建结果同步回项目。

## 基础 EDA 输出

- 表格：`data/outputs/baseline/tables/`
- 图：`data/outputs/baseline/figures/`
- manifest：`data/outputs/baseline/manifest.json`
- 原因字典：`data/reference/mappings/reason_dictionary_v1.csv`

脚本读取 `data/reference/mappings/reason_label_registry_v2.csv`、
`reason_domain_map_v2.csv`、`reason_context_map_v2.csv` 和
`analysis_family_domains_v2.csv`。任一原始标签未登记时，脚本立即停止。

原因映射只读诊断：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/audit_reason_mapping.R -IncludeOutputs
```

## API 缓存

- OpenAlex 500 DOI 压测：`data/cache/openalex/pressure-tests/works-500/`
- 对照抽样压测：`data/cache/openalex/pressure-tests/controls-25/`

正式抓取遵循相同模式，缓存原始 JSON，并记录请求清单、失败和重试日志。

## 数据冻结

- 原始 CSV 只读。
- 下载日期和观察日期分开记录。
- 文件哈希写入 manifest。
- 派生数据可删除重建。
- `external/` 与 `reference/` 的来源边界不可混用。
- manifest 只记录项目相对路径。

## 应用与报告构建

`data/outputs/app/` 是应用数据源，`data/outputs/final/figures/` 是报告图源。
构建脚本生成可独立部署的 `app/data/` 和 `reports/assets/figures/`；
生成目录不作为权威源，修改数据时必须先更新冻结输出。

## Git 与 PR

- `main` 为稳定分支，改动通过短生命周期分支和 Pull Request 完成。
- 原始数据、API 缓存、密钥和大型 RDS 不提交。
- 提交前阅读 [贡献与 PR 规范](../../CONTRIBUTING.md)。
- PR 使用 `.github/pull_request_template.md`。
- 涉及研究口径或文件边界的改动必须同步 ADR。

## 提交检查

1. 核心计数和图表能由脚本重建。
2. 报告引用输出文件存在。
3. Shiny 使用预计算结果。
4. 无 API key、邮箱或个人缓存路径。
5. 论文、机构与资助解释符合边界。
6. 有效 Markdown 链接可解析。
7. 小型冻结输出与应用构建结果可追溯。
