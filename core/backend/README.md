# core/backend/ — 可替换后端

实现 `port/backend.tie` 的 Backend 接口。引擎调度对后端透明、可热切换（前端 interp 即后端基准，热点提升到 JIT）。

- `orcjit/` — **LLVM ORC JIT**。默认热点后端（对标 HotSpot tiered），LLVM 随包分发；无 LLVM 环境退纯 interp。
- `tiejit/` — **简易执行器占位**。用其他语言写的一个简易实现，专门顶替 orcjit **尚未覆盖**的平台（如 Android / 无 LLVM 端）；待 orcjit 覆盖后淘汰。
- 跨平台一致性：以 interp 为语义基准 + 契约矩阵（§7.4），JIT 只要通过同一契约测试，不要求每端 JIT 行为一致。