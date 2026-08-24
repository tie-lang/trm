# impl/impl-win32/ —— trm 平台实现层（Win32）

对应设计 [trm-final-design.md](https://github.com/tie-lang/tie/blob/main/docs/designs/trm-final-design.md) §6：
平台实现层**全 tie 写**，用 `unsafe extern` + 标量/指针桥原生 Win32/libc API，保持 0-Rust 自举灵魂。

## 能力（命名空间 trm_platform）

| 函数 | 说明 | 底层 |
| --- | --- | --- |
| `is_tty() -> bool` | 输出句柄是否接真实控制台（重定向/管道 → false） | GetStdHandle + GetConsoleMode |
| `raw_mode(on: bool) -> bool` | 输入原始模式开/关（清 ECHO+行缓冲）；需真实控制台 | Get/SetConsoleMode |
| `capture(cmd) -> string` | 进程管道捕获：`_popen(cmd,"r")` 建管道逐字节读 stdout 到 EOF（ASCII 精确） | libc _popen/fgetc/_pclose |
| `write_cmd(cmd, data) -> i64` | 写方向：`_popen(cmd,"w")` 写 data 到子进程 stdin | libc _popen/fwrite/_pclose |

- 交付形态：`tiec platform_win32.tie --shared` → `trm_platform.dll`（M5 动态库，C/外部宿主
  `LoadLibrary`）；tie 侧经该源码直接消费（非交互下优雅降级）。
- ABI：全部标量/指针/string 形参；`_popen` 返回的 `FILE*` 即 i64 句柄，无结构体 ABI。

## 构建与回归

```powershell
pwsh impl/impl-win32/regress-platform.ps1   # 5 项：.dll 编译 / 导出面 / C 冒烟 / 终端回归 / 管道捕获
```

- tie 侧回归驱动：`tests/s10_platform/platform_demo.tie`（is_tty/raw_mode 重定向降级）；
  `tests/s10_platform/pipe_demo.tie`（`capture('cmd /c echo hello')` 读到 hello）。
- 库里层接线：`lib/terminal.is_tty`、`lib/process.capture` 经传递导入接入 `trm_platform`，
  随 `main.tie` 汇总回归（所需的 tiec 深层多导入修复已并入 tie-main）。

## 已知限制与后续

- **CreatePipe/CreateProcessW 结构化管道暂缓**：其 STARTUPINFOW/SECURITY_ATTRIBUTES/
  PROCESS_INFORMATION 需 repr(C) 窄字段（u32/i16）struct 经指针精确传递，而当前 tiec 对窄字段
  struct 的 store 存在 codegen 缺陷（`store i32` 但值仍 i64）。已用 `_popen` 达成进程管道捕获；
  待后端修复后接入结构化进程（双向管道/进程信息/退出码）。
- 键读取（`ReadConsoleInputW` + INPUT_RECORD 解析）、光标/ANSI、窗口/UI（trm.ui，P5）。