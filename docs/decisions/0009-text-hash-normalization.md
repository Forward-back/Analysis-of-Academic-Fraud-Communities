# 0009：文本内容哈希统一按 LF 计算

- 状态：已接受
- 日期：2026-11-19
- 决策范围：manifest、参考映射 provenance 和跨平台回归测试

## 背景

Git 将 CSV、JSON 和 Markdown 统一检出为 LF，但历史 manifest 和 provenance
记录了 Windows 工作区产生的 CRLF 字节哈希。相同内容因此在不同检出环境得到不同
SHA-256，导致单元测试和冻结制品不可复现。

## 决策

- 文本扩展名的 SHA-256 在计算前将 CRLF 和单独 CR 规范为 LF。
- 原始 CSV、二进制文件和 API 响应仍按原始字节计算 SHA-256。
- manifest、参考映射 provenance 和对应测试共用
  `R/lib/file_hash.R::sha256_canonical_file()`。
- 哈希值表示规范化后的文本内容，不表示检出工作区的行尾字节。

## 后果

- Windows、Linux 和 Git checkout 得到相同文本内容哈希。
- 行尾变化不再破坏冻结校验，但实际文本内容变化仍会改变哈希。
- 原始文件和二进制文件继续保留逐字节校验。
