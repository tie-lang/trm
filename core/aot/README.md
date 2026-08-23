# core/aot/ — AOT 前端（tieir → 原生编译执行）

对应 P3 后置（完整 tieir→LLVM IR 降级）与 P5「wasm/AOT 可选后端」的 AOT 侧。
与 orcjit 同源：orcjit 运行时 JIT（MCJIT），aot 前置把 tieir 降级为 LLVM IR，经工具链
`llc(-filetype=obj) → clang 链接 → 原生可执行` 静态编译后执行，结果与 interp 契约一致。

- `aot.tie`（`trm_aot`）：对已加载 tieir 纯函数：
  - `lift_ir(fid)`：tieir → LLVM IR 文本降级；
  - `verify_ir(fid)`：llc 校验 IR 合法（AOT 编译前置）；
  - `aot_execute(fid, a, b)`：降级 → llc 机器码 → clang 链接 → 原生执行 → 回灌结果。
- 限制：单块、2 参、body 为单一算术（add/sub/mul/div）的纯函数；完整 IR 降级（多块/多 op/
  嵌套/const 展开）留待 P3 深化。
- 依赖：D:\LLVM（llc/clang）；LLVM_HOME 可用 `TIE_LLVM_HOME` 覆盖；产物写系统临时区 `%TEMP%\trm-aot`。

验收：`tests/s9aot` —— add/sub/mul 各 5 断言（支持/IR 非空/llc 校验/AOT 执行==期望/AOT==interp）全过。