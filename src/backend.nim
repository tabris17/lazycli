import std/[envvars, httpclient, json, uri]
import std/strutils
import std/tables
import ./config


var proxyUrl* = ""


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

  let response = httpClient.request(
    url = provider.baseUrl, 
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
        {"role": "system", "content": "你是一个将自然语言直接转换为 PowerShell 命令的转换器，只输出可执行的 PowerShell 命令本身，不要任何解释、格式、注释或多余内容。命令必须是一行。"},
        {"role": "user", "content": text}
      ],
      # "max_tokens": 500,
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
