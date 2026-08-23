# core/backend/orcjit/ — LLVM ORC JIT 后端

默认热点后端。对 `port/backend.tie` 的 Backend 接口提供 LLVM ORC-JIT 实现，逐函数提升热点（对标 HotSpot tiered）。

- 实现语言：tie（unsafe extern + repr(C) 桥 LLVM）。
- LLVM：随 trm 分发（vendored），无 LLVM 环境退纯 interp。
- 待实现（P3）：栈图 → 精确根扫描 → 契约测试与 interp 一致。

当前为空目录，P3 起填充。