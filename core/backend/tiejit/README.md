# core/backend/tiejit/ — 简易执行器

**其他语言写的一个简易执行实现**，专门顶替 orcjit 尚未覆盖的平台（Android / 无 LLVM 端）。待 orcjit 覆盖后由它上位淘汰。

- 定位：临时替代（设计 §7.3「Android ORC → 用户写临时替代实现」；§3.1 可替换后端之一）。
- 约束：后端须与 interp 语义一致（interp 为基准 + 契约矩阵）。
- 实现语言：非 tie（用其他语言），因为目标平台暂缺 LLVM/ORC，tie 编译路线难落地。

当前为空目录。