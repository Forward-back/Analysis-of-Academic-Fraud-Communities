# 复现说明

> 状态：仓库契约、P0 管道和 P1 主对照管道已建立，M6 对照片本富化进行中

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
- P0 正式抓取：`data/cache/openalex/p0/works-batches/`
- P0 批次元数据：`data/cache/openalex/p0/works-batches/metadata/`

正式抓取遵循相同模式，缓存原始 JSON，并记录请求清单、失败和重试日志。

## P0 重建顺序

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_p0_panel.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_openalex_fetch.ps1 -DryRun
$env:OPENALEX_API_KEY = "..."
powershell -ExecutionPolicy Bypass -File scripts/run_openalex_fetch.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_p0_openalex_parse.R -IncludeOutputs -IncludeCache
```

P0 缓存元数据不保存 API key。失败批次保留 HTTP 状态和截断错误信息，
下一次运行默认跳过有效缓存，`-Refresh` 强制重取。

当前 P0 全量抓取已冻结：266 批，候选 DOI 26,526，单一精确匹配 26,497。
重新执行时脚本会比较缓存元数据中的 DOI 集合；短样本批次不会冒充全量批次。

## P1 机构与对照

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_openalex_institutions.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_openalex_institution_parse.R -IncludeOutputs -IncludeCache
powershell -ExecutionPolicy Bypass -File scripts/run_institution_tier_sources.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_institution_tier_candidates.R -IncludeOutputs
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_institution_tier_registry.R -IncludeOutputs
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_institution_enrichment.R -IncludeOutputs

powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_control_plan.R -IncludeOutputs
powershell -ExecutionPolicy Bypass -File scripts/run_control_pool_fetch.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_control_pool_parse.R -IncludeOutputs -IncludeCache
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_control_match.R -IncludeOutputs
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_control_fallback.R -IncludeOutputs
powershell -ExecutionPolicy Bypass -File scripts/run_selected_control_fetch.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_selected_control_parse.R -IncludeOutputs -IncludeCache
# 完整字段解析后再次校验年份与类型，排除抓取后漂移的对照
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_control_fallback.R -IncludeOutputs
```

`run_control_pool_fetch.ps1` 的请求同时设置 `sample` 和 `per_page`；
只设置 `sample` 会被 OpenAlex 按默认 25 条截断。

## 分析样本冻结

对照匹配和匹配平衡审计完成后执行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_analysis_sample_freeze.R -IncludeOutputs
```

该入口生成逐论文冻结标记、样本登记表、对照机构字段缺口分解和网络纳入排除比较。
详细口径见 [分析样本冻结与选择审计](../analysis/analysis-samples.md)。

论文层原因族描述：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_paper_descriptives.R -IncludeOutputs
```

该入口构建案例与对照论文面板，并输出团队规模、机构层级、合作地理和匹配层构成。

论文层调整模型：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_paper_models.R -IncludeOutputs
```

该入口执行主混合 logistic、条件 logistic、正距离量级、聚类稳健负二项和
剔除 2023 敏感性模型。

论文层稳健性：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_paper_model_robustness.R -IncludeOutputs
```

该入口执行作者去重叠、主机构、固定 985/211、前五批次剔除和团队规模分层模型。

网络原因族比较与审计簇画像：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_network_conditioned_profiles.R -IncludeOutputs
```

该入口复用 1,000 次网络零模型，生成原因族标准化超额和 25 个审计簇画像。

2023 外部治理证据：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_event_2023_external_evidence.R -IncludeOutputs
```

该入口验证来源和声明登记，生成外部时间线、机制映射、反事实边界和快照 manifest。

## 数据冻结

- 原始 CSV 只读。
- 下载日期和观察日期分开记录。
- 文件哈希写入 manifest。
- CSV、JSON、Markdown 等文本文件先将 CRLF 和单独 CR 规范为 LF 再计算哈希；
  原始 CSV、二进制文件和 API 响应保留逐字节哈希。
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
