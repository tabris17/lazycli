import std/[envvars, httpclient, json, os, strutils, tables, uri]
import ./config
import ./utils


var proxyUrl* = ""


const
  entryPoint = "/chat/completions"
  defaultPrompt = """You are a command generation engine.

Task:
Convert natural language into a single executable command for {{shell}}.

Output rules:
1. Output ONLY the command. No explanations, no comments, no extra text.
2. Output must be a single line (no LF or CRLF).
3. Do not use code blocks or formatting.
4. Do not output placeholders or examples.
5. If conversion is impossible or unsafe, output exactly: Unable to convert
6. Output will be executed directly. Ensure no leading/trailing whitespace or hidden characters.

Execution environment:
- Shell: {{shell}} v{{shell_version}}
- Operating System: {{os}}
- Working Directory: {{pwd}}
- User: {{user}}
- Available tools: {{tools}}

Constraints:
- Must be compatible with the specified shell and OS.
- Prefer minimal and direct commands.
- Avoid interactive commands unless explicitly requested.
- Avoid destructive operations unless explicitly requested.
"""


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
    testUrl(proxyUrl)
    testUrl(getEnv("https_proxy"))
    testUrl(getEnv("http_proxy"))
    testUrl(config.get(proxy))
  else:
    testUrl(proxyUrl)
    testUrl(getEnv("http_proxy"))
    testUrl(config.get(proxy))


proc query*(text: string): string =
  let provider = config.get(provider)
  let isHttpsUrl = parseUri(provider.baseUrl).scheme == "https"
  let httpClient = newHttpClient(proxy = createProxy(isHttpsUrl))
  let promptTpl = if config.get(prompt).len > 0: config.get(prompt) else: defaultPrompt
  let prompt = promptTpl.render({
    "os": getPlatform(),
    "shell": config.get(shell).name, "shell_version": config.get(shell).version, 
    "pwd": getCurrentDir(), 
    "user": getUsername(),
    "tools": ""
  }.toTable)
  echo prompt

  let response = httpClient.request(
    url = provider.baseUrl.toFullUrl,
    httpMethod = HttpPost, 
    headers = newHttpHeaders({
      "Content-Type": "application/json",
      "Authorization": "Bearer " & provider.apiKey
    }),
    body = $(%*{
      "model": provider.model,
      "stream": false,
      "temperature": 0,
      "thinking": {"type": "disabled"}, # Deepseek-specific parameter to disable thinking time
      "messages": [
        {"role": "system", "content": prompt},
        {"role": "user", "content": text}
      ],
      # "max_tokens": config.get(tokenLimit),
    })
  )

  if response.status != $Http200:
    raise newException(ValueError, "Request failed with status code: " & $response.status)

  let contentType = response.headers["Content-Type"]
  if not contentType.startsWith("application/json"):
    raise newException(ValueError, "Unexpected response content type: " & contentType)

  let json = parseJson(response.body)

  try:
    result = json["choices"][0]["message"]["content"].getStr()
  except Exception:
    raise newException(ValueError, "Unexpected response format")
