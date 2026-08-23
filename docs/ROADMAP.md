# trm 实施路线图（库层优先版）

> 状态：**已定稿**（2026-08-23，取消设计定稿 §10 的「引擎 P0-P5 先行」顺序，改为库层优先）
> 定位：tie 平台运行时套件。架构分层与依赖方向见 `trm-final-design.md`（随 tie 主仓维护）。

## 1. 方向变更

原定稿 §10 从引擎 P0（tieir 加载 + interp）起步。**新方案改为库层（lib/）优先**：
第一步直接实现基础功能（库层核心系统域），做完再加。引擎/gc/后端（路线 B 内核）延后。

理由：库层全 tie 写、零引擎依赖、可直接交付可用的基础能力；引擎工作量大、收益前置性低。

## 2. 实施步骤

| 步骤 | 内容 | 里程碑 |
| --- | --- | --- |
| **S1（完成）** | 库层核心系统域：`fs / process / env / clock / terminal` | 编译零错误 + 回归通过 |
| **S2（完成）** | 库层补充域：`session / data / net`（ui 需平台桥，延后） | 三模块编译零错误 + 回归通过 |
| **S3（完成）** | 引擎 frontend：`loader`（tieir 反序列化+校验）+ `interp`（最小字节码 VM） | P0 验收：加载+interp 跑通 add/sub/mul 纯函数 |
| **S4（完成）** | 引擎 gc / mnn（objmodel 属 P4，保持占位） | GC 探针 + 协程：gc_test / mnn_test 验收通过 |
| **S5（完成）** | backend：tiejit（简易执行器）+ orcjit（独立 LLVM-MCJIT 驱动进程）+ registry（契约矩阵） | 统一契约矩阵：interp/tiejit/orcjit 三端同契一致性验收通过 |
| **S6（完成）** | 引擎 objmodel（对象模型/反射底座） | 运行时类型查询 + 自动序列化 + 跨域身份，tests/s6obj 验收 |
| **S7（完成）** | 运行时内省诊断（diag） | 统一诊断快照 + 内省自检，tests/s7diag 验收 |
| **S8（完成）** | 动态加载 + 模块生命周期（module 注册表） | load/内省/invoke/unload 生命周期，tests/s8mod 验收 |
| **S9（完成）** | AOT 前端（tieir → LLVM IR → 原生编译执行） | llc/clang 原生执行与 interp 契约一致，tests/s9aot 验收 |

## 3. S1 具体方案

- 标准库复用：**vendoring（选 A）**。在 `stdlib/` 内置 `std/fs|process|time|path` 子集，
  `import "../../stdlib/fs.tie"`，仓库自包含可独立构建。
- `lib/` 5 模块，`type tie<class>`，命名空间 `trm.{name}`，包装 std 实现。
- 模块清单：

| 模块 | 命名空间 | 内容 |
| --- | --- | --- |
| lib/fs.tie | trm.fs | 文件/目录（读/写/列/存在/删除/大小） |
| lib/process.tie | trm.process | 执行命令 / 捕获输出 / 退出码 |
| lib/env.tie | trm.env | 环境变量 / 平台信息 |
| lib/clock.tie | trm.clock | 时间戳 / 延时 |
| lib/terminal.tie | trm.terminal | 终端输出 / ANSI 基础阶面 |

### 3.1 版本号设计（定稿）

- **每个模块独立版本号**：各 `lib/x.tie` 顶层 `const TRM_<模块>_VERSION`，暴露
  `module_version() -> string` 查询。
- **trm 整体发行版本号**：由 `main.tie` 持有 `const TRM_VERSION`（发行版主/次/补丁）。
- 模块名与常量：fs→TRM_FS_VERSION，process→TRM_PROCESS_VERSION，env→TRM_ENV_VERSION，
  clock→TRM_CLOCK_VERSION，terminal→TRM_TERMINAL_VERSION，session→TRM_SESSION_VERSION，
  data→TRM_DATA_VERSION，net→TRM_NET_VERSION（避免全局常量跨模块重名）。

### 3.2 构建依赖

- 库层包装 vendored std/fs|process 的桥内置（file_read/file_write 等）需 tie-interp 静态库。
- 编译需设 `TIE_INTERP_LIB` 指向 tie-interp 库，或在 CWD 下存在 `target\release\tie_interp.lib`。

### 3.3 S3 引擎加载执行（完成）

- `core/frontend/loader.tie`：tieir（段 1-7）反序列化 + 校验（魔数/版本/段号/计数/偏移/段界/尾量），
  反序列化重建参数/结果值 id（函数先建领参数值、指令后建领结果值，单调递增）。
- `core/frontend/interp.tie`：最小字节码 VM，支持算术/位/移位/const_i/ret/br/cond_br/icmp/select。
- 验收：`tests/s3pure` 加载 .tieir 后 interp 跑通 `add/sub/mul` 纯函数（结果 PASS）。
- **已知编译器约束**：此 tiec 构建的 `byte_read`/`byte_write` 内置在特定程序形态下崩溃
  （`tiec --tieir-out` 亦崩），故 .tieir 经逗号分隔字节文本中转（gen2 → loader），
  不使用 byte 内置；待 tiec 修复后改回二进制直读。

- 验收：各库文件 `tiec` 编译零错误；`main.tie` 调用各模块并输出预期结果。

### 3.4 S4 引擎 gc/mnn（完成）

