# 踩坑记录（都真实发生过）

## 1. backdrop 自引用 → 启动瞬间 SIGSEGV 爆栈

**症状**：装上模块后打开设置页立刻闪退，无异常对话框，logcat 里是栈溢出/原生 SIGSEGV。
**根因**：把悬浮底栏放进了 `Modifier.layerBackdrop(backdrop)` 的同一个 Box 里。采图层录制时又绘制了底栏，底栏又去读采图层 → 无限递归。
**规则**：任何要 `drawBackdrop` / `textureBlur` 的组件，必须画在它的采样图层**之外**。
**正确布局**：

```kotlin
Box(Modifier.layerBackdrop(backdrop)) {      // 采样层：只有页面内容
    HorizontalPager(...)
}
Scaffold(bottomBar = { BottomBar(backdrop = backdrop) })   // 底栏在层外
```

**自检**：把 `bottomBar` 槽里的组件临时移到采图层内部，如果能复现崩溃，说明布局对了；反之就是还在层内。

## 2. `Box` 不加 `fillMaxWidth()`，`align()` 会对着窄盒子对齐

卡片里放右下角图标时，`Box` 宽度被文字撑开（约 229dp）而卡片实际 370dp，`align(Alignment.BottomEnd)` 就对到窄盒子的右边 —— 图标落在卡片中间，之后再怎么调 `offset` 都"只动一点点"。
修法：`Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(CardDefaults.CornerRadius)))`。`clip` 同样必要，否则超出卡片的部分不裁剪，会画到卡片外面。

## 3. `offset` 不参与测量

`Modifier.offset()` 只改绘制位置，不进布局。所以把一个超尺寸图标往边缘推时：
- 它**不会**把父容器撑大 —— 这是想要的效果（裁剪而非撑高卡片）；
- 但如果父容器是 `wrapContent`（如 `IntrinsicSize.Min` 的 Row），`offset` 也**不会**为它让位，内容会直接叠在别的元素上，此时要改用 `padding` 或 `requiredWidth`。

## 4. 图标"贴边只露一部分"的几何上限

24 视图里，`check_circle_outline` 圆环占 `x = 2..22`，对勾占 `x = 6..18`、`y = 7.58..17`。
图标尺寸 `S`、水平外移 `dx` 时卡内可见到视图的 `24 − 24·dx/S` 处，要求对勾右端 ≥ 18：

```
24 − 24·dx/S ≥ 18   →   dx ≤ S/4
```

即**最多只能裁掉圆环直径的 20%**；同理垂直方向受 `y ≤ H/2 − 0.208S` 限制（`H` 为容器高）。这个比例与 `S` 无关，放大图标换不来更多裁切（`y` 的上限反而更小）。
要更深只有两条路：接受切到图标本体，或者换一份对勾更靠中心的 path 数据。**不要承诺做不到的效果，先把上限算给用户看。**

## 5. 点 tab 时指示器抽搐 / 跳位

想当然地直接在 `NavigationBarItem.onClick` 里调 `pagerState.animateToPage(index)`：底栏和 pager 各写一次状态，两次动画互相抢锁。
正解：`rememberMainPagerState(pagerState)`，点选走 `mainPagerState.animateToPage(index)`（立即更新 `selectedPage` 让指示器先动，`isNavigating` 期间忽略回传），手动滑动走 `LaunchedEffect(pagerState.currentPage) { mainPagerState.syncPage() }`。

## 6. 玻璃层的 `color` 忘了设透明

`SmallTopAppBar` / `NavigationBar` 自己有底色，`textureBlur` 打在它们外面就会被盖住 —— 表现是"玻璃没生效"。玻璃激活时必须 `color = Color.Transparent`。

## 7. `rememberLayerBackdrop` 的黑边/空采样

lambda 里先 `drawRect(surfaceColor)` 再 `drawContent()`：不打底会在半透明区域采到未定义像素，折射出黑边。
`layerBackdrop` 要挂在有真实尺寸的节点上（`fillMaxSize()`）；挂到 0 尺寸或被 `alpha(0f)` 完全隐藏的节点上则采不到东西，效果静默消失（`tabsBackdrop` 那层是特殊情况：它用 `alpha(0f)` 隐藏但仍有布局尺寸，所以可用）。

## 8. 参数不要手调，素材不要自绘

用户明确要求：界面素材来自 Miuix / KernelSU 官方源码，不要自绘；官方组件只做最小适配（改包名、改 import），不改尺寸/弹性/折射参数。历史上手调 `dampingRatio`/`stiffness`、手绘图标都返工过。

## 9. 图标依赖的坑

不要引 `androidx.compose.material:material-icons-extended`：它把几千个图标打包进 dex，实测给 APK 加 15 MB 以上。只需要单个图标时，手写一个 `ImageVector`（viewport 24、`path { ... }`）效果完全一致，参考 `assets/ksu-glass-ui` 旁边的 `CheckCircleOutline.kt` 写法。

## 10. 其它运行期注意

- 玻璃态要 `isRuntimeShaderSupported()` 门控，低版本设备或无 shader 时降级为不透明色，别硬开。
- `blur(4.dp, 4.dp)` + `lens(24.dp, 24.dp)` 是每帧 GPU 工作，`blurRadius` 别再往上加；列表页同时开多个 `textureBlur` 会明显掉帧。
- 悬浮底栏两侧要给 `padding(start = 28.dp, end = 28.dp)`，否则胶囊贴到屏幕边缘，圆角会被裁掉一半。
- 底栏底部留白别写死：`insets != 0.dp ? 8.dp + insets : 28.dp`，否则手势条机型上底栏会被导航条压住。
