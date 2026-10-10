---
name: miuix-liquid-glass-nav
description: "Miuix 液态玻璃底栏与导航专家（KernelSU 模板）。用于给 Android Compose 工程做磨砂顶栏、通栏/悬浮底栏、胶囊 tab 栏、折射高亮等液态玻璃效果，或移植/排障这套底栏，或做 Miuix 二级页面/详情页导航与预测性返回：液态玻璃、liquid glass、玻璃底栏、磨砂底栏、悬浮底栏、floating bottom bar、胶囊底栏、tab 栏、底部导航、NavigationBar 悬浮/通栏、二级页面、详情页、页面切换、页面进入动画、返回上一级、预测性返回、predictive back、预见性返回、返回手势、边滑返回、NavDisplay、NavBackStack、NavSwipeDirection、miuix-nav、返回栈、blur backdrop、layerBackdrop、rememberLayerBackdrop、textureBlur、drawBackdrop、lens 折射、refraction、vibrancy、innerShadow、CombinedBackdrop、DampedDragAnimation、InteractiveHighlight、Highlight/BloomStroke、MainPagerState、KernelSU 底栏、Miuix 主题/ThemeController/MiuixTheme 底栏，或相关症状：底栏不显示玻璃、折射失效、磨砂没生效、启动闪退/爆栈、指示器抽搐、tab 点击跳位、二级页只显示一半、返回时白屏、拖动返回不跟手、关闭开关后预测返回仍在。用 Miuix 但只问普通按钮/卡片的走内置 miuix skill；指定 Material 3 或非 Miuix 主题时不触发。"
---

# Miuix 液态玻璃底栏（KernelSU 模板）

一套已经跑通的组合：Miuix 主题 + 两层 backdrop + KernelSU 移植的悬浮胶囊底栏 + miuix-nav 二级页面导航。
本 skill 含可直接复制的模板代码（`assets/ksu-glass-ui/`，10 个 Kotlin 文件）和已核对过的参数原值。

## 何时用

用户要在 Miuix / HyperOS 风格应用里做底部导航或顶栏，并提到玻璃、磨砂、悬浮、液态、折射、胶囊、iOS 观感；要做二级页面/详情页（从一级页点进去、带返回的那层）；要页面进入动画、返回手势、预测性返回；或者相反，报告这套界面的故障（没玻璃、折射失效、启动闪退、指示器抽搐、二级页只显示一半、返回白屏、拖动不跟手、关了开关预测返回还在）。

## 执行顺序

1. 先读 `references/integration-walkthrough.md`，按里面 7 节接线：依赖 → 主题 → 双层 backdrop → Scaffold → 底栏两形态 → 顶栏 → 判据。
2. 用脚本装模板（会按目标包名重写 `package` / `import`）：
   `sh scripts/install-glass-ui.sh <工程根目录> <目标包名>`
   默认落到 `<工程>/app/src/main/kotlin/<目标包名路径>`。Android 环境只有 `ash`，用 `sh` 调用，不要用 `bash`。
3. 要做二级页面、页面切换动画、预测性返回、返回手势 → 读 `references/detail-nav.md`，从第 0 节依赖开始（JVM 21 不满足直接编不过），照第 2 节骨架接 NavDisplay，**不要自己写位移动画**。
4. 需要弄清某个文件干什么、参数原值是多少，读 `references/layer-anatomy.md`；改参数前先看那张常量表。
5. 出问题先查 `references/pitfalls.md`（底栏类）和 `references/detail-nav.md` 第 6 节（导航类），都是实际踩过的，能在里面找到答案就不要重新试错。
6. 要核对 API 签名或找上游实现，用 `references/sources.md` 的路径（本机已 clone Miuix 与 KernelSU 源码）。

## 硬规则

