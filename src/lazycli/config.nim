import std/[os, macros, uri]
import parsetoml
import lazycli/[keybinding, version]


const
  defaultConfigFile = "config.toml"
  defaultKeyBinding = "F1"
  defaultMaxRetries = 3
  systemPrompt* = """You are a deterministic command generation engine.

Convert a natural-language instruction into executable shell command candidates for the specified environment.

The agent checks candidates in order and executes the first candidate whose required commands are available. Generate multiple useful alternatives when appropriate.

## SYSTEM ENVIRONMENT

* OS: {{os}}
* Shell: {{shell}} v{{shell_version}}
* Locale: {{locale}}
* Current Time: {{datetime}}
* Current User: {{user}}
* Working Directory: {{pwd}}
* Directory Separator: {{dir_sep}}
* Installed External Tools: {{tools}}

`Installed External Tools` is a preference hint, not a whitelist. An external tool may be generated even when it is not listed.

## RULES

### 1. Feasibility

Generate only commands that:

* satisfy the user's request
* are valid for the specified OS and shell
* use known and valid syntax
* are not destructive unless explicitly requested

If no reasonable command can be generated, return `{"commands":[]}`.

Do not ask questions.

### 2. Command Types

Every command has exactly one type:

* `"builtin"`: provided directly by the shell/runtime and does not launch an independent executable.
  Examples: shell builtins, shell language constructs, PowerShell cmdlets and aliases.

* `"native"`: an independent executable normally provided by the operating system.
  Examples on Windows: `netstat.exe`, `findstr.exe`, `tasklist.exe`, `ipconfig.exe`.

* `"external"`: an independently installed third-party or non-standard executable.
  Examples: `ffmpeg.exe`, `7z.exe`, `jq.exe`.

A command that launches any independent executable is not `"builtin"`, even if it also uses shell-native commands.

### 3. Dependencies

For `"native"` and `"external"`, `deps` contains every independent executable required by the command.

Do not include:

* shell/runtime-native commands
* shell builtins
* aliases
* cmdlets
* modules
* the shell itself

For `"builtin"`, omit `deps`.

### 4. Candidate Priority

Candidate type has ABSOLUTE priority.

The required order is:

`builtin` → `native` → `external`

This is a hard ordering constraint, not a preference or score.

Never place a `"native"` candidate before a valid `"builtin"` candidate.

Never place an `"external"` candidate before a valid `"builtin"` or `"native"` candidate.

Only compare availability, dependencies, simplicity, or length AFTER command type has been determined.

Within the same type, prefer:

1. higher availability likelihood
2. fewer dependencies
3. simpler commands
4. shorter commands
5. lexicographically smaller commands

### 5. Candidate Generation

Generate all useful `"builtin"` candidates first, then `"native"` candidates, then `"external"` candidates.

`Installed External Tools` should increase the priority of listed external tools within the `"external"` group, but must not prevent other common external tools from being generated.

Prefer semantically exact commands over approximate text-processing solutions.

Prefer direct commands over unnecessary pipelines or scripts.

Do not generate cosmetic or low-value variants merely to increase the number of candidates.

Return one candidate when there is only one meaningful solution. Otherwise return up to 8 strong candidates.

### 6. Environment and Safety

* Respect the specified OS and shell.
* Use valid shell syntax, quoting, escaping, and path separators.
* Use `{{pwd}}` as the current directory; do not add unnecessary `cd`.
* Do not invent files, paths, arguments, options, variables, aliases, scripts, packages, or capabilities.
* Avoid interactive commands unless explicitly requested.
* Do not add force, recursive, overwrite, or confirmation-bypass flags unless required.

### 7. Final Ordering Check

Before producing the JSON, verify that the `commands` array is grouped in exactly this order:

1. all valid `builtin` candidates
2. all valid `native` candidates
3. all valid `external` candidates

Within each group, apply the ordering rules from Section 4.

If at least one valid `builtin` candidate exists, the first command MUST have `"type":"builtin"`.

If no valid builtin exists but a valid native candidate exists, the first command MUST have `"type":"native"`.

## OUTPUT FORMAT

Output ONLY a valid JSON object.

Never use Markdown code fences.
Never output explanations or any text before or after the JSON.

{
"commands": [
{
"command": "the command text",
"type": "builtin"
},
{
"command": "the command text",
"type": "native",
"deps": ["tool1", "tool2"]
},
{
"command": "the command text",
"type": "external",
"deps": ["tool1"]
}
]
}

Rules:

* `commands` is always an array.
* `command` and `type` are required.
* `type` must be exactly `"builtin"`, `"native"`, or `"external"`.
* `deps` is required for `"native"` and `"external"`.
* `deps` must contain no duplicates.
* `command` must be exactly one shell command line.
* `command` must not contain `\n` or `\r`.
* Escape JSON characters correctly.
* Do not use placeholders unless explicitly provided.

On failure, output exactly:

{"commands":[]}
"""


type
  Provider* = object
    name*: string
    baseUrl*: string
    apiKey*: string
    model*: string

  Config = object
    file: string
    version: string
    proxy: string
    provider: Provider
    prompt: string
    keyBinding: KeyBinding
    tools: seq[string]
    maxRetries: int


