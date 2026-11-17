# 交付材料

当前交付格式为 Markdown。Word 排版由用户后续处理。

| 路径 | 用途 |
|---|---|
| `final-report.md` | 综合报告源稿 |
| `presentation-outline.md` | 汇报提纲 |
| `assets/figures/` | 由构建脚本生成的报告图 |
| `templates/` | 课程模板留档 |

报告数字只从 `data/outputs/` 读取，不手工修改核心数值。
不得手工维护 `assets/figures/` 与 `data/outputs/final/figures/` 的双份图片。
发布前运行 `scripts/build_deliverables.ps1`。
