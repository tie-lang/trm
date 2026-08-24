# 变更记录

本仓库记录 trm 运行时的版本变更。

## 未发布

### v0.1.0（S1–S5）

- 库层基础域（S1）：`trm.fs / trm.process / trm.env / trm.clock / trm.terminal`。
- 库层补充域（S2）：`trm.session / trm.data / trm.net`（ui 需平台桥，另行规划）。
- 引擎 frontend（S3）：`trm_loader`（tieir 反序列化+校验）+ `trm_interp`（最小字节码 VM）。
- 引擎 gc（S4）：`trm_gc` mark-sweep 托管堆探针（精确根 + 扁平边表）。
- 引擎 mnn（S4）：`trm_mnn` M:N 协程调度器探针（固定 worker 池多路复用）。
- 引擎 backend（S5）：`trm_tiejit` 简易执行器 + `trm_backend` 统一契约矩阵
  （interp/tiejit 同契一致；orcjit 占位待实现）。
- 引擎 orcjit（S5b）：独立 LLVM-MCJIT 驱动进程接入 `trm_orcjit`，契约矩阵**三后端
  （interp/tiejit/orcjit）同契全 PASS、无 SKIP**。
- 引擎 objmodel（S6）：`trm_objmodel` 对象模型/反射底座（类型注册表 + 运行时类型查询 +
  签名序列化/反序列化 + 跨域身份 interning + gc 对象类型标）；loader 增参数类型访问器。
- 引擎 diag（S7）：`trm_diag` 运行时内省诊断探针（统一诊断快照 + 内省自检），P4 诊断/内省落地。
- 引擎 module（S8）：`trm_module` 动态加载 + 模块生命周期（load/内省/invoke/unload），
  P4 动态加载落地；新增 calc2 模块资产（`double`）。
- 引擎 aot（S9）：`trm_aot` AOT 前端（tieir→LLVM IR 降级 + llc/clang 原生编译执行），
  P5 AOT 可选后端落地。
- 平台桥（S10）：`impl/impl-win32` 一期——`trm_platform` `is_tty / raw_mode`（unsafe extern
  桥 Win32 控制台），编译为 `trm_platform.dll`（M5 动态库，C LoadLibrary 可消费）；`regress-platform.ps1`
  4 项全绿（.dll 编译 / 导出面 / C 冒烟 / tie 回归）。前置：tie-main extern 扩展 ptr/slice +
  动态库边界放行 slice/repr(C) pod struct、extern 无函数体越界读修复（三笔提交）。
- 库里层接线：`lib/terminal` 增 `trm_terminal.is_tty`（转调 `trm_platform`），随 main 汇总
  传递导入接入（此前 tiec 深层/多导入对 extern 的越界读假报已修复，见 tie-main）。
- 进程管道（S10b，preview.5）：`trm_platform.capture(cmd)`——`_popen(cmd,"r")` 建管道逐字节
  读子进程 stdout 到 EOF（libc，无结构体 ABI），`trm_process.capture` 接线；`regress-platform.ps1`
  增至 5 项全绿（新增步骤5：capture('cmd /c echo hello') 读到 hello）。
- 记录 tiec 后端坑：repr(C) 窄字段（u32/i16）struct 的 store codegen 值未收窄到 i32
  （`store i32` 但值仍 i64）——CreatePipe/CreateProcessW 的结构化管道（STARTUPINFOW/
  PROCESS_INFORMATION 经指针传递）据此延后，待后端修复后接入。
- 记录 tiec 后端坑：链式/嵌套表元素复绑定易崩溃或挂起，S4 起统一用扁平 `table<i64>` 规避；S5b 又见库 TU 内 `break` 解析怪癖，改无换行输出 + 免 break 解析规避。