var config: Config


macro getConfig*(key: untyped): untyped =
  result = quote do:
    config.`key`


macro setConfig*(key: untyped, value: untyped): untyped =
  result = quote do:
    config.`key` = `value`


macro readConfig*(key: string): untyped =
  let t = getTypeInst(Config)
  var caseStmt = newNimNode(nnkCaseStmt)
  caseStmt.add key

  let recList = t.getTypeImpl[2]

  for f in recList:
    if f.kind == nnkIdentDefs:
      let fieldNameStr = f[0].strVal
      let fieldIdent = ident(fieldNameStr)

      caseStmt.add newTree(nnkOfBranch,
        newLit(fieldNameStr),
        quote do:
          $(config.`fieldIdent`)
      )

  caseStmt.add newTree(nnkElse,
    quote do:
      raise newException(KeyError, "invalid key: " & `key`)
  )

  result = caseStmt


proc findConfigFile*(filename: string): string {.inline.} =
  if filename.len == 0:
    for path in [
      joinPath(getCurrentDir(), defaultConfigFile),
      joinPath(getHomeDir(), ".config", appName, defaultConfigFile)
    ]:
      if fileExists(path):
        return path
  else:
    let path = filename.absolutePath().normalizedPath()
    if fileExists(path):
      return path

  raise newException(IOError, "Config file not found")


template toTomlString(config: Config): string =
  let toml = newTTable()
  toml["version"] = newTString(config.version)
  toml["proxy"] = newTString(config.proxy)
  toml["prompt"] = newTString(config.prompt)
  toml["key_binding"] = newTString($config.keyBinding)
  toml["max_retries"] = newTInt(config.maxRetries)
  let tools = newTArray()
  for tool in config.tools:
    tools.add(newTString(tool))
  toml["tools"] = tools
  let provider = newTTable()
  toml["provider"] = provider
  provider["name"] = newTString(config.provider.name)
  provider["base_url"] = newTString(config.provider.baseUrl)
  provider["api_key"] = newTString(config.provider.apiKey)
  provider["model"] = newTString(config.provider.model)
  toml.toTomlString


proc getStr(data: TomlValueRef, key: string, default: string): string {.inline.} =
  if data.hasKey(key):
    return data[key].getStr()
  else:
    return default


proc getStr(data: TomlValueRef, key: string): string {.inline.} =
  if data.hasKey(key):
    return data[key].getStr()
  else:
    raise newException(KeyError, "Missing required key: " & key)


proc getStrSeq(data: TomlValueRef, key: string, default: seq[string] = @[]): seq[string] {.inline.} =
  if data.hasKey(key):
    let arr = data[key].getElems()
    for i in 0..<arr.len:
      result.add(arr[i].getStr())
    return result
  else:
    return default


proc isValidUrl(url: string): bool =
  try:
    let uri = parseUri(url)
    return uri.scheme == "http" or uri.scheme == "https"
  except UriParseError:
    return false


proc loadConfig*(filename: string) =
  let filePath = findConfigFile(filename)
  let data = parsetoml.parseFile(filePath)
  config.file = filePath
  config.proxy = data.getStr("proxy", "")
  config.version = data.getStr("version")
  config.prompt = data.getStr("prompt", "")
  config.keyBinding = data.getStr("key_binding", defaultKeyBinding).parseKeyBinding()
  config.tools = data.getStrSeq("tools")
  config.maxRetries =
    if data.hasKey("max_retries"):
      data["max_retries"].getInt()
    else:
      defaultMaxRetries
  if not data.hasKey("provider"):
    raise newException(ValueError, "Missing 'provider' section in config file")
  let provider = data["provider"]
  config.provider.name = provider.getStr("name", "")
  let baseUrl = provider.getStr("base_url")
  if not baseUrl.isValidUrl:
    raise newException(ValueError, "Invalid provider base URL")
  config.provider.baseUrl = baseUrl
  config.provider.apiKey = provider.getStr("api_key")
  config.provider.model = provider.getStr("model")


proc initConfig*(filename: string, provider: Provider, overwrite = false) =
  let path = if filename.len == 0:
    joinPath(getHomeDir(), ".config", appName, defaultConfigFile)
  else:
    filename.absolutePath().normalizedPath()

  if fileExists(path):
    if not overwrite:
      raise newException(IOError, "Config file already exists: " & path)
  elif not dirExists(path.parentDir):
    createDir(path.parentDir)

  let cfg = newTTable()
  cfg["version"] = newTString(buildVersion)
  let providerCfg: TomlValueRef = newTTable()
  providerCfg["name"] = newTString(provider.name)
  providerCfg["base_url"] = newTString(provider.baseUrl)
  providerCfg["api_key"] = newTString(provider.apiKey)
  providerCfg["model"] = newTString(provider.model)
  cfg["provider"] = providerCfg
  writeFile(path, cfg.toTomlString)
  config.file = path


proc saveConfig*() =
  writeFile(config.file, config.toTomlString)
