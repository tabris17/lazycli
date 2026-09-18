import std/[envvars, httpclient, json, os, strutils, tables, times, uri]
import lazycli/[config, env, utils]


const entryPoint = "/chat/completions"


type
  CommandOption* = object
    command*: string
    commandType*: string  # "builtin", "native", or "external"
    deps*: seq[string]


proc toFullUrl(baseUrl: string): string {.inline.} =
  if baseUrl.endsWith(entryPoint):
    baseUrl
  elif baseUrl.endsWith("/"):
    baseUrl & entryPoint[1..^1]
  else:
    baseUrl & entryPoint


proc createProxy(preferHttps: bool): Proxy {.inline.} =
  template testUrl(url: string): untyped =
    if url.len > 0:
      return newProxy(url)

  if preferHttps:
    testUrl(env.getEnv(proxy))
    testUrl(getEnv("HTTPS_PROXY"))
    testUrl(getEnv("https_proxy"))
    testUrl(getEnv("HTTP_PROXY"))
    testUrl(getEnv("http_proxy"))
    testUrl(getEnv("ALL_PROXY"))
    testUrl(getEnv("all_proxy"))
    testUrl(getConfig(proxy))
  else:
    testUrl(env.getEnv(proxy))
    testUrl(getEnv("HTTP_PROXY"))
    testUrl(getEnv("http_proxy"))
    testUrl(getEnv("ALL_PROXY"))
    testUrl(getEnv("all_proxy"))
    testUrl(getConfig(proxy))


proc buildTemplateContext(): Table[string, string] =
  {
    "os": getPlatform(),
    "shell": env.getEnv(shell).name,
    "shell_version": env.getEnv(shell).version,
    "locale": getLocale(),
    "datetime": $now(),
    "pwd": getCurrentDir(),
    "user": getUsername(),
    "tools": getConfig(tools).join(", "),
    "dir_sep": $env.getEnv(dirSep),
  }.toTable


proc renderPrompt*(): string =
  result = systemPrompt.render(buildTemplateContext())


proc validateResponse(content: string): seq[CommandOption] =
  ## Parse and validate the LLM response.
  ## Returns a seq of CommandOption, or raises ValueError on invalid format.
  let json = parseJson(content)

  if not json.hasKey("commands"):
    raise newException(ValueError, "Response missing 'commands' field")

  let cmds = json["commands"]
  if cmds.kind != JArray:
    raise newException(ValueError, "'commands' must be a JSON array")

  if cmds.len > 10:
    raise newException(ValueError, "Too many commands (max 10), got " & $cmds.len)

  for item in cmds:
    if item.kind != JObject:
      raise newException(ValueError, "Each command must be a JSON object")

    if not item.hasKey("command") or item["command"].kind != JString or item["command"].getStr().strip().len == 0:
      raise newException(ValueError, "Each command must have a non-empty 'command' string")

    if not item.hasKey("type") or item["type"].kind != JString:
      raise newException(ValueError, "Each command must have a 'type' string")
    let cmdType = item["type"].getStr()
    if cmdType notin ["external", "builtin", "native"]:
      raise newException(ValueError, "'type' must be 'builtin', 'native', or 'external', got: " & cmdType)

  for item in cmds:
    var deps: seq[string] = @[]
    if item.hasKey("deps") and item["deps"].kind == JArray:
      for dep in item["deps"]:
        if dep.kind == JString and dep.getStr().strip().len > 0:
          deps.add(dep.getStr())
    result.add(CommandOption(
      command: item["command"].getStr(),
      commandType: item["type"].getStr(),
      deps: deps
    ))


proc checkDeps(deps: seq[string]): bool =
  ## Check if all dependency commands exist on the system.
  if deps.len == 0:
    return true
  for dep in deps:
    if findExe(dep).len == 0:
      return false
  return true


