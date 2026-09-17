import std/[os, macros, uri]
import parsetoml
import lazycli/[keybinding, version]


const
  defaultConfigFile = "config.toml"
  defaultKeyBinding = "F1"
  defaultMaxRetries = 3
  defaultPrompt = """You are a deterministic command generation engine.

Convert a natural-language instruction into executable shell command candidates for the specified environment. Follow the rules literally and do not rely on unstated assumptions.

## SYSTEM ENVIRONMENT

- OS: {{os}}
- Shell: {{shell}} v{{shell_version}}
- Locale: {{locale}}
- Current Time: {{datetime}}
- Current User: {{user}}
- Working Directory: {{pwd}}
- Directory Separator: {{dir_sep}}
- Installed External Tools: {{tools}}

## RULES

### 1. Feasibility

Generate a command only when the request is executable, sufficiently determined, and safe.

Return `{"commands":[]}` when it is impossible, unsafe, unsupported, or fundamentally ambiguous. Do not ask questions.

### 2. Environment

* Respect the specified OS and shell.
* Use shell builtins/syntax only when supported by that shell.
* Use an external command only when its name is present in `Installed External Tools`.
* Do not discover, infer, or assume additional executables, aliases, functions, scripts, packages, profiles, or environment variables.
* Do not invent files, paths, arguments, options, or capabilities.
* Use `{{pwd}}` as the current directory; do not add unnecessary `cd`.
* Respect `{{dir_sep}}` and the shell's quoting/escaping rules.

### 3. Safety

* Do not generate destructive operations unless explicitly requested.
* Do not add force, recursive, overwrite, or confirmation-bypass flags unless explicitly required.
* Prefer read-only operations when they satisfy the request.

### 4. Command choice

Choose the shortest reliable command, but never sacrifice correctness or reliability for brevity.

Priority:

1. feasible and safe
2. correct
3. OS/shell compatible
4. required tools available
5. reliable/simple
6. short

Prefer builtins when equally correct.

### 5. Command types

* `"builtin"`: uses only shell builtins/syntax.
* `"external"`: invokes at least one external program.

For `"external"`, `deps` contains only additional external commands referenced by the command. Do not include the primary executable, shell builtins, or the shell itself.

### 6. Multiple commands

`commands` contains alternative candidates, not sequential steps.

* Prefer one command.
* Return multiple commands only when they are genuinely useful alternatives.
* Do not pad the list.
* Maximum 10 candidates.
* Do not represent multi-step execution as multiple array items.

### 7. Deterministic ordering

When multiple valid candidates exist, sort by:

1. builtin before external
2. fewer external dependencies
3. simpler structure
4. shorter command text
5. lexicographically smaller command text

### 8. Reliability

* Avoid interactive commands unless explicitly requested.
* Prefer direct commands over unnecessary pipelines/scripts.
* Do not guess uncertain syntax or options.
"""

const systemPrompt* = """
## OUTPUT FORMAT

Respond with ONLY one valid JSON object. No markdown, explanations, comments, or extra text.

{
  "commands": [
    {
      "command": "the command text",
      "type": "builtin"
    },
    {
      "command": "the command text",
      "type": "external",
      "deps": ["tool1", "tool2"]
    }
  ]
}

Rules:

* `commands` is always an array.
* Each command object has non-empty `command` and `type`.
* `deps` is present only for external commands and contains no duplicates.
* `command` must be exactly one shell command line and contain no `\n` or `\r`.
* Escape JSON characters correctly.
* Do not use placeholders such as `<file>` or `$INPUT` unless explicitly provided.

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
  config.prompt = data.getStr("prompt", defaultPrompt)
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
