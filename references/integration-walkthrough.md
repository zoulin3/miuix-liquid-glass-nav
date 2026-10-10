# 接入流程：Miuix 主题 + 双层 backdrop + 液态玻璃底栏

目标产物：顶栏与「通栏」底栏整条矩形磨砂；「悬浮」底栏是带折射、高光、按压缩放的胶囊。
对照实现（已验证可编译可运行）：`/workspace/PrivacyDot/app/src/main/kotlin/com/eta/privacydot/ui/MainActivity.kt`
（`MiuixRoot` / `PrivacyDotShell` / `TopBar` / `BottomBar` 四个函数，约 300–555 行）。

## 1. 依赖

`gradle/libs.versions.toml`：

```toml
[versions]
agp = "9.4.1"
kotlin = "2.4.20"
miuix = "0.9.4"
androidx-lifecycle = "2.11.0"
activityCompose = "1.13.0"

[libraries]
miuix-ui = { group = "top.yukonga.miuix.kmp", name = "miuix-ui-android", version.ref = "miuix" }
miuix-blur = { group = "top.yukonga.miuix.kmp", name = "miuix-blur-android", version.ref = "miuix" }
miuix-icons = { group = "top.yukonga.miuix.kmp", name = "miuix-icons-android", version.ref = "miuix" }
miuix-preference = { group = "top.yukonga.miuix.kmp", name = "miuix-preference-android", version.ref = "miuix" }
miuix-nav = { group = "top.yukonga.miuix.kmp", name = "miuix-nav-android", version.ref = "miuix" }
activity-compose = { group = "androidx.activity", name = "activity-compose", version.ref = "activityCompose" }
androidx-lifecycle-runtime-compose = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "androidx-lifecycle" }
```

`app/build.gradle.kts`：

```kotlin
android {
    namespace = "com.example.app"
    compileSdk = 37
    buildToolsVersion = "36.0.0"
    defaultConfig { minSdk = 34; targetSdk = 36 }
    buildFeatures { compose = true }
}
kotlin { jvmToolchain(25) }

dependencies {
    implementation(libs.miuix.ui)
    implementation(libs.miuix.blur)      // textureBlur / drawBackdrop / layerBackdrop / Highlight
    implementation(libs.miuix.icons)     // MiuixIcons.Demibold.* 图标
    implementation(libs.miuix.preference)
    implementation(libs.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
}
```

`minSdk < 33` 时 `isRuntimeShaderSupported()` 返回 false，玻璃态自动降级为不透明色，业务代码不需要分支。

## 2. 主题

整棵 UI 树必须在 `MiuixTheme` 之下；只有根节点创建 `ThemeController`，子页面不要再套一层。

```kotlin
val mode = when {
    monet && themeMode == Prefs.THEME_LIGHT -> ColorSchemeMode.MonetLight
    monet && themeMode == Prefs.THEME_DARK  -> ColorSchemeMode.MonetDark
    monet                                   -> ColorSchemeMode.MonetSystem
    themeMode == Prefs.THEME_LIGHT          -> ColorSchemeMode.Light
    themeMode == Prefs.THEME_DARK           -> ColorSchemeMode.Dark
    else                                    -> ColorSchemeMode.System
}
val controller = remember(mode) { ThemeController(colorSchemeMode = mode) }
MiuixTheme(controller = controller) { AppShell(...) }
```

深浅判断统一走 `MiuixTheme.colorScheme.surface.luminance() < 0.5f`（模板里已封装成 `isInDarkTheme()`），不要另读 `Configuration.uiMode`，否则 Monet 模式下会和实际配色不一致。

## 3. 双层 backdrop（最关键的一步）

```kotlin
val glass = state.bool(Prefs.Keys.LIQUID_GLASS) && isRuntimeShaderSupported()
val floating = state.bool(Prefs.Keys.FLOATING_BAR)
val surfaceColor = MiuixTheme.colorScheme.surface

// ① 整屏采样源：顶栏 + 通栏底栏的磨砂都读它
val blurBackdrop = if (glass) rememberLayerBackdrop {
    drawRect(surfaceColor); drawContent()
} else null

// ② 页面采样源：只圈住 HorizontalPager，悬浮胶囊读它
val backdrop = rememberLayerBackdrop {
    drawRect(surfaceColor); drawContent()
}
```

规则：**要 drawBackdrop 的组件绝不能画在自己的采样图层里面**。胶囊底栏放在 `Scaffold.bottomBar`（图层外），`backdrop` 只贴在 `HorizontalPager` 上。违反这一条会在启动时自引用递归 → SIGSEGV 爆栈（见 `pitfalls.md`）。

