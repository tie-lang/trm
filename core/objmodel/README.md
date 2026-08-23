# core/objmodel/ — 对象模型 / 反射

对应设计 §3.4。运行期类型查询、自动序列化、跨域身份的公共底座（GC + 序列化 + 调试器 + 动态加载共用）。依赖 GC 的统一对象身份。

## 状态（S6）

已落地 **对象模型/反射底座探针**（`objmodel.tie`，命名空间 `trm_objmodel`，纯 tie 逻辑可
单文件编译回归）：

- **类型注册表**：name↔omTyId（内置 i64/f64/bool/string/fn/void）+ ir→om 类型桥接。
- **运行时类型查询**：对已加载 tieir（`trm_loader`）枚举函数签名/参数/返回类型。
- **自动序列化**：签名 ↔ 规范文本（`name:<t0>:<t1>:<ret>`）的可逆序列化/反序列化。
- **跨域身份**：签名 interning（同文↔同 id）+ gc 对象类型标（objId 由 `trm_gc` 给定 =
  统一对象身份，objmodel 关联类型）。

验收：`tests/s6obj` 32 断言全过。完整动态加载/热更/诊断留待 P4 深化。

## 状态（S7）诊断

`diag.tie`（`trm_diag`）——**运行时内省诊断探针**：把 loader/interp、gc、mnn、objmodel、
backend 契约矩阵汇总成统一诊断快照（模块头/计数/组件/版本/matrix_ok）+ 内省自检
（反射 round-trip 逐条自洽）。验收 `tests/s7diag` 15 断言全过。P4「诊断 + 类型内省」落地。

## 状态（S8）动态加载 / 生命周期

`module.tie`（`trm_module`）——**模块注册表 + 动态加载生命周期**：`load` 动态加载 .tieir
并登记模块描述符（内省函数签名），`module_func_*` 多模块内省，`activate` 命中/`invoke`
按名动态调用（interp），`unload` 卸载禁用可复活。验收 `tests/s8mod`（含新资产 calc2
`double` 模块）19 断言全过。P4「动态加载 tieir」落地。