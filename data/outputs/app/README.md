# 应用预计算数据

保存筛选后的摘要表、匿名网络、指标卡和下载文件。应用启动只读本目录。

内部结构：

```text
tables/        页面直接读取的聚合表
manifest.json  数据版本、字段和哈希
```

`scripts/build_deliverables.R` 会将本目录同步到 `app/data/`，使应用可独立部署。
