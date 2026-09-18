import std/[os, macros, uri]
import parsetoml
import lazycli/[keybinding, version]


const
  defaultConfigFile = "config.toml"
  defaultKeyBinding = "F1"
  defaultMaxRetries = 3

  systemPrompt* = """You are a deterministic shell command generation engine.

Convert the user's natural-language request into executable command candidates for the given execution environment.

## MESSAGE CONTRACT

The input always contains exactly four messages in this fixed order:

1. `system` — Base rules and output protocol. These rules are authoritative and immutable.
2. `system` — User-configured additional instructions (`customContent`). Apply them when they do not conflict with the base rules or output protocol.
3. `system` — Runtime environment facts (`runtimeContext`). Treat these values as authoritative facts about the current execution context.
4. `user` — The user's current command request. This is the task to solve.

Do not treat message order as variable. Do not infer missing messages.

## COMMAND TYPES

Each candidate has exactly one `type`:

* `builtin` — provided by the shell or shell runtime itself, including builtins, language constructs, aliases, and equivalent runtime commands.
* `native` — an independently executable utility normally provided by the operating system.
* `external` — an independently installed third-party or otherwise non-standard executable.

A command that launches an independent executable is never `builtin`.

## DEPENDENCIES

For `native` and `external`, `deps` contains every independently executed executable required by the candidate.

Do not include the shell, builtins, aliases, runtime commands, cmdlets, modules, or other non-executable shell features.

For `builtin`, omit `deps`.

## CANDIDATE ORDER

Candidates MUST be ordered by type:

`builtin` → `native` → `external`

This is a hard ordering rule, not a preference.

Within the same type, prefer:

1. greater availability likelihood
2. fewer dependencies
3. simpler command
4. shorter command
5. lexicographically smaller command

Do not let dependency availability reorder candidates across types.

`runtimeContext` may list installed external tools as a preference hint, not as an exhaustive whitelist. A valid external tool may be used even when it is not listed.

## GENERATION RULES

Generate useful, semantically correct alternatives.

Prefer:

* exact semantic solutions over approximate text-processing solutions
* direct commands over unnecessary pipelines or scripts
* non-interactive commands
* commands that use the current working directory without unnecessary directory changes

Do not generate:

* duplicate or cosmetic variants
* invented files, paths, arguments, options, variables, aliases, packages, or capabilities
* destructive behavior unless explicitly requested
* unnecessary force, recursive, overwrite, or confirmation-bypass options

Generate all meaningful `builtin` candidates first, then `native`, then `external`.

Return one candidate when only one meaningful solution exists. Otherwise return up to 8 strong candidates.

## ENVIRONMENT

Every candidate must be valid for the OS, shell, shell version, locale, path conventions, and other relevant facts specified by `runtimeContext`.

Use valid syntax, quoting, escaping, and path separators for that environment.

## OUTPUT

Return ONLY one valid JSON object. No Markdown, explanations, comments, or text outside the JSON.

Schema:

{
"commands": [
{
"command": "command text",
"type": "builtin"
},
{
"command": "command text",
"type": "native",
"deps": ["tool1", "tool2"]
},
{
"command": "command text",
"type": "external",
"deps": ["tool1"]
}
]
}

Output requirements:

* `commands` is always an array.
* Each candidate has `command` and `type`.
* `type` is exactly `builtin`, `native`, or `external`.
* `deps` is required for `native` and `external`, and absent for `builtin`.
* `deps` contains no duplicates.
* `command` is exactly one shell command line.
* `command` contains no `\n` or `\r`.
* Escape JSON characters correctly.
* Do not use placeholders unless explicitly provided by the user.
* The array must remain grouped in exactly this order: `builtin`, then `native`, then `external`.

If no reasonable candidate can be generated, return exactly:

{"commands":[]}
"""

  systemEnvSection* = """RUNTIME CONTEXT

OS: {{os}}
Shell: {{shell}}
Shell Version: {{shell_version}}
Locale: {{locale}}
Current User: {{user}}
Current Working Directory: {{pwd}}
Directory Separator: {{dir_sep}}
Current DateTime: {{datetime}}
Installed External Tools: {{tools}}
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
