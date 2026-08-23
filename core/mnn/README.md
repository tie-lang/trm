# core/mnn/ — M:N 协程 / async 调度

对应设计 §5。可迁移栈 + M:N 调度器，栈由 GC 一并托管（依赖 core/gc）。

- lean async：方法内暂停（路线 B 完整 await）。
- 与 actor（路线 A 纯编译）衔接：默认解耦，老鸟 unsafe 显式接入（设计 §8）。

当前为空目录，P2 起填充。