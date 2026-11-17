# 运行入口

| 文件 | 用途 |
|---|---|
| `check_environment.R` | 检查 R 与核心包 |
| `run_initial_eda.R` | 从命令行重跑基础 EDA |
| `run_initial_eda.ps1` | Windows PowerShell 入口 |
| `run_in_ascii_stage.ps1` | 在 ASCII 临时目录运行 R 并同步输出 |
| `run_tests.R` | 执行 `testthat` 项目回归测试 |
| `run_tests.ps1` | Windows PowerShell 测试入口 |

所有命令从项目根目录执行。正式管道完成后增加 `run_all.ps1`。
