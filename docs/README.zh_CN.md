# Lazycli

[[English](../README.md)]

一款跨平台命令行工具，利用 LLM 将自然语言转换为 shell 命令。在执行前会要求用户显式确认，兼顾便利与安全。

## 特性

- 跨平台支持（Windows、Linux、macOS、BSD）
- 兼容主流 shell（bash、fish、nushell、zsh、PowerShell）
- 通过 OpenAI 兼容 API 灵活接入多种 LLM 后端
- 可自定义提示词模板
- 交互式命令确认后再执行
- 轻量高效，token 消耗低

## 安装

### 源码编译

```shell
git clone https://github.com/tabris17/lazycli
cd lazycli
nimble setup
nimble release
```

### 下载预编译版本

从以下地址获取最新版本：

```text
https://github.com/tabris17/lazycli/releases
```

## 集成

将 lazycli 集成到你的 shell 中。请根据使用的 shell 选择以下方式：

### Bash

在 `~/.bashrc` 末尾添加：

```bash
eval "$(lazycli init bash)"
```

如果你在 Windows 上运行 Bash（例如 Git Bash、MSYS2），请加上 `--posix-path` 参数以确保路径处理正确：

```bash
eval "$(lazycli init --posix-path bash)"
```

### Fish

在 `~/.config/fish/config.fish` 末尾添加：

```fish
lazycli init fish | source
```

### Nushell

在 nushell 中执行以下命令：

```nushell
mkdir ($nu.data-dir | path join "vendor/autoload")
lazycli init nushell | save -f ($nu.data-dir | path join "vendor/autoload/lazycli.nu")
```

### PowerShell

在 PowerShell 配置文件末尾添加（运行 `notepad $PROFILE` 可打开配置文件）：

```powershell
Invoke-Expression (& { lazycli init powershell | Out-String })
```

### Zsh

在 `~/.zshrc` 末尾添加：

```zsh
eval "$(lazycli init zsh)"
```

### 进阶选项

`lazycli init` 支持以下选项：

- `--config`：指定要使用的配置文件
- `--posix-path`：强制初始化脚本使用 POSIX 路径分隔符。适用于 Windows 上的便携版 Bash
- `-p, --proxy`：指定代理 URL（优先级高于配置文件和环境变量）

## 使用方法

首先执行以下命令初始化配置文件：

```shell
lazycli config init
```

按照提示逐步完成设置。如需覆盖已有配置文件，可使用 `--force` 选项。

确保 shell 已加载初始化脚本。在命令提示符中输入你想执行命令的自然语言描述，例如 `list all files`。

然后按下配置的热键（默认为 <kbd>F1</kbd>）调用 lazycli。处理完成后，命令提示符中的内容会自动替换为可执行的 shell 命令。

## 配置

默认配置文件路径：

- Linux/macOS：`~/.config/lazycli/config.toml`
- Windows：`%USERPROFILE%\.config\lazycli\config.toml`

你也可以运行 `lazycli config` 来定位配置文件路径。

### 自定义提示词

你可以在 `config.toml` 中可选地添加 `prompt` 字段来注入额外指令。该自定义提示词**不会替换**内置系统提示词，而是作为一条独立的 `{"role": "user"}` 消息发送至 API 请求中，位于你的实际查询之前。这使你能在不影响核心指令模板的前提下，为 LLM 提供额外的上下文或约束。

```toml
prompt = "尽可能优先使用 PowerShell cmdlet，而非本机可执行文件。"
```

运行 `lazycli prompt` 可预览完整渲染后的系统提示词，查看实际发送给模型的内容。

## 支持的 LLM 后端

目前已支持：

- OpenAI 兼容 API

## 许可证

MIT 许可证