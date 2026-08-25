# impl/impl-win32/ —— trm 平台实现层（Win32）

对应设计 [trm-final-design.md](https://github.com/tie-lang/tie/blob/main/docs/designs/trm-final-design.md) §6：
平台实现层**全 tie 写**，用 `unsafe extern` + 标量/指针桥原生 Win32/libc API，保持 0-Rust 自举灵魂。

## 能力（命名空间 trm_platform）

| 函数 | 说明 | 底层 |
| --- | --- | --- |
| `is_tty() -> bool` | 输出句柄是否接真实控制台（重定向/管道 → false） | GetStdHandle + GetConsoleMode |
| `raw_mode(on: bool) -> bool` | 输入原始模式开/关（清 ECHO+行缓冲）；需真实控制台 | Get/SetConsoleMode |
| `capture(cmd) -> string` | 进程管道捕获：结构化 `CreatePipe/CreateProcessW`（repr(C)
STARTUPINFOW/PROCESS_INFORMATION 经指针传 Win32，SetHandleInformation 置写端可继承）读子进程 stdout 到 EOF | CreatePipe/CreateProcessW/ReadFile |
| `run(cmd, input) -> string` | 双向管道：写 input 到子进程 stdin（关写端 EOF）后读 stdout 到 EOF；退出码经 `last_exit()` 查询 | CreatePipe×2/CreateProcessW/WriteFile/ReadFile/GetExitCodeProcess |
| `last_exit() -> i32` | 最近一次 `run` 的子进程退出码（errno 式，0=成功） | dll 内全局 |
| `spawn_run(cmd) -> i64` | 交互式会话启动：结构化建**两条**管道后 `CreateProcessW` 启动，**保留 stdin 写端**（子进程不见 EOF）；返回会话 id（失败 -1） | CreatePipe×2/CreateProcessW |
| `run_write(sid, data) -> i32` | 写 data 到会话 stdin（不关闭写端）；返回写入字节数（失败 -1） | WriteFile |
| `run_read(sid) -> string` | 阻塞读会话 stdout 一帧（至多 4096；EOF 返回空串）——实时对话的应答读取 | ReadFile |
| `run_avail(sid) -> i64` | 非阻塞探测会话 stdout 可读字节数（-1 = 无效/断管） | PeekNamedPipe |
| `run_close_in(sid) -> i32` | 关闭会话 stdin 写端 → 子进程读到 EOF（收尾） | CloseHandle |
| `run_wait(sid) -> i32` | 等待会话退出并返回退出码；回收句柄与会话状态（幂等） | WaitForSingleObject/GetExitCodeProcess |
| `msleep(ms)` | 让出当前线程 ms 毫秒（实时轮询循环让子进程获调度时间片） | Win32 Sleep |
| `write_cmd(cmd, data) -> i64` | 写方向：`_popen(cmd,"w")` 写 data 到子进程 stdin | libc _popen/fwrite/_pclose |

- 交付形态：`tiec platform_win32.tie --shared` → `trm_platform.dll`（M5 动态库，C/外部宿主
  `LoadLibrary`）；tie 侧经该源码直接消费（非交互下优雅降级）。
- ABI：`capture`/`run`/会话系列走 repr(C) 窄字段 struct（STARTUPINFOW/PROCESS_INFORMATION）
  指针传参（tiec datalayout 对齐保证字段偏移与 C 一致）；dll 导出边界不允许指针出参，故
  退出码用 `last_exit()` 查询（errno 式）；`write_cmd` 用 `_popen` 的 `FILE*`（即 i64 句柄）。
- 交互式会话状态用扁平 `table<i64>` 并行表（sid 即下标），规避嵌套表复绑定缺陷；
  `run_wait` 幂等回收句柄与状态，无泄漏路径。

## 构建与回归

```powershell
pwsh impl/impl-win32/regress-platform.ps1   # 7 项：.dll / 导出面 / C 冒烟 / 终端 / 管道捕获 / 双向管道 / 交互式（mnn 泵）
```

- tie 侧回归驱动：`tests/s10_platform/platform_demo.tie`（is_tty/raw_mode 重定向降级）；
  `tests/s10_platform/pipe_demo.tie`（`capture('cmd /c echo hello')` 读到 hello）；
  `tests/s10_platform/run_demo.tie`（`run('cmd /c findstr .', 'hello')` → stdout=hello 且 exit=0）；
  `tests/s10_platform/interactive_demo.tie`（S10d：会话实时收发 + mnn 双会话泵，子进程
  `echo_child.exe` 每行实时回显模拟 REPL，需先在仓库根目录用 clang 编译）。
- 库里层接线：`lib/terminal.is_tty`、`lib/process.capture`/`run`/会话系经传递导入接入
  `trm_platform`，随 `main.tie` 汇总回归（所需的 tiec 深层多导入修复已并入 tie-main）。

## 已知限制与后续

- **交互式会话为调用方驱动**：`run_read` 阻塞等应答，读/写节奏由应用协议把控（典型
  REPL 对话：read 提示 → write 答 → read 应答）；子进程洪泛输出需及时 read/收尾，否则
  写满管道会阻塞子进程（管道语义本相）。
- **`write_cmd`（写子进程 stdin）仍用 `_popen("w")`**：读方向（`capture`/`run`）已走结构化
  CreateProcessW；`write_cmd` 结构化改造留待后续。
- **batch 工具（cmd/findstr/sort 等）在 stdin 为匿名管道且未 EOF 时不逐行 flush**：交互式
  实时回显需 REPL 类程序（如 `echo_child`），这是 Windows 控制台程序的平台事实，非桥缺陷。
- **该 tiec 构建下多会话交错 `run_avail`/`run_read` 会出现字节串线/丢失**（同 `byte_read`
  内置崩溃一族的 unsafe 指针流缺陷，见 ROADMAP §3.10）：泵（`pump_round`）只推进 mnn
  调度不代读管道，逐会话输出由 `read()` 直读；待 tiec 后端修复后深化为泵直读合并。
- 键读取（`ReadConsoleInputW` + INPUT_RECORD 解析）、光标/ANSI、窗口/UI（trm.ui，P5）。