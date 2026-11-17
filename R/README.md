# R 分析管道

脚本从项目根目录运行，按编号执行。当前已完成 `90_baseline_eda.R`；其余编号文件在对应阶段创建。

```text
00_setup.R             环境、路径与依赖
01_ingest_rwdb.R       原始数据读取与记录级审计
02_build_doi_panel.R   DOI 级论文表
03_map_reasons.R       原因族多标签映射
04_screen_china.R      中国大陆候选池
05_fetch_openalex.R    OpenAlex 抓取与缓存
06_build_authorships.R 作者、机构、国家长表
07_match_controls.R    非撤稿对照匹配
08_enrich_institutions.R 机构层级、省市与距离
09_build_networks.R    作者网络与社群
10_descriptive.R       描述性统计
11_paper_models.R      论文层模型
12_network_analysis.R  零模型与社群检验
13_event_2023.R        2023 事件专项
14_funding_audit.R     第二阶段资助审计
15_exports.R           报告与 Shiny 输出
16_run_all.R           全流程入口
90_baseline_eda.R      已完成的基础 EDA
```

共享函数放在 `lib/`。脚本不得在输出中写入 API key、邮箱或未脱敏缓存路径。

输出遵循 [仓库文件与制品契约](../docs/decisions/0002-repository-file-contract.md)：

- `data/external/` 只读第三方来源。
- `data/reference/` 只读人工冻结映射。
- 原因分析读取 v2 注册表、领域长表、上下文长表和分析族预设。
- 原始标签若未出现在注册表中，管道立即停止，不静默归入 `unclassified`。
- 阶段结果写入 `data/outputs/{audits,baseline,final,app}/`。
- 大型中间对象写入 `data/interim/` 或 `data/processed/`，不提交 Git。
