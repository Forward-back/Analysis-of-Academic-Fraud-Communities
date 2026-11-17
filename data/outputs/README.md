# 分析输出

本目录按分析阶段组织，并在每个阶段内部按制品类型组织。

| 阶段目录 | 内容 | 内部结构 |
|---|---|---|
| `audits/` | 覆盖、匹配和接口压测 | `tables/`、`figures/` |
| `baseline/` | 基础 EDA | `tables/`、`figures/`、`manifest.json` |
| `final/` | 主模型、网络、事件和资助结果 | `tables/`、`figures/`、`models/`、`manifest.json` |
| `app/` | Shiny 预计算数据 | `tables/`、`manifest.json` |

报告和 Shiny 不直接读取原始 CSV。
小型审计、表、图和模型摘要提交到 Git；大型 RDS 与临时文件不提交。
每个冻结阶段必须有 manifest，manifest 只使用项目相对路径。

应用构建命令：

```powershell
Rscript scripts/build_deliverables.R
```

该命令将 `outputs/app/` 同步到可独立部署的 `app/data/`，并将最终报告图同步到
`reports/assets/figures/`。
