# R 分析管道

脚本从项目根目录运行，按编号执行。当前已完成 P0 的全部管道、
P1 的机构层级与对照匹配阶段、M6 首轮平衡审计、作者网络基线和
2023 本地事件拆解。
其余编号文件在对应阶段创建。

```text
00_setup.R             环境、路径与依赖
01_ingest_rwdb.R       原始数据读取与记录级审计
02_build_doi_panel.R   DOI 级论文表
03_map_reasons.R       原因族多标签映射
04_screen_china.R      中国大陆候选池
05_fetch_openalex.R    OpenAlex 抓取与缓存
06_build_authorships.R 作者、机构、国家长表
06a-06f                P1 机构抓取、层级、地区和论文富化
07a-07g                P1 对照分层、候选池、匹配和对照解析
08_match_balance_audit.R 对照缺口、匹配平衡和团队规模审计
09_build_networks.R    作者网络与重复合作基线
10_descriptive.R       描述性统计
11_paper_models.R      论文层模型
12_network_analysis.R  零模型与社群检验
13_event_2023.R        2023 事件专项
14_funding_audit.R     第二阶段资助审计
15_exports.R           报告与 Shiny 输出
16_run_all.R           全流程入口
90_baseline_eda.R      已完成的基础 EDA
```

当前 `09_build_networks.R` 已生成网络边和描述性结构，尚未实现置换零模型；
`13_event_2023.R` 已完成本地构成，尚未接入 Crossref 分母和外部证据。

## P0 运行入口

```powershell
# 从原始 CSV 重建 DOI 面板和中国大陆候选池
powershell -ExecutionPolicy Bypass -File scripts/run_p0_panel.ps1

# 只检查 OpenAlex 请求计划
powershell -ExecutionPolicy Bypass -File scripts/run_openalex_fetch.ps1 -DryRun

# 设置 OPENALEX_API_KEY 后全量抓取
powershell -ExecutionPolicy Bypass -File scripts/run_openalex_fetch.ps1

# 抓取完成后解析作品、作者和机构长表
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_p0_openalex_parse.R -IncludeOutputs -IncludeCache
```

`run_openalex_fetch.ps1` 支持 `-Limit N`、`-DryRun` 和 `-Refresh`。
正式全量抓取默认每批 100 个 DOI。

## P1 运行入口

```powershell
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
# 完整字段解析后再次校验年份与类型
powershell -ExecutionPolicy Bypass -File scripts/run_in_ascii_stage.ps1 `
  -RScript scripts/run_control_fallback.R -IncludeOutputs
```

共享函数放在 `lib/`。脚本不得在输出中写入 API key、邮箱或未脱敏缓存路径。

输出遵循 [仓库文件与制品契约](../docs/decisions/0002-repository-file-contract.md)：

- `data/external/` 只读第三方来源。
- `data/reference/` 只读人工冻结映射。
- 原因分析读取 v2 注册表、领域长表、上下文长表和分析族预设。
- 原始标签若未出现在注册表中，管道立即停止，不静默归入 `unclassified`。
- 阶段结果写入 `data/outputs/{audits,baseline,final,app}/`。
- 大型中间对象写入 `data/interim/` 或 `data/processed/`，不提交 Git。
