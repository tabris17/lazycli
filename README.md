# Lazycli

[[简体中文](docs/README.zh_CN.md)]

A cross-platform command-line tool that converts natural language into shell commands using LLMs.

It bridges user intent and the shell environment by generating commands through an LLM backend and requiring explicit user confirmation before execution for safety.

## Features

- Cross-platform support (Windows, Linux, macOS, BSD)
- Compatible with multiple shells (bash, fish, nushell, zsh, PowerShell)
- Flexible LLM backend support via OpenAI-compatible APIs
- Configurable prompt templates
- Interactive command confirmation before execution

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

Run script blow:

```nushell
mkdir ($nu.data-dir | path join "vendor/autoload")
lazycli init nushell | save -f ($nu.data-dir | path join "vendor/autoload/lazycli.nu")
```

### PowerShell

Add the following to the end of your PowerShell configuration (find it by running `$PROFILE`):

```powershell
Invoke-Expression (&lazycli init powershell)
```

### Zsh

Add the following to the end of `~/.zshrc`:

```zsh
eval "$(lazycli init zsh)"
```

## Usage

## Configuration File

Default location:

- Linux/macOS: `~/.config/lazycli/config.toml`
- Windows: `%USERPROFILE%\.config\lazycli\config.toml`

## Supported LLM Backends

Currently supported:

- OpenAI-compatible APIs

## License

MIT License
