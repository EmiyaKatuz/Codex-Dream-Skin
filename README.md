# Codex Dream Skin · 超天酱动态主题

<p align="center">
  <strong>为 Codex Desktop 制作的超天酱 / INTERNET ANGEL 沉浸式动态主题。</strong><br>
  原生控件换肤 · 动态像素装饰 · 本地主题管理 · 不修改官方安装包
</p>

<p align="center">
  <img src="windows/assets/dream-reference.jpg" alt="超天酱 INTERNET ANGEL 默认主题背景" width="900"><br>
  <sub>Windows 源码安装的默认主题素材；界面、动画与控件皮肤由运行时注入层生成</sub>
</p>

> 当前 fork 版本：`1.5.6`（2026-07-26）。主要开发与验证平台为 Windows；macOS 与 Linux 能力随上游及本 fork 的贡献继续维护。

Windows 与 macOS 安装包发布在本 fork 的 [GitHub Releases](https://github.com/EmiyaKatuz/Codex-Dream-Skin/releases)。

## 这是什么

这是基于 [Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin) 开发的独立 fork。当前版本围绕「超天酱 · INTERNET ANGEL」重新设计了 Windows Codex Desktop 的视觉、交互与主题管理体验。

侧栏、任务、建议卡、项目选择、输入框、设置和终端等 Codex 原生控件会直接呈现主题样式。主题通过仅绑定本机回环地址的 CDP 注入，不修改 `WindowsApps`、`app.asar`、应用签名或官方二进制。

本 fork 将作为独立项目继续开发。上游后续更新会按需同步，再以本项目的超天酱功能和视觉实现为准进行整合。

## 本 Fork 的主要改动

### 超天酱主题已固定为 Windows 源码安装的默认体验

源码安装首次初始化会自动创建三套可切换主题：

| 主题 | 资源 | 说明 |
|------|------|------|
| 超天酱 · INTERNET ANGEL | `theme.json` + `dream-reference.jpg` | 默认启用的 `2560 × 1440` JPEG 版 |
| 超天酱 · INTERNET ANGEL · Pixel Cafe | `theme-choten.json` + `codex-dream-skin-pixel-cafe.png` | 保留原始构图的无损 PNG 版 |
| Gothic Void Crusade | `windows/presets/preset-gothic-void-crusade/` | 随上游更新保留的附加预设 |

两套超天酱主题会以不同名称显示在托盘的「已保存主题」菜单中，不需要手动跨目录导入。

### 全界面视觉重制

- 以青色、粉色、紫色和像素霓虹为核心，统一首页、任务页和原生顶栏的视觉语言。
- 为首页加入 ANGEL COMMAND DECK 指令卡，并保留 Codex 原生输入和任务创建能力。
- 适配设置、插件、站点、计划任务、Pull Requests、选择工具栏和系统提示。
- 适配终端、侧边对话、变更摘要、编辑资源卡、子代理面板和 composer 菜单。
- 对窄窗口、矮窗口、侧栏展开、底部面板展开和双面板状态提供独立响应式布局。
- 保留原生控件的点击、滚动、键盘操作和可访问性行为；装饰层不拦截鼠标事件。

### 动画与状态表现

- 为超天酱背景加入与图片几何位置同步的眨眼、心跳、信号、粒子和直播状态装饰。
- 窗口缩放、侧栏收起或最大化时会重新计算动效位置，避免装饰与人物错位。
- 支持系统「减少动态效果」偏好，并在空间不足或面板展开时自动隐藏次要动画。
- 暂停、继续和重新应用主题时，会在 Codex 主界面显示 loading、成功或失败状态。

### 更完整的主题管理

- 使用专门设计的超天酱多尺寸像素托盘图标。
- 支持导入 PNG、JPEG、WebP 背景，并保存为本地主题。
- 支持从托盘快速切换已保存主题、暂停、继续、重新应用和完整恢复。
- 暂停会立即卸下当前窗口皮肤；继续会清除暂停状态并立即重新应用。
- watcher 会根据主题配置和图片内容修订值进行热更新，renderer 重载后仍能恢复当前主题。

### 合并的可靠性修复

- 收起或重建左侧栏时继续保留主题，避免短暂闪回 Codex 原生配色。
- 只在确认主 Codex 窗口后应用皮肤，宠物等透明辅助窗口会清理残留背景。
- DOM 主题刷新设有 `120ms` 最小间隔，文本匹配先于可见性测量，降低长会话中的重复扫描与布局读取。
- CDP WebSocket、domain enable、同步和异步事件回调均有独立异常边界，失败会完整释放 session。
- 暂停、恢复、renderer reload 与 watcher 退出会清理 fallback timer、监听器和持久化注入脚本。
- 主壳重建时会释放旧 `ResizeObserver` target；托盘菜单重建及退出会释放 WinForms 资源。
- 导入和注入前校验图片格式、尺寸、像素总量和文件大小。
- 主题仓库、状态文件、恢复流程和运行时替换保留原子写入与路径边界检查。

### 已整合的上游更新

当前分支已合并上游 `upstream/main` 的 `3aaaf7d`（上游版本 `1.5.5`），并纳入以下能力：

- Windows Inno Setup 安装器、版本检查、自动 Release 构建与覆盖更新支持。
- 主题 ZIP 导入、清单与 SHA-256 校验、Safe CSS 策略以及导入事务回滚。
- DreamSkin.cc Gallery、Studio 与社区主题一键应用链接。
- Codex Desktop 26.721+ 首页结构适配、原生窗口就绪检查和注入诊断。
- `tools/selectors.json` 选择器契约、统一运行时同步检查与 GitHub 自动测试。
- macOS 菜单栏应用、DMG 构建、主题 ZIP 工作流和社区主题恢复机制。
- Linux 安装、验证、恢复与发行归档脚本。

Windows 使用本 fork 的超天酱专属渲染覆盖层；macOS 使用通用运行时。各平台共享选择器契约、主题格式和注入安全边界。

### v1.5.6 合并与发行修复

- 合并上游 `v1.5.5` 以及本 fork 的 Linux、macOS 修复，解决文档、运行时、注入器和测试冲突。
- 保留超天酱 JPEG 主题作为 Windows 安装包与源码安装的默认主题，同时内置 Pixel Cafe 与 Gothic Void Crusade。
- 适配 Codex Desktop 26.721+ 的 `.home-banners` 首页结构，并为折叠侧栏和完整任务页补充稳定标记。
- 强化窗口、document 与 viewport 就绪验证，补充 renderer 清理、Safe CSS 部件标记和回归测试。
- Windows 打包过程会校验三套内置主题的 ID、图片映射与 SHA-256，防止发行阶段替换默认素材。
- 各平台版本源统一更新到 `1.5.6`，版本变更会触发 GitHub 自动构建、校验与 Release 发布。

## 快速安装（Windows）

### Release Setup（普通用户推荐）

Release 安装需要 Windows 10/11 x64，以及已注册到当前用户的 Microsoft Store 官方 `OpenAI.Codex` 应用。首次安装前请至少启动一次 Codex，随后退出 Codex 与旧版 Dream Skin 托盘。

1. 从本 fork 的 [Latest Release](https://github.com/EmiyaKatuz/Codex-Dream-Skin/releases/latest) 下载 `CodexDreamSkin-Setup-vX.Y.Z.exe` 和 `SHA256SUMS.txt`。
2. 对照校验文件确认 Setup.exe 的 SHA-256，再双击运行安装向导。
3. 保持默认的当前用户安装方式。安装过程不需要管理员权限。
4. 安装完成后，从开始菜单打开 `Codex Dream Skin`；安装向导也可以在结束时直接启动托盘。

Release Setup 内置经过固定版本与哈希校验的 Node.js 运行时。普通用户无需 clone 仓库、安装 Node.js 或手动执行 PowerShell 脚本。当前安装包尚未进行代码签名；若 SmartScreen 显示警告，请核对文件名、下载来源和 SHA-256，再选择「更多信息 → 仍要运行」。请保留 Defender、SmartScreen 和 Smart App Control 的现有安全设置。

图形安装器只创建开始菜单中的 `Codex Dream Skin` 入口，并提供可选的登录时启动项。它会把受管运行时安装到 `%LOCALAPPDATA%\CodexDreamSkin\engine`，主题和图片保存在 `%LOCALAPPDATA%\CodexDreamSkin`。详细说明见 [`docs/install-windows.md`](./docs/install-windows.md)。

图形安装包首次启用超天酱 JPEG 主题；超天酱 Pixel Cafe 与 Gothic Void Crusade 会加入「已保存主题」。

### 从源码安装（开发者与高级用户）

源码安装额外需要 `PATH` 中可用的 Node.js 22 或更高版本，以及 Windows PowerShell 5.1 或 PowerShell 7。在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\windows\scripts\install-dream-skin.ps1
```

源码安装会原子部署受管运行时、启动托盘，并在桌面创建 `Codex Dream Skin`、`Codex Dream Skin - Tray` 和 `Codex Dream Skin - Restore`；开始菜单会创建启动与托盘入口。安装完成后可以移动或删除当前源码目录，受管运行时仍会从 LocalAppData 工作。

源码安装首次启用超天酱 JPEG 主题，并保存 Pixel Cafe 与 Gothic Void Crusade 供托盘切换。

### 日常使用

Release 用户从开始菜单打开 `Codex Dream Skin`；源码安装用户也可以打开桌面的 `Codex Dream Skin - Tray`。托盘菜单支持：

- 切换安装包内置主题和用户保存的主题。
- 使用「更换背景图」导入自己的纯背景，再选择「保存当前主题」。
- 使用「导入主题 ZIP…」导入经过清单、大小、路径和 SHA-256 校验的主题包；导入完成后可从「已保存主题」启用。
- 打开 DreamSkin.cc Gallery 或 Studio 浏览、制作主题；受支持的社区主题链接可交给本机客户端确认并应用。
- 使用「暂停皮肤」立即恢复当前窗口的原生外观。
- 使用「继续显示皮肤」或「应用或重新应用」恢复主题。
- 使用「完全恢复 Codex」清理 Dream Skin 状态并回到官方外观。
- 手动检查本 fork 的最新 Release；该操作不会后台轮询、自动下载或静默安装。

导入图片必须是纯背景，不要使用包含窗口、侧栏、输入框、文字或按钮的效果截图。图片最大 `10 MB`，单边不超过 `16384` 像素，总像素不超过 `5000 万`。主题 ZIP 最大 `32 MiB`、最多 `32` 个条目，解压后最多 `64 MiB`；完整格式与安全规则见 [`docs/install-windows.md`](./docs/install-windows.md)。

## 更新与卸载

### Release Setup 更新

1. 退出 Dream Skin 托盘并关闭 Codex。
2. 下载最新 Setup.exe，并核对对应的 SHA-256。
3. 运行安装向导覆盖现有安装，再从开始菜单启动 `Codex Dream Skin`。

覆盖安装会保留活动主题、已保存主题、导入图片和配置备份。`v1.5.6` 使用新的语义版本号，托盘版本检查可以识别本次更新。

Release 用户可以从「设置 → 应用 → 已安装的应用」卸载 Codex Dream Skin。卸载器会先恢复 Codex 官方外观，并默认保留 `%LOCALAPPDATA%\CodexDreamSkin` 中的主题与图片。

### 源码安装更新

1. 退出 Dream Skin 托盘并关闭 Codex。
2. 拉取本 fork 的最新代码，或重新下载最新源码。
3. 重新运行 `install-dream-skin.ps1`，让运行时、安全检查和快捷方式一起更新。

源码安装用户可以使用 `Codex Dream Skin - Restore` 恢复官方外观。更完整的更新、恢复和自定义端口说明见 [`windows/README.md`](./windows/README.md)。

## macOS 安装

macOS 普通用户可以从 [Latest Release](https://github.com/EmiyaKatuz/Codex-Dream-Skin/releases/latest) 下载 `CodexDreamSkin-vX.Y.Z.dmg`，把 `Codex Dream Skin.app` 拖入 Applications 后启动。DMG 已包含所需运行时，无需安装 Node.js、Homebrew 或执行 shell 命令。

当前 macOS 安装包没有 Apple Developer ID 签名。首次打开遇到 Gatekeeper 提示时，请在「系统设置 → 隐私与安全性」核对并选择「仍要打开」，无需执行 `xattr` 或关闭 Gatekeeper。应用启动后可从菜单栏选择「安装 / 升级引擎」。完整步骤、更新和卸载方法见 [`docs/install-macos.md`](./docs/install-macos.md)。

## Linux 安装

Linux 支持目前仅在 AUR [`openai-codex-desktop`](https://aur.archlinux.org/packages/openai-codex-desktop) 包上测试。安装前请关闭 Codex，并确保系统已安装 Node.js 20 或更高版本，然后在仓库根目录运行：

```bash
./linux/scripts/install-dream-skin-linux.sh
```

安装完成后，从原 Codex 桌面图标启动即可自动加载主题。构建发行归档可运行 `./linux/scripts/build-release.sh`；安装、验证、恢复与自定义路径说明见 [`linux/README.md`](./linux/README.md)。

## 验证

运行 Windows 完整回归：

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\windows\tests\run-tests.ps1
```

检查最终注入 payload：

```powershell
node .\windows\scripts\injector.mjs --check-payload
```

测试覆盖主题播种与切换、图片及 ZIP 校验、Safe CSS、社区主题恢复、运行时替换、安装器静态检查、选择器契约、状态安全、暂停/恢复、侧栏折叠、响应式首页、原生窗口就绪、renderer 清理、payload revision 和 CDP 回环验证。

## 目录说明

| 路径 | 内容 |
|------|------|
| [`windows/assets/`](./windows/assets/) | 超天酱背景、托盘图标、CSS、renderer 注入代码和主题配置 |
| [`windows/scripts/`](./windows/scripts/) | 安装、启动、恢复、主题仓库、托盘与 CDP 注入逻辑 |
| [`windows/tests/`](./windows/tests/) | Windows 与 renderer 回归测试 |
| [`windows/installer/`](./windows/installer/) | Windows 图形安装器与 Release 构建配置 |
| [`windows/README.md`](./windows/README.md) | Windows 详细操作说明 |
| [`windows/CHANGELOG.md`](./windows/CHANGELOG.md) | 超天酱版本更新记录 |
| [`docs/platforms.md`](./docs/platforms.md) | 平台差异与主题格式说明 |
| [`macos/`](./macos/) | 继承并维护的上游 macOS 实现 |
| [`runtime/`](./runtime/) 与 [`tools/`](./tools/) | 上游通用运行时、选择器契约和诊断工具；Windows 主题保留专属覆盖层 |

## 未来计划

- 会加入更多动画，以显示不同状态下的差分（思考、输出等）
- 会随 Codex Desktop 主版本及原始项目更新作长期维护
- 更多的杂项修复

## 安全边界

- CDP 只绑定 `127.0.0.1`；主题运行期间不要执行来源不明的本机程序。
- 不修改 Codex 官方安装目录、`app.asar`、WindowsApps 内容或代码签名。
- 不读取或改写 API Key、Base URL 和模型供应商配置。
- 用户图片与主题配置保存在本机，不依赖外部 AI/API 分析。
- 可随时使用恢复脚本撤销主题并回到官方外观。

## 许可与声明

- 本项目沿用上游许可；详见 [`macos/LICENSE`](./macos/LICENSE) 与 [`macos/NOTICE.md`](./macos/NOTICE.md)。
- 非 OpenAI 官方产品；Codex 及相关权利归其权利人。
- 本主题/皮肤中所涉及的 IP 素材与商标权利归其权利人。
- 使用、公开展示或再分发人物、IP 素材与商标前，请自行确认所需授权。

## 致谢

- 原始项目：[Fei-Away/Codex-Dream-Skin](https://github.com/Fei-Away/Codex-Dream-Skin)
- Gothic Void Crusade 原创主题贡献者：[@seansong-ideogram](https://github.com/seansong-ideogram)

---

让 Codex 工作台成为超天酱的直播间。
