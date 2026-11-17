# Shiny 应用

应用读取 `data/outputs/app/` 的预计算结果，不在页面启动时重算全量网络或模型。

计划四页：

1. 数据覆盖。
2. 原因族与资源结构。
3. 网络与待核查社群。
4. 2023 事件、资助审计与方法。

代码采用 `app.R` 加 `R/` 模块结构。详细交互与验收标准见
[Shiny 规格](../docs/specs/shiny-spec.md)。

本地运行时优先读取 `data/outputs/app/`。独立部署前运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/build_deliverables.ps1
```

构建脚本把应用数据同步到 `app/data/`，该目录不作为权威数据源，也不进入 Git。
