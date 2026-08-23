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
| **S1（当前）** | **库层核心系统域**：`fs / process / env / clock / terminal` | 5 模块编译零错误 + main 回归跑通 |
| S2 | 库层补充域（session/data/net/ui 起步） | 各域可用 |
| S3 | 引擎 frontend（interp + loader）：tieir 加载执行 | interp 跑通纯函数 |
| S4 | 引擎 gc / mnn / objmodel | GC 探针 + 协程 |
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
  clock→TRM_CLOCK_VERSION，terminal→TRM_TERMINAL_VERSION（避免全局常量跨模块重名）。

### 3.2 构建依赖

- 库层包装 vendored std/fs|process 的桥内置（file_read/file_write 等）需 tie-interp 静态库。
- 编译需设 `TIE_INTERP_LIB` 指向 tie-interp 库，或在 CWD 下存在 `target\release\tie_interp.lib`。

- 验收：各库文件 `tiec` 编译零错误；`main.tie` 调用各模块并输出预期结果。

## 4. 决策记录

| 决策点 | 结论 | 备选 |
| --- | --- | --- |
| 起步顺序 | 库层优先（先基础功能） | 引擎 P0 先行 |
| 标准库复用 | vendoring（stdlib/ 内置子集） | 引用 tie-main / 零依赖自实现 |
| S1 范围 | 核心系统域 5 模块 | 更多/更少 |