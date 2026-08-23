# core/backend/orcjit/ — LLVM JIT 后端

默认热点后端。对 `port/backend.tie` 的 Backend 接口提供 **LLVM JIT** 实现，逐函数提升热点
（对标 HotSpot tiered）。以 interp 为语义基准 + 契约矩阵，JIT 通过与 interp 同一契约测试。

## 现状（已接入）

- `orcjit.c` + `build-orcjit.ps1`：独立 **LLVM MCJIT 驱动进程**（D:\LLVM 的 LLVM-C）。
  对 `op a b` 用 IRBuilder 现场构造 `i64 cf(i64,i64)` 模块，经 `LLVMCreateExecutionEngineForModule`
  **真 JIT 编译并调用**，结果十进制打印（无换行）。这证明 LLVM JIT 执行路径真实可用。
- `jit.tie`（`trm_orcjit`）：tie 侧后端。读 tieir 纯函数算术 op → 调驱动进程 → 捕获 stdout → 解析，
  作为契约矩阵第三个实端。`tests/s5jit` 三后端（interp／tiejit／orcjit）同一契约全 PASS。

> 为何用独立进程桥：tiec 的 extern 仅解析 libc 这类自动链接符号、无附加链接库机制，
> 且 tie 无原始函数指针调用，进程内桥接 LLVM 在当前 toolchain 下风险过高；独立 JIT 进程 +
> 进程边界调用契合「可替换后端 / 其他语言实现」的契约框架。

## 构建

```powershell
powershell -File core/backend/orcjit/build-orcjit.ps1   # 产 orcjit.exe + LLVM-C.dll
```

- 依赖 D:\LLVM（LLVM-C.dll/.lib + include/llvm-c）；随包分发时改任一 `TIE_LLVM_HOME` 即可。
- **产物为本地构建件（.exe/.dll 不入库）**；无 LLVM 环境矩阵对该端降级（SKIP 或置不可用）。

## 后续（P3）

- 完整 tieir → LLVM IR 降级（现仅覆盖单块 2 参算术纯函数）。
- 栈图 → 精确根扫描 → GC 协同；进程内桥（MCAnalysis/JITLink）替代进程边界。