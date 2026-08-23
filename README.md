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
├── core/                # 引擎层（tieir 执行核心）
│   ├── frontend/          #  前端（interp 解释，语义基准）
│   │   └── loader/        #    tieir 类加载（并入前端）
│   ├── backend/
│   │   ├── orcjit/      #   LLVM ORC JIT（默认热点后端）
│   │   └── tiejit/      #   简易执行器（orcjit 未覆盖的平台先用，后被取代）
│   ├── gc/              # 引擎级统一 GC（独立子系统）
│   ├── mnn/             # M:N 协程 / async 调度
│   └── objmodel/        # 对象模型 / 反射
├── lib/                 # 可共用代码（库层业务能力，全 tie 写）
├── port/                # 接口（port 角色 / Backend trait / 平台端口）
├── tool/                # 工具层（构建 / 分发 / 诊断）
├── tie.pkg              # 包清单
└── main.tie             # 入口（占位）
```

依赖方向（硬约束）：`app → lib → core(interp/backend/gc) → port → 平台 → 系统 API`。

## License

本仓库按 tie-lang 组织自创的宽松许可证 **TIE-LANG Open Source License v1.0** 授权发布（全文见 [LICENSE](LICENSE)）：你可自由使用、修改并分发本软件源码，包括用于商业产品，仅需保留版权声明并附本许可证；而用该语言开发的自有软件完全归你所有，不附带任何署名义务。

This repository is released under the **TIE-LANG Open Source License v1.0** (full text in [LICENSE](LICENSE)): you may freely use, modify, and redistribute the source code, including in commercial products, provided you retain the copyright notice and a copy of the license; programs you write in the language are entirely your own, with no attribution obligation.