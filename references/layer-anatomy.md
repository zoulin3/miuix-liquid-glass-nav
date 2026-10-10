# 分层与参数解剖

## 文件职责

| 文件 | 职责 | 来源 |
|---|---|---|
| `FloatingBottomBar.kt` | 悬浮胶囊底栏主体：外层 Row（折射 + 高光 + 阴影 + 拖动手势）、内层 Row（真实可点内容）、滑块指示器 | compose-miuix-ui example `IosLiquidGlassNavigationBar`，经 KernelSU 移植 |
| `DampedDragAnimation.kt` | 拖动/按压动画驱动：`value`（当前 tab 浮点位置）、`targetValue`、`pressProgress`、`modifier`（手势+动画）、`animateToValue()` | KernelSU `ui/component` |
| `DragGestureInspector.kt` | 底层指针手势识别，供上面的驱动调用 | KernelSU `ui/component` |
| `InteractiveHighlight.kt` | 手指命中位置的动态高光，`modifier` 负责绘制、`gestureModifier` 负责采集位置 | KernelSU `ui/component/liquid` |
| `Lens.kt` | `BackdropEffectScope.lens()`：圆角矩形折射（液态玻璃的核心观感），可选色散、景深 | Kyant0/AndroidLiquidGlass，Miuix example 镜像 |
| `Vibrancy.kt` | `BackdropEffectScope.vibrancy()`：`colorControls(saturation = 1.5f)` | 同上 |
| `InnerShadow.kt` | `Modifier.innerShadow()`：内阴影，给玻璃边缘加深 | 同上 |
| `CombinedBackdrop.kt` | `rememberCombinedBackdrop(a, b)`：把两个 `Backdrop` 合成一个，供 `drawBackdrop` 一次采样 | 同上 |
| `MainPagerState.kt` | 底栏↔pager 的共享状态，负责消除"点切换与滑动互相抢状态" | KernelSU `bottombar/BottomBar.kt` 内的 `MainPagerState` |

这些文件是同源模板，**不要为了"统一风格"重写**：删掉任一个都会破坏折射/高光链路。

## FloatingBottomBar 公开 API

```kotlin
@Composable
fun FloatingBottomBar(
    modifier: Modifier = Modifier,
    selectedIndex: Int,
    onSelected: (index: Int) -> Unit,
    backdrop: Backdrop,                   // 页面内容采样源（不是整屏那个）
    tabsCount: Int,
    isBlurEnabled: Boolean = true,
    content: @Composable RowScope.((Int) -> Unit) -> Unit,   // 参数是 activateTab(index)
)

@Composable
fun RowScope.FloatingBottomBarItem(
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
)

@Composable fun isInDarkTheme(): Boolean
val LocalFloatingBottomBarTabScale   // { () -> Float }，按压时由底栏提供 1f→1.2f
```

`content` 的 lambda 参数必须在 `onClick` 里调用（`onClick = { activateTab(index) }`），直接调 `onSelected` 会绕过指示器动画。

## 内部常量（KernelSU / Miuix example 原值，勿二次手调）

| 项 | 值 | 位置 |
|---|---|---|
| 外层 Row 高度 | `64.dp` | 胶囊外框 |
| 内层 Row 高度 | `56.dp` | 真实可点层 |
| 内外 padding | 外层 `.padding(4.dp)`，内层 `.padding(horizontal = 4.dp)` | 玻璃厚度 |
| tab 内容缩进 | `contentWidth = totalWidth − 8dp` | tabWidth 计算 |
| 拖拽橡皮筋 | `rubberBandPx = 4.dp` | 越界回弹 |
| 按压缩放（外层） | `lerp(1f, 1f + 16.dp/width, pressProgress)` 横向撑开 | layerBlock |
| 按压 tab 缩放 | `lerp(1f, 1.2f, pressProgress)` | `LocalFloatingBottomBarTabScale` |
| 指示器缩放 | `pressedScale = 78f / 56f` | `DampedDragAnimation` |
| 胶囊阴影 | `dropShadow(radius = 10.dp, alpha = 0.1f 亮 / 0.2f 暗)` | 外层 Row |
| backdrop 效果 | `padding ≥ 40.dp` → `vibrancy()` → `blur(4.dp, 4.dp)` → `lens(refractionHeight = 24.dp, refractionAmount = 24.dp)` | effects 块 |
| 高光 | `iosIndicatorSpecular`：`Highlight(width = 1.dp, BloomStroke(color = White 0.12f, innerBlurRadius = 2.dp, dualPeak = true, 主光 (0.5, −0.3, −0.05) 强度 1f, 副光 (0.5, 0.8, −0.5) 强度 0.4f))`；外层 `alpha = 0.75f` | 文件头 |
| 重力跟随 | `LIGHT_REF = (0.5, 0.7)`；`|g_xy| > 0.1`（约 6° 倾斜）才更新；角度步进 `3°`；主光额外 `−45°`、胶囊高光 `+90°` | `rememberGravityRotatedHighlight` |
| 玻璃底色 | `surfaceContainer.copy(0.4f)`；不透明态 `surfaceContainer` | `containerColor` |
| 强调色 | 指示器内 `MiuixTheme.colorScheme.primary` | `accentColor` |

## 三层结构（理解这个就不会写错）

1. **整屏采样层** `blurBackdrop`：`rememberLayerBackdrop { drawRect(surface); drawContent() }`，挂在 pager 外层 Box 上 → 顶栏/通栏底栏用它 `textureBlur`。
2. **页面采样层** `backdrop`：只挂在 `HorizontalPager` 上 → 悬浮胶囊用它 `drawBackdrop`。组件本身在 `Scaffold.bottomBar`，位于该图层之外，所以不会录到自己。
3. **tab 内容采样层** `tabsBackdrop`：`FloatingBottomBar` 内部建的第二层，用一个 `alpha(0f)` + `clearAndSetSemantics {}` 的 Row 记录 tab 图标/文字，再通过 `rememberCombinedBackdrop(backdrop, tabsBackdrop)` 合进主采样源 —— 这样图标也会出现在折射里。**这层必须 `alpha(0f)`，否则内容会被画两遍。**

## 其它玻璃组件

通栏底栏 / 顶栏用 `Modifier.textureBlur(backdrop, shape = RectangleShape, blurRadius = 25f, colors = BlurDefaults.blurColors(blendColors = listOf(BlendColorEntry(surface.copy(0.87f)))))`，并在玻璃生效时把组件自身 `color` 设为 `Color.Transparent`。`surface.copy(0.87f)` 是不透明度基准，想更通透就调小它（但别低于 0.6，否则文字对比度不够）。
