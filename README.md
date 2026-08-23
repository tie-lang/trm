# trm — tie 平台的运行时套件

> 状态：**初始化阶段**（骨架 + 设计定稿）

trm（tie runtime suite）是 tie 平台的运行时套件。定位为**双层 + 非对称**：

- **路线 A（纯编译，零依赖）**：开发者不 import trm，走现状的稳固路径——`tiec ──▶ LLVM ──▶ 原生可执行文件`（actor / 纯逻辑 / 编译器自身 / 算法库）。
- **路线 B（trm 运行时）**：import trm，`tiec` 产出 tieir 字节码，由 trm 引擎执行，提供 GC / M:N 协程 / 反射 / 动态加载 / 可替换后端等能力面。

哲学：**纯编译是安全默认；运行时是能力增强。** 两条路同源一套源码，`import` 即选择。

## 权威设计

权威设计文档随 tie 主仓维护（本仓的 `docs/` 后续会承接独立副本）：

- `trm-final-design.md`——唯一权威运行时设计，取代 `trm-arch.md`
- `trm-design-compare.md`——方案对比
- `concurrency-model.md`——actor 原生语法零运行时

## 快速开始

```bash
tiec main.tie -o trm.exe
./trm.exe
```

## 工程结构

```
trm/
├── tie.pkg           # 包清单
├── main.tie          # 入口（占位）
├── docs/             # 设计文档索引
├── src/              # 运行时源码（待建）
└── impl-*/           # 平台实现层（win32 / posix / macos / android，待建）
```