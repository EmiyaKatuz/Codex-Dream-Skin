# Codex Dream Skin

为官方 Codex Desktop 提供的本地动态主题。主题通过仅绑定本机回环地址的 CDP 注入到 `app://` 渲染页，不修改 `app.asar`、安装目录、应用签名或 Codex 配置。

当前仓库包含 Windows、macOS 和 Linux 实现；Linux 版本已作为一等构建目标提供。

## Linux 快速开始

要求：已安装官方 Codex Desktop、Node.js 20+、`bash`、`curl`、`tar`、`pgrep`。首次安装前请关闭 Codex。

```bash
git clone https://github.com/Edward334/Codex-Dream-Skin.git
cd Codex-Dream-Skin
./linux/scripts/install-dream-skin-linux.sh
```

安装器会复制稳定运行时到 `~/.codex/codex-dream-skin-linux`，并把主题状态和日志保存到 `${XDG_STATE_HOME:-~/.local/state}/CodexDreamSkin`。随后使用以下命令管理：

```bash
# 启动或重新应用主题
~/.codex/codex-dream-skin-linux/scripts/start-dream-skin-linux.sh

# 仅验证当前窗口是否已经注入
~/.codex/codex-dream-skin-linux/scripts/verify-dream-skin-linux.sh

# 移除当前窗口主题并停止注入器
~/.codex/codex-dream-skin-linux/scripts/restore-dream-skin-linux.sh
```

Linux 启动器会从 `codex-desktop` 或 `/usr/share/applications/Codex.desktop` 发现官方客户端。如采用其他安装方式，可在执行前指定：

```bash
CODEX_APP_BIN=/absolute/path/to/codex-desktop \
  ./linux/scripts/install-dream-skin-linux.sh
```

## Linux 构建

构建无需联网，也不会包含 Git 元数据：

```bash
./linux/scripts/build-release.sh
```

输出为 `linux/release/CodexDreamSkin-Linux-v1.3.5.tar.gz` 及同目录 SHA-256 文件。解压后运行归档内的 `scripts/install-dream-skin-linux.sh` 即可部署。

## 安全边界

- CDP 强制使用 `127.0.0.1`，不会暴露到局域网。
- 注入器仅接受 `app://` 页面目标。
- 背景图限制为 16 MiB、单边 16384 px、总计 5000 万像素。
- 不读取或改写 API Key、模型供应商、账号信息及 `~/.codex/config.toml`。
- `restore` 仅停止记录在状态文件中的注入器，并从当前窗口卸载主题。

## 其他平台

- Windows：[`windows/README.md`](./windows/README.md)
- macOS：[`macos/README.md`](./macos/README.md)
- Linux 详细说明：[`linux/README.md`](./linux/README.md)

## 许可与声明

本项目不是 OpenAI 官方产品。Codex 及相关商标归其权利人所有；主题素材、人物/IP 内容的使用与再分发需自行确认授权。