proc findFirstExecutable(options: seq[CommandOption]): string =
  ## Find the first available command:
  ## - "builtin" type is always accepted immediately
  ## - "native" type requires all its dependencies to exist on the system
  ## - "external" type requires all its dependencies to exist on the system
  ## Falls back to the first option if nothing is found.
  ## Priority order: builtin → native → external
  # First pass: builtin commands first
  for opt in options:
    if opt.commandType == "builtin":
      return opt.command

  # Second pass: native commands with dep checking
  for opt in options:
    if opt.commandType == "native":
      if checkDeps(opt.deps):
        return opt.command

  # Third pass: external commands with dep checking
  for opt in options:
    if opt.commandType == "external":
      if checkDeps(opt.deps):
        return opt.command

  # Fallback: return the first native or external option anyway (will likely fail)
  for opt in options:
    if opt.commandType in ["native", "external"]:
      return opt.command

  return ""


proc query*(text: string): string =
  let provider = getConfig(provider)
  let isHttpsUrl = parseUri(provider.baseUrl).scheme == "https"
  let httpClient = newHttpClient(proxy = createProxy(isHttpsUrl))
  let tplContext = buildTemplateContext()
  let systemContent = systemPrompt.render(tplContext)
  let maxRetries = getConfig(maxRetries)
  let isVerbose = env.getEnv(verbose)

  var messages: seq[JsonNode] = @[]
  messages.add(%*{"role": "system", "content": systemContent})

  let customPrompt = getConfig(prompt)
  if customPrompt.len > 0:
    messages.add(%*{"role": "user", "content": customPrompt.render(tplContext)})

  messages.add(%*{"role": "user", "content": text})

  let requestBody = $(%*{
    "model": provider.model,
    "stream": false,
    "temperature": 0.1,
    "thinking": {"type": "disabled"},
    "messages": messages,
  })

  if isVerbose:
    stderr.writeLine("--- BEGIN REQUEST ---")
    stderr.writeLine("URL: " & provider.baseUrl.toFullUrl)
    stderr.writeLine(requestBody)
    stderr.writeLine("--- END REQUEST ---")

  for attempt in 0..maxRetries:
    let response = httpClient.request(
      url = provider.baseUrl.toFullUrl,
      httpMethod = HttpPost,
      headers = newHttpHeaders({
        "Content-Type": "application/json",
        "Authorization": "Bearer " & provider.apiKey
      }),
      body = requestBody
    )

    if isVerbose:
      stderr.writeLine("--- BEGIN RESPONSE ---")
      stderr.writeLine(response.body)
      stderr.writeLine("--- END RESPONSE ---")

    if response.status != $Http200:
      if attempt < maxRetries:
        continue
      raise newException(ValueError, "Request failed with status code: " & $response.status)

    let contentType = response.headers["Content-Type"]
    if not contentType.startsWith("application/json"):
      if attempt < maxRetries:
        continue
      raise newException(ValueError, "Unexpected response content type: " & contentType)

    let responseJson = parseJson(response.body)

    let content =
      try:
        responseJson["choices"][0]["message"]["content"].getStr()
      except:
        if attempt < maxRetries:
          continue
        raise newException(ValueError, "Unexpected API response format")

    # Try to parse and validate the command JSON
    var options: seq[CommandOption]
    try:
      options = validateResponse(content)
    except ValueError as e:
      if attempt < maxRetries:
        continue
      raise newException(ValueError, "Invalid response format: " & e.msg)

    # If the commands array is empty, it means the LLM couldn't generate
    # any commands from the user's description (too vague) - don't retry.
    if options.len == 0:
      raise newException(ValueError,
        "Unable to generate a command from the description. " &
        "Please provide a more specific and clear description of the operation you want to perform.")

    # Find the first executable command
    result = findFirstExecutable(options)

    if result.len == 0:
      if attempt < maxRetries:
        continue
      raise newException(ValueError, "No valid command found in the response")

    return result

  raise newException(ValueError, "Failed to get a valid response after " & $maxRetries & " retries")