## 4. Scaffold 接线

```kotlin
Scaffold(
    modifier = Modifier.fillMaxSize(),
    topBar = { TopBar(backdrop = blurBackdrop, glass = glass) },
    bottomBar = { BottomBar(...) },
) { innerPadding ->
    pagerContent(innerPadding.calculateBottomPadding())
}
```

- `bottomBar` 保持在 Scaffold 槽位里，不要改成手写覆盖层（KernelSU 的做法，覆盖层会让页面底部 padding 算错）。
- 底栏底部留白：
  `val bottomPadding = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding().let { if (it != 0.dp) 8.dp + it else 28.dp }`
- 每个页面顶部留白 = `statusBars + TopAppBarDefaults.SmallTopAppBarCenterHeight + TopAppBarDefaults.SubtitleBottomPadding`，底部留白用 `innerPadding.calculateBottomPadding()`。

## 5. 底栏两形态

`BottomBar(...)` 一个函数里分叉，`floating = false` 走通栏：

```kotlin
Box(
    modifier = if (glass && blurBackdrop != null) Modifier.textureBlur(
        backdrop = blurBackdrop,
        shape = RectangleShape,          // 通栏必须矩形，不要圆角
        blurRadius = 25f,
        colors = BlurDefaults.blurColors(
            blendColors = listOf(BlendColorEntry(color = MiuixTheme.colorScheme.surface.copy(0.87f))),
        ),
    ) else Modifier,
) {
    NavigationBar(
        modifier = modifier,
        color = if (active) Color.Transparent else MiuixTheme.colorScheme.surface,
    ) {
        items.forEachIndexed { index, item ->
            NavigationBarItem(
                modifier = Modifier.weight(1f),
                icon = item.icon, label = item.label,
                selected = selectedIndex == index,
                onClick = { onSelected(index) },
            )
        }
    }
}
```

`floating = true` 交给模板：

```kotlin
FloatingBottomBar(
    modifier = modifier.padding(start = 28.dp, end = 28.dp, bottom = bottomPadding),
    selectedIndex = selectedIndex,
    onSelected = onSelected,
    backdrop = backdrop,          // ← 页面采样源，不是 blurBackdrop
    tabsCount = items.size,
    isBlurEnabled = glass,
) { activateTab ->
    items.forEachIndexed { index, item ->
        FloatingBottomBarItem(
            selected = selectedIndex == index,
            onClick = { activateTab(index) },
            modifier = Modifier.defaultMinSize(minWidth = 76.dp),
        ) {
            Icon(imageVector = item.icon, contentDescription = item.label)
            Text(text = item.label, fontSize = 11.sp, lineHeight = 14.sp,
                 maxLines = 1, softWrap = false, overflow = TextOverflow.Visible)
        }
    }
}
```

底栏与 pager 的同步必须用 `MainPagerState`（`rememberMainPagerState`），不要直接调 `pagerState.animateToPage`：否则点 tab 时两侧各写一次状态，指示器来回抽搐。手动滑动时用 `LaunchedEffect(pagerState.currentPage) { mainPagerState.syncPage() }` 回传。

## 6. 顶栏

```kotlin
@Composable
private fun TopBar(backdrop: LayerBackdrop?, glass: Boolean) {
    val active = glass && backdrop != null
    Box(
        modifier = if (active) Modifier.textureBlur(
            backdrop = backdrop, shape = RectangleShape, blurRadius = 25f,
            colors = BlurDefaults.blurColors(
                blendColors = listOf(BlendColorEntry(color = MiuixTheme.colorScheme.surface.copy(0.87f))),
            ),
        ) else Modifier,
    ) {
        SmallTopAppBar(
            title = stringResource(R.string.app_name),
            color = if (active) Color.Transparent else MiuixTheme.colorScheme.surface,
            scrollBehavior = MiuixScrollBehavior(),
        )
    }
}
```

玻璃生效时被磨砂包的组件 `color` 必须设成 `Color.Transparent`，否则磨砂被不透明底色盖住。

## 7. 完成判据

1. 冷启动不崩、不闪黑（没触发 backdrop 自引用）。
2. 顶栏下内容滚动时从磨砂后面穿过。
3. 悬浮底栏：滑动页面时胶囊内出现内容折射；按住某个 tab 胶囊轻微放大、高光增强；可拖动跨 tab 吸附。
4. 点 tab 与手动滑动都不会让指示器抽搐或跳位。
5. 关闭「液态玻璃」开关后立刻退回不透明纯色，不支持 RuntimeShader 的设备同样成立。
