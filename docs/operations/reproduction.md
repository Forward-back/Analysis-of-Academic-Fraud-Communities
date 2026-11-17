# 复现说明

> 状态：目录已重构，正式管道待实现

## 环境

- R 4.6.1 或项目锁文件记录的版本。
- `renv` 恢复包环境。
- Windows PowerShell 或兼容命令行。
- OpenAlex key 通过 `OPENALEX_API_KEY` 环境变量提供。

## 首次运行

```powershell
Rscript scripts/check_environment.R
powershell -ExecutionPolicy Bypass -File scripts/run_initial_eda.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

本项目当前位于中文 Windows 路径下，`readr` 与图形设备可能无法直接写入。正式入口
`scripts/run_in_ascii_stage.ps1` 会把最小项目复制到 ASCII 暂存目录，运行成功后将
`data/outputs/` 等生成结果同步回项目。直接运行 R 脚本只建议用于不写文件的检查。

`renv.lock` 记录当前直接依赖。由于 `renv` 在中文项目路径下创建项目库存在编码限制，
完整恢复应在 ASCII 路径或 ASCII 暂存环境中执行；当前机器上的正式运行入口使用已安装
的系统包，并在每次新增核心依赖后更新锁文件。

## 基础 EDA 输出

- 表格：`data/outputs/baseline/`
- 图：`data/outputs/baseline/figures/`
- 原因字典：`data/external/mappings/reason_dictionary_v1.csv`

## API 缓存

- OpenAlex 500 DOI 压测：`data/cache/openalex/pressure-tests/works-500/`
- 对照抽样压测：`data/cache/openalex/pressure-tests/controls-25/`

正式抓取遵循相同模式，缓存原始 JSON，并记录请求清单、失败和重试日志。

## 数据冻结

- 原始 CSV 只读。
- 下载日期和观察日期分开记录。
- 文件哈希写入 manifest。
- 派生数据可删除重建。

## 提交检查

1. 核心计数和图表能由脚本重建。
2. 报告引用输出文件存在。
3. Shiny 使用预计算结果。
4. 无 API key、邮箱或个人缓存路径。
5. 论文、机构与资助解释符合边界。
