import std/[os, macros, uri]
import parsetoml
import ./version


const defaultConfigFile = "config.toml"


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


var config: Config


macro get*(key: untyped): untyped =
  result = quote do:
    config.`key`


macro set*(key: untyped, value: untyped): untyped =
  result = quote do:
    config.`key` = `value`


macro read*(key: string): untyped =
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


proc findFile*(filename: string): string {.inline.} =
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
  let tomlValue = newTTable()
  if config.proxy.len > 0:
    tomlValue["proxy"] = newTString(config.proxy)
  tomlValue["version"] = newTString(config.version)
  tomlValue.toTomlString


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


proc isValidUrl(url: string): bool =
  try:
    let uri = parseUri(url)
    return uri.scheme == "http" or uri.scheme == "https"
  except UriParseError:
    return false


proc loadConfig*(filename: string) =
  let filePath = findFile(filename)
  let data = parsetoml.parseFile(filePath)
  config.file = filePath
  config.proxy = data.getStr("proxy", "")
  config.version = data.getStr("version")
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
  let data = newTTable()
  writeFile(config.file, config.toTomlString)
