# FClash Plus

> [English / 英文说明](./README.md)

基于 [FlClash](https://github.com/chen08209/FlClash) 的 **macOS 专属**修改版本，主要改进系统托盘菜单的使用体验。

---

## 致谢与基线

本项目基于 [chen08209](https://github.com/chen08209) 开发的 **[FlClash](https://github.com/chen08209/FlClash)**——一款基于 ClashMeta 的跨平台代理客户端。**所有核心功能的版权归原作者**。

- **基线版本**:FlClash `v0.8.92`
- **核心 (`FlClashCore`)**:**未做任何修改**,直接复用上游的 macOS 预编译二进制
- **范围**:仅 macOS。Android / Windows / Linux / iOS 源码已全部移除,属于个人使用版本

---

## 修改内容

所有改动都集中在 macOS 系统托盘菜单(`lib/common/tray.dart`、`lib/manager/tray_manager.dart`,以及内置 `plugins/tray_manager` 插件的 macOS 侧)。

### 新增
- **延迟徽章** —— 节点项右侧显示彩色延迟徽章:
  - 🟢 **绿色**:`< 200ms`
  - 🟠 **橙色**:`200–499ms`
  - 🔴 **红色**:`≥ 500ms` 或测速失败
- **选中标记** —— 当前选中的节点旁边显示 `✓`。
- **分组子菜单标签** —— 组的子菜单标题右侧显示该组当前选中的节点名(`组名        当前选中节点`)。
- **测速进行中占位** —— 点"延迟测试"后,整个分组的节点徽章**立刻全部变成 `...`**,等真实结果回来再陆续刷成数字 / fail,看得出测试在跑。

### 文案改动
- `timeout` 改为更短的 **`fail`** —— 适合徽章这种小区域显示。

### 修复
- **带延迟标签的节点之前点不动**。自定义的右对齐 `NSView`(用来渲染 `name\tdelay` 这种带 tab 的标签)把鼠标事件吞掉了。现在 `mouseUp` 会正确派发,节点能正常选中。
- **测速结束后菜单会自动关闭**。原来的刷新路径走 `cancelContextMenu` → 重建 → `popUpContextMenu`,但在 macOS 上重新弹出不可靠。现在保持打开。
- **菜单开着时后台刷新会让已显示菜单的点击失效**。原来每次重建都会重新分配 `MenuItem` id,显示中的 `NSMenu` 的 tag 跟 Dart 端对不上,点击就被吃掉。现在两层都保留身份:
  - Plugin 的 Dart 端,如果新菜单和旧菜单**形状一致**就**原地合并**字段进现有 `_menu`,**id 不变**。
  - macOS 端**原地更新现有 `NSMenuItem` 的 view 内容**而不是重建整个菜单,所以已经展示中的菜单徽章也能实时刷新。

### 行为
- 托盘菜单**只在用户主动触发的测速完成后**才刷新(托盘点击 or dashboard 触发)。核心后台健康检查产生的延迟事件**故意不监听**,避免刚测出来的好结果几秒后被瞬时失败覆盖。

---

## 编译

需要 Flutter(对应 `pubspec.yaml` 的 `environment.sdk` 版本)和 Xcode。

```bash
flutter build macos --release
```

产物路径:`build/macos/Build/Products/Release/FClash Plus.app`

预编译 DMG 在每个 [GitHub Release](https://github.com/zhangbaoshengrio/fclash-plus/releases) 里都有附件。

macOS 核心二进制 `libclash/macos/FlClashCore` 已经包含在仓库中,编译 macOS 端不需要 Go 工具链。

---

## TUN 模式说明

第一次开 TUN 模式时,macOS 会弹一次管理员密码框 —— 给 `FlClashCore` 加 `setuid`,让核心能配置 `utun` 接口。跟上游 FlClash 一样。

bundle id 故意改成了 `com.zhangbaosheng.fclash-plus`,这样 FClash Plus 和原版 FlClash 可以**并存安装**,不会在 `LaunchServices` 路由、偏好设置、`utun` 设备这些地方互相冲突。

---

## 协议

继承自上游 FlClash —— 原始协议条款见 [chen08209/FlClash](https://github.com/chen08209/FlClash)。

---

## 致谢

强烈感谢 [chen08209](https://github.com/chen08209) 这个优秀的原项目。本仓库只是在上面做了一些个人小修改而已。
