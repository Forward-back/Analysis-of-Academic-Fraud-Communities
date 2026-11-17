# 清洗中间表

本目录保存从原始数据到分析面板之间的中间结果，默认使用 RDS。

预期文件：

- `rwdb_records.rds`
- `rwdb_doi_level.rds`
- `china_candidates.rds`
- `openalex_matches.rds`

中间表可删除重建，不手工修改。
