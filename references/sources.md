# 库与源码索引（本机路径）

## Miuix（库）

- 坐标：`top.yukonga.miuix.kmp:miuix-ui-android` / `miuix-blur-android` / `miuix-icons-android` / `miuix-preference-android` / `miuix-nav-android`
- 已验证版本：`0.9.4`（Kotlin 2.4.20、AGP 9.4.1、compileSdk 37、buildToolsVersion 36.0.0、JDK 25）
- 依赖拉取走阿里云镜像，缓存在 `~/.gradle/caches/modules-2/files-2.1/top.yukonga.miuix.kmp/`

模块职责：

| 模块 | 用途 |
|---|---|
| `miuix-ui` | 核心组件：Scaffold、NavigationBar、TopAppBar、Card、Switch、TextField…（自带 miuix-core、miuix-squircle） |
| `miuix-blur` | `layerBackdrop` / `rememberLayerBackdrop` / `textureBlur` / `drawBackdrop` / `Highlight` / `isRuntimeShaderSupported` |
| `miuix-icons` | `MiuixIcons.Demibold.*` 等 5 种字重 |
| `miuix-preference` | 设置项组件 |
| `miuix-nav` | 自带返回栈的导航运行时（注意不要按旧模块名去推 `androidx.navigation3` API） |

## Miuix 源码

路径：`/workspace/miuix-src`（完整 git 仓库，约 29 MB，只读参考）
已验证 commit：`0657575`（2026-10-06，`build: Adopt build-logic composite build best practices`）

- 官方示例里的液态玻璃底栏原型：`/workspace/miuix-src/example/shared/src/commonMain/kotlin/component/liquid/`
  （`LiquidGlassNavigationBar.kt`、`Lens.kt`、`Vibrancy.kt`、`InnerShadow.kt`、`CombinedBackdrop.kt`）
- 组件源码：`/workspace/miuix-src/miuix-ui/src/commonMain/kotlin/top/yukonga/miuix/kmp/`
- 文档：`/workspace/miuix-src/docs/guide/`、中文版 `/workspace/miuix-src/docs/zh_CN/`

## KernelSU 源码（移植来源）

路径：`/workspace/ksu-src`（约 16 MB）
已验证 commit：`24d9bc3`（2026-10-08）
底栏与液态玻璃全部在 `manager/app/src/main/java/me/weishu/kernelsu/ui/component/`：

| 文件 | 内容 |
|---|---|
| `FloatingBottomBar.kt` | 悬浮胶囊底栏（含重力跟随高光） |
| `bottombar/BottomBar.kt` | `MainPagerState` 出处 |
| `bottombar/BottomBarMiuix.kt` | Miuix 版通栏/悬浮分叉、`TopBar` 磨砂、pager 布线 |
| `liquid/Lens.kt`、`Vibrancy.kt`、`InnerShadow.kt`、`CombinedBackdrop.kt` | 折射、饱和度、内阴影、采样合成 |

上游出处：`Kyant0/AndroidLiquidGlass`（Apache 2.0）→ Miuix example 镜像 → KernelSU 移植 → 本 skill 的 `assets/ksu-glass-ui`。

## 查证流程（不要凭记忆写签名）

1. 需要某个 Miuix 组件的准确签名时，先在 `/workspace/miuix-src` 里 grep 组件名：
   `grep -rn "fun Scaffold" /workspace/miuix-src/miuix-ui/src/commonMain/kotlin/ | head`
2. 移植类文件的行为细节，直接读 `/workspace/ksu-src/manager/.../component/` 的原件对照。
3. 只有本地仓库不存在时才去读 gradle 缓存里的 aar / 用 jadx 反编译。
4. 已安装的内置 `miuix` skill（`/data/data/io.github.mangi.eta/files/skills/miuix/`）是官方组件目录与用法参考：`references/miuix-nav.md`、`references/setup-and-theme.md`、`references/component-selection.md`、`references/color-lookup.md`。组件级问题先查它，液态玻璃/底栏观感问题查本 skill。

## 版本更替时

Miuix 升版本后，按顺序复核：

1. `miuix-blur` 的 `Backdrop` / `BackdropEffectScope` API 是否变动（`lens`、`vibrance`、`colorControls`、`drawBackdrop` 参数）。
2. `NavigationBar` / `NavigationBarItem` 的参数顺序（0.9.4 起 `NavigationBarItem` 在 `badge` 之前多了一个 `NavigationBarItemColors`）。
3. `Highlight` / `BloomStroke` / `LightPosition` 是否仍是这些名字。
4. 拿模板跑一遍 `assembleRelease`，编译错误就是签名变更清单。
