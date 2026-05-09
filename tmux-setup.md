# Tmux 配置说明

## 配置文件

- **主配置**：`~/.tmux.conf`（本仓库 `.tmux.conf` 同步）
- **Kaku 集成**：`~/.config/kaku/tmux/kaku.tmux.conf`（Kaku 自动管理，勿手动改）
- **插件目录**：`~/.tmux/plugins/`
- **会话快照**：`~/.local/share/tmux/resurrect/`
- **原始备份**：`~/.tmux.conf.bak.20260509-103455`

## 基础操作

**Prefix 键**：`C-a`（即 `Ctrl+a`，替换了默认的 `C-b`）

| 操作 | 快捷键 |
|---|---|
| 水平分屏 | `C-a v` |
| 垂直分屏 | `C-a h` |
| 切换 pane | `Alt+方向键` |
| 切换 window | `Shift+左/右` |
| 重载配置 | `C-a r` |

## 鼠标复制（macOS）

已配置 `set -g mouse on` + `pbcopy`，三种复制方式：

| 方式 | 操作 | 说明 |
|---|---|---|
| 鼠标拖拽 | 拖拽选中文字，松开即复制 | `⌘V` 粘贴，最常用 |
| vi 模式 | `C-a [` 进入 → 选中 → 按 `y` | 适合精确选择大段文本 |
| 手动 buffer | `C-a C-c` 复制 / `C-a C-v` 粘贴 | tmux buffer ↔ 系统剪贴板 |

**关键配置项**：
- `set -g set-clipboard on`：启用 OSC52 剪贴板通道
- `MouseDragEnd1Pane → copy-pipe-and-cancel pbcopy`：拖拽松开自动进剪贴板
- tmux 3.2+ 不需要 `reattach-to-user-namespace`，直接用 `pbcopy`

## 会话自动保存与恢复

基于 [知乎文章方案](https://zhuanlan.zhihu.com/p/146544540)，三个插件协作：

| 插件 | 作用 |
|---|---|
| `tpm` | 插件管理器 |
| `tmux-resurrect` | 保存/恢复会话到磁盘 |
| `tmux-continuum` | 定时自动保存 + 启动自动恢复 |

**配置参数**：
- `@continuum-save-interval 15`：每 15 分钟自动保存
- `@continuum-restore on`：tmux 启动时自动恢复上次会话
- `@resurrect-capture-pane-contents on`：同时保存 pane 显示内容

**快捷键**：

| 操作 | 快捷键 |
|---|---|
| 手动保存会话 | `C-a C-s` |
| 手动恢复会话 | `C-a C-r` |
| 安装新插件 | `C-a I`（大写） |

**日常使用**：
- 平时在 tmux 里干活，continuum 每 15 分钟自动保存
- 关机/重启后执行 `tmux a`，自动恢复所有 session、窗口、pane、工作目录
- `tmux ls` 报 `no server running` 是正常的（没启动 tmux server 而已，不是 bug）

## 首次安装步骤

```bash
# 1. 复制配置文件
cp ~/config/.tmux.conf ~/.tmux.conf

# 2. 安装 tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# 3. 启动 tmux 并安装插件
tmux
# 在 tmux 内按 C-a I 安装插件
# 或命令行：~/.tmux/plugins/tpm/bin/install_plugins
```