1. **`drawBackdrop` / `textureBlur` 的组件不能画在自己的采样图层里** —— 违反会自引用递归，启动即 SIGSEGV 爆栈。悬浮底栏放在 `Scaffold.bottomBar`，`backdrop` 只挂 `HorizontalPager`。
2. **两个 backdrop 必须分开**：`blurBackdrop` 包整屏（顶栏、通栏底栏用），`backdrop` 只包页面（悬浮胶囊用）。
3. **模板文件不做二次创作**：尺寸、弹性、折射、高光参数全用原值。历史上手调 dampingRatio/stiffness、手绘图标都返工了。
4. **素材必须来自 Miuix / KernelSU 官方源码**，不要自绘；官方组件只做最小适配（包名、import）。
5. **底栏↔pager 的同步一律走 `MainPagerState`**，不要直接调 `pagerState.animateToPage`。
6. 玻璃生效时被磨砂包裹的组件要 `color = Color.Transparent`；整条链路用 `isRuntimeShaderSupported()` 门控，低版本降级为不透明色。
7. **几何类诉求先算上限再承诺**：例如"图标贴边只露一部分且主体完整"存在数学上限（见 pitfalls 第 4 条），做不到就直说并给替代方案。
8. **二级页面一律走 miuix-nav 返回栈（NavDisplay + entry）**，不要用 overlay/AnimatedContent 自制（五个失败症状见 detail-nav 第 6 节）。根 entry 必须 `swipeDismiss = NavSwipeDirection.None`。
9. **miuix-nav 需要 JVM target 21**：`entry<T>()` 是 inline，target 11 会报 "Cannot inline bytecode built with JVM target 21"。Route 必须 `@Serializable`（返回栈存 Bundle）。
10. **要"关掉预测性返回"必须另挂 NavigationBackHandler**（写在 NavDisplay 之后），只设 `NavSwipeDirection.None` 关不掉系统级手势。见 detail-nav 第 5 节。

## 资源

| 路径 | 内容 |
|---|---|
| `assets/ksu-glass-ui/` | 10 个模板文件，KernelSU / Miuix example 原样移植（源包名 `com.eta.privacydot.ui.ksu`）：9 个玻璃底栏文件 + `CheckCircleOutline.kt`（不引 icons-extended 的手写图标范例） |
| `scripts/install-glass-ui.sh` | 复制模板并按目标包名重写 `package` / `import` |
| `references/integration-walkthrough.md` | 从依赖到验收的完整接线，含可编译片段 |
| `references/detail-nav.md` | 二级页面导航与预测性返回：miuix-nav 依赖、路由、NavDisplay 骨架、DetailPage 模板、返回开关的正确关法、overlay 方案失败记录 |
| `references/layer-anatomy.md` | 文件职责、公开 API、三层结构、全部参数原值表 |
| `references/pitfalls.md` | 10 条真实故障与修法 |
| `references/sources.md` | Miuix 库/源码、KernelSU 源码路径与 commit、查证流程 |

完整参考实现（可对照运行）：`/workspace/PrivacyDot`（宿主路径 `/data/local/tmp/eta/PrivacyDot`），界面代码在
`ui/MainActivity.kt`（主题、Shell、NavDisplay、MainScreen、TopBar、BottomBar、DetailPage、返回手势开关）与 `ui/ksu/`（模板文件本体）。
KernelSU manager 侧同套导航的官方实现：`/workspace/ksu-src/manager/app/src/main/java/me/weishu/kernelsu/ui/`（`MainActivity.kt` + `navigation3/`）。

## 落笔前

用 Miuix 但只涉及普通组件（按钮、卡片、开关、设置项）→ 用内置 `miuix` skill，不要拉这套玻璃模板进来，改动面太大。
只是要"页面 A 跳页面 B"且不需要动画/手势，走普通状态切换也行；一旦要进入动画、返回手势、预测性返回三者之一，就用 detail-nav 的返回栈方案，别混搭。


## 多级应用页面与预测性返回更新

二级列表页、三级应用详情页均应使用同一个 `miuix-nav` `NavDisplay` 返回栈；路由参数使用稳定包名，列表/详情整屏不透明 `surface`，不要嵌套导航器或自制位移动画。预测返回启用时沿用 `NavSwipeDirection.LeftToRight`，关闭时除设 `None` 外还需在 `NavDisplay` 后注册 `NavigationBackHandler`。详细接线、恢复行为和逐层返回验收见 `references/detail-nav.md` 第 7 节。
