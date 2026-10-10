# miuix-liquid-glass-nav

一个 **Agent Skill**：用 Miuix + KernelSU 模板给 Android Compose 工程做**液态玻璃底栏 / 磨砂顶栏 / 悬浮胶囊 tab 栏**，以及 **miuix-nav 二级页面导航与预测性返回**。

模板代码不是重写的，是从 [KernelSU](https://github.com/tiann/KernelSU) 与 Miuix example **原样移植**（只改包名和 import），参数保持上游原值。

## 内容

| 路径 | 内容 |
|---|---|
| `SKILL.md` | 技能正文：执行顺序、硬规则、资源索引 |
| `assets/ksu-glass-ui/` | 10 个 Kotlin 模板（FloatingBottomBar、DampedDragAnimation、InteractiveHighlight、DragGestureInspector、Lens、Vibrancy、InnerShadow、CombinedBackdrop、MainPagerState、CheckCircleOutline） |
| `scripts/install-glass-ui.sh` | 把模板复制到目标工程并按目标包名重写 `package` / `import`（POSIX sh，Android 上用 `sh` 调用） |
| `references/integration-walkthrough.md` | 从依赖到验收的完整接线，含可编译片段 |
| `references/detail-nav.md` | 二级页面导航与预测性返回：miuix-nav 依赖、路由、NavDisplay 骨架、DetailPage 模板、返回开关的正确关法、overlay 方案失败记录 |
| `references/layer-anatomy.md` | 各文件职责、公开 API、三层结构、全部参数原值表 |
| `references/pitfalls.md` | 真实故障与修法 |
| `references/sources.md` | Miuix / KernelSU 源码路径与 commit、查证流程 |

## 用法

作为 Skill 安装（目录需包含 `SKILL.md`），或直接把 `assets/` 里的文件拷进工程：

```sh
sh scripts/install-glass-ui.sh <工程根目录> <目标包名>
```

## 关键约束（完整版见 SKILL.md）

- `drawBackdrop` / `textureBlur` 的组件不能画在自己的采样图层里，否则启动即 SIGSEGV 爆栈。
- 两个 backdrop 必须分开：`blurBackdrop` 包整屏，`backdrop` 只包页面。
- 模板参数不做二次创作。
- 二级页面一律走 miuix-nav 返回栈，不用 overlay / AnimatedContent 自制；miuix-nav 需要 JVM target 21，Route 必须 `@Serializable`。
- 要关掉预测性返回，除 `NavSwipeDirection.None` 外还需在 `NavDisplay` 之后挂 `NavigationBackHandler`。

## 来源与致谢

- [Miuix](https://github.com/miuix-kotlin/miuix) —— UI 组件库与主题
- [KernelSU](https://github.com/tiann/KernelSU) —— 液态玻璃底栏的原始实现（`manager/app/src/main/java/me/weishu/kernelsu/ui/`）

本仓库只做整理与文档化。
- [Miuix](https://github.com/compose-miuix-ui/miuix) —— UI 组件库与主题（本 skill 基于 `0657575`）
- [KernelSU](https://github.com/tiann/KernelSU) —— 液态玻璃底栏的原始实现（本 skill 基于 `24d9bc3`，`manager/app/src/main/java/me/weishu/kernelsu/ui/`）