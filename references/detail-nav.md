# 二级页面导航与预测性返回（miuix-nav，已在 PrivacyDot 跑通）

一级页（底栏 + Pager）之上叠详情页，用 Miuix 自带的导航栈实现：
进入动画、边缘滑动返回、预测性返回跟手、取消回弹全部由库内完成，**不要自己写 graphicsLayer 位移**。
参考实现：`/workspace/PrivacyDot` 的 `ui/MainActivity.kt`（KernelSU manager 用的是同一套 `miuix-nav`，其 `ui/MainActivity.kt` + `ui/navigation3/` 可对照）。

## 0. 依赖与版本要求（先看，不满足直接编不过）

```toml
# gradle/libs.versions.toml
miuix = "0.9.4"
kotlinx-serialization = "1.11.0"
navigationevent = "1.1.2"

miuix-nav = { group = "top.yukonga.miuix.kmp", name = "miuix-nav-android", version.ref = "miuix" }
kotlinx-serialization-json = { group = "org.jetbrains.kotlinx", name = "kotlinx-serialization-json", version.ref = "kotlinx-serialization" }
androidx-navigationevent-compose = { group = "androidx.navigationevent", name = "navigationevent-compose", version.ref = "navigationevent" }

kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

```kotlin
// app/build.gradle.kts
plugins { alias(libs.plugins.kotlin.serialization) }
dependencies {
    implementation(libs.miuix.nav)          // NavDisplay / NavBackStack / NavSwipeDirection
    implementation(libs.kotlinx.serialization.json)  // rememberNavBackStack 存 Bundle 用
    implementation(libs.androidx.navigationevent.compose) // 关闭预测返回时自己接返回事件
}
compileOptions {
    // ★ miuix-nav 用 JVM 21 编译，entry<T>() 是 inline 函数；
    //   target 11 会报 "Cannot inline bytecode built with JVM target 21"
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}
```

`Route` 必须 `@Serializable`（返回栈会经 rememberSaveable 存进 Bundle，转屏/进程回收后回到原二级页）。

## 1. 路由定义

```kotlin
@Serializable
sealed interface Route : NavKey {
    @Serializable data object Main : Route            // 一级页（底栏 + Pager）
    @Serializable data object IndicatorTypes : Route // 二级页，简单页面用 data object
    @Serializable data class Detail(val id: Int) : Route // 带参数用 data class
}
```

## 2. 导航骨架（唯一一层 Scaffold）

```kotlin
@Composable
fun AppShell(state: PrefsState) {
    val backStack = rememberNavBackStack<Route>(Route.Main)
    val predictiveBack = state.bool(Prefs.Keys.PREDICTIVE_BACK)
    // 开关直接映射成方向：LeftToRight=边滑+预测返回；None=禁
    val swipeDismiss = if (predictiveBack) NavSwipeDirection.LeftToRight else NavSwipeDirection.None
    val push: (Route) -> Unit = { if (it !in backStack) backStack.add(it) }
    val pop: () -> Unit = { if (backStack.size > 1) backStack.removeLastOrNull() }
    val canPop = backStack.size > 1

    Scaffold(modifier = Modifier.fillMaxSize()) { _ ->
        NavDisplay(
            backStack = backStack,
            modifier = Modifier.fillMaxSize(),
            effects = NavDisplayEffects(cornerClipRadius = rememberNavSystemCornerRadius()),
            onBack = pop,
        ) {
            // ★ 根条目必须 NavSwipeDirection.None：它没有可返回的上一级，
            //   开了边滑会把整屏往右拖。
            entry<Route.Main>(swipeDismiss = NavSwipeDirection.None) {
                MainScreen(onOpen = push)
            }
            entry<Route.IndicatorTypes>(swipeDismiss = swipeDismiss) {
                DetailPage(
                    title = stringResource(R.string.indicator_types_entry),
                    onBack = pop,
                ) { /* LazyListScope 内容 */ }
            }
        }

        // ★ 完全关闭预测返回必须再加这一段，见第 5 节。
        if (!predictiveBack) {
            val navEventState = rememberNavigationEventState(NavigationEventInfo.None)
            NavigationBackHandler(
                state = navEventState,
                isBackEnabled = canPop,
                onBackCompleted = pop,
            )
        }
    }
}
```

导航栈在 NavDisplay 里自带过渡动画（MiuixDefault：推进/退出/缩放/暗化），
push 前记得判重（`route !in backStack`），双击连推同一路由会在 reconcile 时被拒。

## 3. 一级页：不嵌套 Scaffold

根条目内容自己用 Box 摆位，**不要在 NavDisplay 的 entry 里再放一层 Scaffold**
（Scaffold 套 Scaffold 会有 insets 双重消费、SubcomposeLayout 双份层级的问题）。
顶栏/底栏是浮在内容之上的两层，天然在采样图层之外（符合 backdrop 规则）：

```kotlin
@Composable
fun MainScreen(onOpen: (Route) -> Unit) {
    val pagerState = rememberPagerState(pageCount = { PAGE_COUNT })
    val mainPagerState = rememberMainPagerState(pagerState)
    val blurBackdrop = ...  // 整屏采样，同 integration-walkthrough
    var bottomBarHeight by remember { mutableStateOf(64.dp) }
    val density = LocalDensity.current

    Box(Modifier.fillMaxSize()) {
        Box(Modifier.layerBackdrop(blurBackdrop)) {          // 采样层：只有 pager
            HorizontalPager(state = pagerState, ...) { page -> ... }
        }
        TopBar(...)                                          // 顶栏画在层外
        Box(Modifier.align(Alignment.BottomCenter)
            .onSizeChanged { bottomBarHeight = with(density) { it.height.toDp() } }) {
            BottomBar(...)                                    // 底栏画在层外
        }
    }
}
```

- 底部内容留白用**实测**的 `bottomBarHeight`（悬浮态 64dp 胶囊 ≠ 通栏 64+insets），`onSizeChanged` 拿到真实高度再传给各页，切换形态不会错位。
- 顶栏可加 `actions: @Composable RowScope.() -> Unit` 槽，放全页共用的图标（如重启 SystemUI）；危险动作先弹 `OverlayDialog` 确认。

## 4. 二级页模板（DetailPage）

三个要点：**不透明背景**、**带返回箭头的顶栏**、**没有底栏**：

```kotlin
@Composable
fun DetailPage(
    title: String,
    onBack: () -> Unit,
    content: LazyListScope.() -> Unit,
) {
    val statusBarTop = WindowInsets.statusBars.asPaddingValues().calculateTopPadding()
    val bottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val topSpace = statusBarTop + TopAppBarDefaults.SmallTopAppBarCenterHeight +
        TopAppBarDefaults.SubtitleBottomPadding

    Box(Modifier.fillMaxSize().background(MiuixTheme.colorScheme.surface)) { // ★ 必须画背景
        PageColumn(topSpace = topSpace, bottomSpace = bottomInset + 8.dp, content = content)
        TopBar(backdrop = null, glass = false, title = title, onBack = onBack)
    }
}

