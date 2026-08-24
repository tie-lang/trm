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

## 已知限制（tiec 导入展开）

`platform_win32.tie` 含顶层 `unsafe extern` + `namespace`，当它被 **多个库文件浅层/深层传递导入**进
一个 logic 主文件时会触发「语句只能出现在文件顶层」的 tiec 导入展开序限制（单组导入如
`terminal+net+platform`、`fs+process+env+terminal` 均可，全量 8 库 + platform 则崩）。故平台桥
由消费方**显示 import** 单独回归，暂不并入 `main.tie` 汇总导入。此属编译器限制，待 tiec 导入
展开修复后即可并入库层。

## 二期候选

- 键读取（`ReadConsoleInputW` + INPUT_RECORD 解析）
- 进程管道（`CreatePipe`/`CreateProcessW` + STARTUPINFOW 结构 ABI，需 repr(C) 精确布局）
- 光标/ANSI（`SetConsoleCursorPosition` 或经转义序列）
- 窗口/UI（trm.ui 绘制契约，P5）