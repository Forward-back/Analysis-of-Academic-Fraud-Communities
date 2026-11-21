# 运行入口

| 文件 | 用途 |
|---|---|
| `check_environment.R` | 检查 R 与核心包 |
| `run_initial_eda.R` | 从命令行重跑基础 EDA |
| `run_initial_eda.ps1` | Windows PowerShell 入口 |
| `run_in_ascii_stage.ps1` | 在 ASCII 临时目录运行 R 并同步输出 |
| `run_tests.R` | 执行 `testthat` 项目回归测试 |
| `run_tests.ps1` | Windows PowerShell 测试入口 |
| `run_unit_tests.R` | 只执行不需要原始数据的仓库契约测试 |
| `run_integration_tests.R` | 执行需要本地原始数据的集成测试 |
| `run_unit_tests.ps1` | Windows 单元测试入口，使用 ASCII 暂存目录 |
| `run_integration_tests.ps1` | Windows 集成测试入口，使用 ASCII 暂存目录 |
| `run_match_balance_audit.R` | 对照缺口、匹配平衡和团队规模审计 |
| `run_analysis_sample_freeze.R` | 冻结论文、机构和网络分析样本并审计选择差异 |
| `run_paper_descriptives.R` | 构建论文层案例对照面板与原因族结构描述 |
| `run_network_baseline.R` | 作者网络与重复合作基线 |
| `run_network_null_model.R` | 团队构成置换零模型 |
| `run_leiden_communities.R` | Leiden 多分辨率与稳定性敏感性 |
| `run_audit_clusters.R` | 固定 25 个重复合作审计簇 |
| `run_degree_preserving_null.R` | 作者度保持零模型敏感性 |
| `run_crossref_denominators.R` | 2023 高频期刊 Crossref 年度分母 |
| `run_event_2023.R` | 2023 本地事件构成拆解 |
| `audit_reason_mapping.R` | 只读检查 112 标签覆盖、领域重叠和分析族计数 |
| `build_deliverables.R` | 从冻结输出构建应用数据和报告图 |
| `build_deliverables.ps1` | Windows PowerShell 交付物构建入口 |

所有命令从项目根目录执行。正式管道完成后增加 `run_all.ps1`。
