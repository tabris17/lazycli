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

`lazy init` supports the following options:

- `--config`: Specifies the configuration file to use
- `--posix-path`: Forces the init shell script to use POSIX path separators. Useful for portable versions of Bash running on Windows

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

## Supported LLM Backends

Currently supported:

- OpenAI-compatible APIs

## License

MIT License
