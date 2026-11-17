# 测试目录

测试分为两层：

- `test-unit-*.R`：不需要原始数据，验证目录契约、冻结映射、哈希、manifest 和链接。
- `test-integration-*.R`：需要本地 `data/raw/retractions.csv`，验证原始哈希和核心计数；
  缺少原始数据时自动跳过。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_unit_tests.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_integration_tests.ps1
powershell -ExecutionPolicy Bypass -File scripts/run_tests.ps1
```

后续测试重点包括 DOI 规范化、日期解析、原因族多标签映射、中国大陆确认、
机构完整子集、匹配比例、固定种子、层内去重和应用数据字段契约。
