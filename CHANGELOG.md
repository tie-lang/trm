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
- 记录 tiec 后端坑：链式/嵌套表元素复绑定易崩溃或挂起，S4 起统一用扁平 `table<i64>` 规避；S5b 又见库 TU 内 `break` 解析怪癖，改无换行输出 + 免 break 解析规避。