- `core/gc/gc.tie`：统一 GC 探针（命名空间 `trm_gc`）。扁平行号表对象 + 扁平边表
  `from/to/alive`，精确根集合 + mark-sweep。`drop_edge` 撤边 / `drop_root` 撤根构造不可达，
  二次 `gc()` 验证只回收不可达对象（`tests/s4gc` 10 断言全过）。
- `core/mnn/mnn.tie`：M:N 协程调度器探针（命名空间 `trm_mnn`）。固定 worker 池 M，
  就绪队列多路复用 N 个协程，`tick` 至多推进 M 个、`run_all` 排空（`tests/s4mnn` 6 断言全过，
  峰值并发 ≤ M 即 M:N 上界）。
- `core/objmodel` 属 P4（反射/序列化底座），本里程碑保持占位。

- **新增 tiec 后端坑（同 §3.3 类）**：链式边表（`g_head[o]→g_edge_next[node]`）的
  索引写读在该 tiec 构建下会**无限挂起**（运行时崩溃/死循环）；改为扁平边表 + `table_push`
  追加 + 全扫索引读即稳定。故 gc/mnn 只用 `table<i64>` 与标量，不做嵌套表元素复绑定 /
  链式指针。

### 3.5 S5 后端契约矩阵（完成）

- `core/backend/tiejit/simple.tie`：tiejit 简易执行器（命名空间 `trm_tiejit`）。与 interp
  同一 .tieir、用**紧凑寄存器式**执行器（独立实现）计算纯函数。
- `core/backend/registry.tie`：后端注册表 + **统一契约矩阵**（命名空间 `trm_backend`）。
  登记 `interp / tiejit / orcjit`，同一组用例逐个后端执行比对，落成 用例×后端 矩阵。
- 验收（`tests/s5jit`）：add/sub/mul 3 用例 × 3 后端，interp 与 tiejit 全 PASS（两实现
  同契一致），orcjit（LLVM）标记未实现 SKIP；19 断言全过。
- **orcjit 接入（S5b）**：新增独立 LLVM-MCJIT 驱动进程（`orcjit.c` + `build-orcjit.ps1`，
  用 D:\LLVM 的 LLVM-C 现场构造 i64 二元函数模块并真 JIT），tie 侧 `trm_orcjit`（`jit.tie`）
  读 tieir op → 调驱动 → 解析输出。契约矩阵升级为**三端全 PASS、无 SKIP**（18 断言全过）。
- orcjit 用进程边界桥（tiec 无附加链接库/原始函数指针，进程内桥 LLVM 风险过高）；
  完整 tieir→LLVM IR 降级与进程内 JITLink 留待 P3。

### 3.6 S6 对象模型/反射底座（完成）

- `core/objmodel/objmodel.tie`（`trm_objmodel`）：类型注册表（name↔omTyId）+ ir→om 桥接；
  对已加载 tieir 的运行时类型查询（函数签名/参数/返回）；签名的可逆序列化/反序列化
  （`name:<t0>:<t1>:<ret>`）；跨域身份（签名 interning + gc 对象类型标）。
- `core/frontend/loader.tie` 增 `func_param_type` 访问器，支撑类型反射。
- 验收（`tests/s6obj`）：反射 add/sub/mul、round-trip、interning 稳定、gc 类型标，32 断言全过。

### 3.7 S7 运行时内省诊断（完成）

- `core/objmodel/diag.tie`（`trm_diag`）：统一诊断快照，汇总 loader（pkg/计数）、gc、
  mnn、objmodel、backend 契约矩阵（matrix_ok）与各模块版本；`selfcheck()` 对已加载函数
  逐一反射签名并 round-trip 校验（内省自洽）。
- `core/objmodel/objmodel.tie` 增 `module_version`（版本约定一致）。
- 验收（`tests/s7diag`）：诊断项 + gc 对象 + 版本 + selfcheck=0，15 断言全过。
  P4「诊断 + 类型内省」落地。

### 3.8 S8 动态加载 + 模块生命周期（完成）

- `core/objmodel/module.tie`（`trm_module`）：模块注册表 + 生命周期。`load(path,alias)`
  动态加载 .tieir 并登记（内省签名）；`module_func_*` 多模块内省；`activate`/`invoke`
  按名动态调用（interp）；`unload` 卸载禁用、`activate` 复活。
- `tests/s8mod/gen3.tie` 生成新资产 `calc2.tieir`（`double(n)=n*2`，const_i+mul）。
- 验收（`tests/s8mod`）：加载两模块、内省、动态调用、卸载/复活，19 断言全过。
  P4「动态加载 tieir」落地。

### 3.9 S9 AOT 前端（完成）

- `core/aot/aot.tie`（`trm_aot`）：tieir → LLVM IR 降级（`lift_ir`）+ llc 校验（`verify_ir`）
  + 端到端原生编译执行（`aot_execute`：降级→llc -filetype=obj→clang 链接→运行→回灌）。
- 依赖 D:\LLVM（llc/clang），经 `process`/`fs` 桥；产物写 `%TEMP%\trm-aot`（不入库）。
- 验收（`tests/s9aot`）：add/sub/mul 各 5 断言全过（AOT 执行==期望，且 AOT 结果== interp，
  与 orcjit JIT 同为「interp 基准 + 契约一致」）。完整 IR 降级留待 P3 深化。

## 4. 决策记录

| 决策点 | 结论 | 备选 |
| --- | --- | --- |
| 起步顺序 | 库层优先（先基础功能） | 引擎 P0 先行 |
| 标准库复用 | vendoring（stdlib/ 内置子集） | 引用 tie-main / 零依赖自实现 |
| S1 范围 | 核心系统域 5 模块 | 更多/更少 |