@Composable
private fun BackButton(onClick: () -> Unit) {
    val layoutDirection = LocalLayoutDirection.current
    IconButton(onClick = onClick) {
        Icon(
            modifier = Modifier.graphicsLayer {
                if (layoutDirection == LayoutDirection.Rtl) scaleX = -1f // RTL 镜像
            },
            imageVector = MiuixIcons.Back,       // top.yukonga.miuix.kmp.icon.extended.Back
            contentDescription = stringResource(R.string.back),
            tint = MiuixTheme.colorScheme.onBackground,
        )
    }
}
```

- 背景必须是 `surface`（与 Scaffold 容器色一致）。不画背景 → 底下一级页列表透上来，看起来就是"二级页只显示了一半"。
- 二级页顶栏 `backdrop = null, glass = false`：二级页自己不是采样层，别把磨砂接进来。
- 底部留白只算导航条（没有底栏）。
- 被覆盖的一级页**仍留在组合树里**（NavDisplay 特性），所以预测返回拖动时露出的是真的一级页，不会白屏。

## 5. 预测性返回开关（最容易做错的一处）

**`NavSwipeDirection.None` 只关掉 NavDisplay 自己的边缘滑动识别器**，系统级预测返回
仍然直接接到 NavDisplay 内部 → 手势照样跟手。要"关掉开关=普通返回"必须自己再挂一个
返回处理器，写在 NavDisplay **之后**（navigationevent 仲裁是"后组合且 enabled 优先"）：

```kotlin
if (!predictiveBack) {
    val navEventState = rememberNavigationEventState(NavigationEventInfo.None)
    NavigationBackHandler(
        state = navEventState,
        isBackEnabled = canPop,        // 只有栈 >1 时才接，一级页让给系统
        onBackCompleted = pop,
    )
}
```

- `NavigationEventInfo.None` = 不跟手：拖动过程中界面不动，松手才返回（即普通返回）。
- 开关打开时不注册它，交回 NavDisplay 的跟手 + 取消回弹效果。
- 判据：`backStack.size > 1` 每次重组都算一次，别缓存成 Boolean。

## 6. 踩坑：为什么不用 overlay / AnimatedContent 方案

曾用 `AnimatedContent(targetState = detail)` + `graphicsLayer { translationX = progress * width }` 自己实现，全部失败，失败方式记录如下，别再走这条路：

| 症状 | 根因 |
|---|---|
| 二级页"只显示一半"，底下透出一级页列表 | 覆盖层没画不透明背景 |
| 覆盖层盖不住底栏区域 | 覆盖层写在页面组合内部，被 pager 页面尺寸（不含底栏）限制 |
| 拖动返回时背景全白 | AnimatedContent 把上一级页移出了组合树，下面没有东西可显示 |
| 手势取消后界面僵住 | 动画状态绑定在页面级 remember 上，页面重组即失联 |
| 开关关闭后预测返回仍在 | 只设了 NavSwipeDirection.None，没挂第 5 节的 NavigationBackHandler |

以上五条在换成 miuix-nav 返回栈后同时消失。判断标准很简单：
**需要"盖在一级页之上的整屏页面"时，用返回栈 entry，不要用 overlay。**
overlay 只适合对话框、菜单这类不需要参与返回栈的临时层。


## 7. 多层页面（列表页 → 应用详情页）

当一级页打开应用列表、再点应用进入详情时，继续使用同一个 `NavDisplay` 返回栈，不要在列表页内另建导航器，也不要用 Dialog/overlay 伪装详情页。路由用可序列化参数携带稳定标识（优先包名）：

```kotlin
@Serializable data class AppList(val section: String) : Route
@Serializable data class AppDetail(val section: String, val packageName: String) : Route
```

依次 push `AppList(section)`、`AppDetail(section, packageName)`。列表和详情都是不透明 `surface` 全屏 entry，均使用与预测性返回设置一致的 `swipeDismiss`；根 entry 仍为 `None`。详情返回只 pop 一层，因此手势预览显示应用列表，继续返回才回一级页。应在每个 entry 内基于路由参数读取配置，确保指示器与状态栏使用独立配置键；不要把当前选中应用只存在易丢失的局部页面状态里。

详情页的开关、分项与下拉选择直接写入各自既有偏好键；旧版包名名单/规则需要保持原格式兼容，新增 UI 不应清空或迁移破坏已有值。测试需覆盖列表→详情、系统返回、边缘预测返回的跟手与取消回弹、连续两层返回、旋转/进程恢复，以及预测返回关闭后松手才 pop。