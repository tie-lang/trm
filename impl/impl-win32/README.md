# impl/impl-win32/ —— trm 平台实现层（Win32 一期）

对应设计 [trm-final-design.md](https://github.com/tie-lang/tie/blob/main/docs/designs/trm-final-design.md) §6：
平台实现层**全 tie 写**，用 `unsafe extern` + 指针/标量桥原生 Win32 控制台 API，保持 0-Rust 自举灵魂。

## 一期能力（S10）

| 函数（命名空间 trm_platform） | 说明 | Win32 |
| --- | --- | --- |
| `is_tty() -> bool` | 输出句柄是否接真实控制台（重定向/管道 → false） | GetStdHandle + GetConsoleMode |
| `raw_mode(on: bool) -> bool` | 输入原始模式开/关（清 ECHO+行缓冲，逐键读取）；需真实控制台 | Get/SetConsoleMode |

- 交付形态：`tiec platform_win32.tie --shared` → `trm_platform.dll`（M5 动态库，
  C/外部宿主可 `LoadLibrary`）；tie 侧经 `platform_win32.tie` 直接消费（非交互下优雅降级）。
- ABI：全部标量/指针形参，无 struct 按值，安全桥接。

## 构建与回归

```powershell
pwsh impl/impl-win32/regress-platform.ps1   # 4 项：.dll 编译 / 导出面 / C 冒烟 / tie 回归
```

tie 侧回归驱动：`tests/s10_platform/platform_demo.tie`（重定向下 is_tty=false、raw 优雅 false）。
库里层接线：`lib/terminal` 经传递导入接入 `trm_platform`，消费方 `trm_terminal.is_tty()`（随
`main.tie` 汇总回归；所需的 tiec 深层多导入修复已并入 tie-main）。

## 二期候选

- 键读取（`ReadConsoleInputW` + INPUT_RECORD 解析）
- 进程管道（`CreatePipe`/`CreateProcessW` + STARTUPINFOW 结构 ABI，需 repr(C) 精确布局）
- 光标/ANSI（`SetConsoleCursorPosition` 或经转义序列）
- 窗口/UI（trm.ui 绘制契约，P5）