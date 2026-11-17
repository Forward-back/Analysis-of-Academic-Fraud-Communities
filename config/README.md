# 配置目录

本目录保存可复核的项目参数，不放密钥和原始数据。

| 文件 | 用途 |
|---|---|
| `project.yml` | 路径、时间窗、样本规模、随机种子与 API 参数 |
| `analysis.yml` | 原因族、机构层级、地理、匹配规则与质量门槛 |

OpenAlex key 使用根目录 `.env` 或环境变量 `OPENALEX_API_KEY`，`.env.example` 仅提供字段模板。

参数修改后应记录在 [进度日志](../docs/progress/log.md)。影响研究设计或匹配口径的修改应新增 ADR。
