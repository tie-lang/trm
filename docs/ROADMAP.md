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
| S5 | backend：orcjit（LLVM）+ tiejit（简易执行器） | 统一契约矩阵 |

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

## 4. 决策记录

| 决策点 | 结论 | 备选 |
| --- | --- | --- |
| 起步顺序 | 库层优先（先基础功能） | 引擎 P0 先行 |
| 标准库复用 | vendoring（stdlib/ 内置子集） | 引用 tie-main / 零依赖自实现 |
| S1 范围 | 核心系统域 5 模块 | 更多/更少 |