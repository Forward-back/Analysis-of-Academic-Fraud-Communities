# 审计输出

保存 OpenAlex 匹配、字段覆盖、对照匹配、作者冲突和数据质量表。
审计结果按 `tables/` 和 `figures/` 组织；小型 JSON 与 CSV 提交到 Git，
大体积原始响应仍保留在 `data/cache/`。

`manifest.json` 记录冻结审计文件及其哈希。
