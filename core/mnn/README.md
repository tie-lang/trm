# core/mnn/ — M:N 协程 / async 调度

对应设计 §5。可迁移栈 + M:N 调度器，栈由 GC 一并托管（依赖 core/gc）。

- lean async：方法内暂停（路线 B 完整 await）。
- 与 actor（路线 A 纯编译）衔接：默认解耦，老鸟 unsafe 显式接入（设计 §8）。

## 状态（S4）

已落地 **M:N 协程调度器探针**（`mnn.tie`，命名空间 `trm_mnn`，纯 tie 逻辑可单文件编译回归）：
固定 worker 池 M + 就绪队列多路复用 N 个协程的协作式 yield，`tests/s4mnn` 6 断言验收通过
（峰值并发 ≤ M，即 M:N 上界）。可迁移栈与真实 await 接入协程/GC 原生栈时实现。