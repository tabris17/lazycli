import std/[envvars, httpclient, json, os, strutils, tables, uri]
import ./config
import ./utils


var proxyUrl* = ""


const entryPoint = "/chat/completions"


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
  let prompt = config.get(prompt).render({
    "os": getPlatform(),
    "shell": config.get(shell).name, "shell_version": config.get(shell).version, 
    "pwd": getCurrentDir(), 
    "user": getUsername(),
    "tools": ""
  }.toTable)

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
