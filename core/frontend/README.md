# core/frontend/ — 前端（interp 解释执行）

对应设计 §3.1 的最前线：**前端 = interp（跨端一致解释执行）**，是路线 B 的语义基准。

- `InterpBackend` 实现 `port/backend.tie` 的 Backend 接口（前端即后端）。
- 跨平台一致性以 interp 为基准：语义契约 + 测试矩阵在此定基线，JIT 须通过同一契约测试。
- 分支策略：Vanilla 场景 interp 直跑；热点函数提升到 orcjit JIT 后端（对标 HotSpot tiered）。

当前为空的接口挂载点，P0 起填充。