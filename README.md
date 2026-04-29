# Lazycli

[[简体中文](docs/README.zh_CN.md)]

A cross-platform command-line tool that translates natural language input into executable shell commands using LLMs.

---

## Overview

This project provides a CLI wrapper that captures user intent in natural language and converts it into valid shell commands via an LLM backend. It supports multiple platforms and can be integrated into common shells (bash, zsh, fish, PowerShell).

## Features

- Cross-platform support (Windows, Linux, macOS, *BSD)
- Natural language to shell command translation
- Pluggable LLM backend support
- Configurable prompt templates
- Optional command preview before execution
- Safety guardrails for dangerous operations

## Installation

### From Source

```shell
git clone https://github.com/tabris17/lazycli
cd lazycli
nimble release
```

### Download

the latest release from:

```text
https://github.com/tabris17/lazycli/releases
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
