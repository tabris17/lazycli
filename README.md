# Lazycli

[[简体中文](docs/README.zh_CN.md)]

A cross-platform command-line tool that converts natural language into shell commands using LLMs, bridging user intent and the shell environment with explicit user confirmation before execution for safety.

## Features

- Cross-platform support (Windows, Linux, macOS, BSD)
- Works seamlessly across popular shells (bash, fish, nushell, zsh, PowerShell)
- Flexible LLM backend support via OpenAI-compatible APIs
- Configurable prompt templates
- Interactive command confirmation before execution
- Lightweight and token-efficient for low-cost usage

## Installation

### From Source

```shell
git clone https://github.com/tabris17/lazycli
cd lazycli
nimble setup
nimble release
```

### Download

Get the latest release from:

```text
https://github.com/tabris17/lazycli/releases
```

## Integration

Configure your shell to initialize lazycli. Select yours from the list below:

### Bash

Add the following to the end of `~/.bashrc`:

```bash
eval "$(lazycli init bash)"
```

If you are running Bash on Windows (e.g., Git Bash, MSYS2), add the `--posix-path` flag to ensure correct path handling:

```bash
eval "$(lazycli init --posix-path bash)"
```

### Fish

Add the following to the end of `~/.config/fish/config.fish`:

```fish
lazycli init fish | source
```

### Nushell

Run the following code in nushell:

```nushell
mkdir ($nu.data-dir | path join "vendor/autoload")
lazycli init nushell | save -f ($nu.data-dir | path join "vendor/autoload/lazycli.nu")
```

### PowerShell

Add the following to the end of your PowerShell profile, which you can open by running `notepad $PROFILE`:

```powershell
Invoke-Expression (& { lazycli init powershell | Out-String })
```

### Zsh

Add the following to the end of `~/.zshrc`:

```zsh
eval "$(lazycli init zsh)"
```

### Advanced

`lazycli init` supports the following options:

- `--config`: Specifies the configuration file to use
- `--posix-path`: Forces the init shell script to use POSIX path separators. Useful for portable versions of Bash running on Windows
- `-p, --proxy`: Specifies the proxy URL (overrides config and environment variables)

## Usage

First, initialize the configuration file using the following command:

```shell
lazycli config init
```

Follow the prompts to complete the setup step by step. To overwrite an existing configuration, use the `--force` option.

Make sure your shell has loaded the initialization script. At the command prompt, type a natural language description of the command you want to execute. For example: `list all files`.

Then press the configured hotkey (default is <kbd>F1</kbd>) to invoke lazycli. After the command is processed, the content at the command prompt will be automatically replaced with an executable shell command.

## Configuration

Default configuration file locations:

- Linux/macOS: `~/.config/lazycli/config.toml`
- Windows: `%USERPROFILE%\.config\lazycli\config.toml`

You can also run `lazycli config` to locate the configuration file path.

### Custom Prompt

Optionally, you can add a `prompt` field to `config.toml` to inject additional instructions. This custom prompt is **not a replacement** for the built-in system prompt — instead, it is sent as a separate message (role `"system"`) in the API request, placed before the runtime context. This allows you to guide the LLM with extra context or constraints without affecting the core instruction template.

```toml
prompt = "Prefer PowerShell cmdlets over native executables when possible."
```

[Preview the full rendered messages](src/lazycli/config.nim) to see exactly what is sent to the model.

## Supported LLM Backends

Currently supported:

- OpenAI-compatible APIs

## License

MIT License
