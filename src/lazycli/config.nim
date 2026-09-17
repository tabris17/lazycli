import std/[os, macros, uri]
import parsetoml
import lazycli/[keybinding, version]


const
  defaultConfigFile = "config.toml"
  defaultKeyBinding = "F1"
  defaultMaxRetries = 3
  defaultPrompt = """You are a deterministic command generation engine.

Your task is to convert a natural language instruction into executable shell commands.

## GUIDELINES

1. Prefer the shortest reliable command.
2. Avoid interactive commands unless explicitly requested.
3. Avoid destructive operations unless explicitly requested.
4. Commands MUST be compatible with the specified OS and shell.

## FAILURE HANDLING

If the request is impossible, unsafe, unsupported, or fundamentally ambiguous, indicate that no command can be generated.

## SYSTEM ENVIRONMENT

- OS: {{os}}
- Shell: {{shell}} v{{shell_version}}
- Locale: {{locale}}
- Current Time: {{datetime}}
- Current User: {{user}}
- Working Directory: {{pwd}}
- Directory Separator: {{dir_sep}}
- Installed External Tools: {{tools}}
"""

const hardcodedFormatPrompt* = """
## OUTPUT FORMAT

Respond ONLY with a JSON object in the exact format below. Do NOT include any other text, markdown, or code fences.

{
  "commands": [
    {
      "command": "the command text",
      "description": "brief explanation of what the command does",
      "type": "external"
    }
  ]
}

### RULES:
- "commands" is an array of command objects, sorted by relevance (most relevant first)
- Maximum 10 commands. Do NOT pad the list — return only genuinely useful options
- Each command object has:
  * "command": The executable command string (required, non-empty)
  * "description": One-line explanation of the command (required)
  * "type": Either "external" (external program) or "builtin" (shell built-in) (required)
- Output ONLY the JSON object, nothing else
- If the request is impossible, unsafe, or ambiguous, return {"commands": []}
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
