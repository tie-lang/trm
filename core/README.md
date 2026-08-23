# core/ — 引擎层

对应设计 §3。**引擎只做"怎么执行 tieir 字节码"**，对标 JVM 本体（解释器 + JIT + 类加载器 + GC），不掺业务 API。

- `frontend/` — **前端**（interp 跨端一致解释执行，语义基准；InterpBackend 即前端即后端；内置 `loader/` tieir 类加载）
- `backend/` — 可替换后端
  - `orcjit/` — **LLVM ORC JIT**（默认热点后端，逐函数提升）
  - `tiejit/` — **简易执行器**（orcjit 尚未覆盖的平台先用它顶替，其后被 orcjit 取代）
- `gc/` — 引擎级统一 GC（分代 + 移动 + 精确根扫描，独立子系统）
- `mnn/` — M:N 协程 / async 调度（可迁移栈）
- `objmodel/` — 对象模型 / 反射（运行期内省底座）

依赖方向（硬约束，§2）：`app → lib → core(interp/backend/gc) → port → 平台 → 系统 API`。core 不依赖 lib。