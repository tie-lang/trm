# lib/ — 可共用代码（库层业务能力面）

对应设计 §4。**全 tie 写**，业务能力面，对标 JDK 类库。这里放跨工具/跨平台可复用的逻辑域。

系统域命名空间：`trm.terminal / trm.process / trm.fs / trm.env / trm.session / trm.clock / trm.net / trm.data / trm.ui`。
交付形态：纯逻辑 → 静态编入产物；平台绑定 → 平台桥动态库（编译到 impl-*）。

当前为空目录，P1 起填充。