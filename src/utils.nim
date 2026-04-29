import std/[os, tables]

when defined(windows):
  import std/winlean

  type
    WCHAR = uint16
    NTSTATUS = int32
    
    OSVERSIONINFOW = object
      dwOSVersionInfoSize: ULONG
      dwMajorVersion: ULONG
      dwMinorVersion: ULONG
      dwBuildNumber: ULONG
      dwPlatformId: ULONG
      szCSDVersion: array[128, WCHAR]

    POSVERSIONINFOW = ptr OSVERSIONINFOW

  proc RtlGetVersion*(lpVersionInformation: POSVERSIONINFOW): NTSTATUS
    {.stdcall, dynlib: "ntdll", importc.}
else:
  import std/posix


func render*(tpl: string, values: Table[string, string]): string =
  var i = 0
  var buf = newStringOfCap(tpl.len)

  while i < tpl.len:
    if i + 1 < tpl.len and tpl[i] == '{' and tpl[i+1] == '{':
      var j = i + 2
      while j + 1 < tpl.len and not (tpl[j] == '}' and tpl[j+1] == '}'):
        inc j

      if j + 1 >= tpl.len:
        buf.add "{{"
        i += 2
        continue

      let key = tpl[i+2 ..< j]

      if values.hasKey(key):
        buf.add values[key]
      else:
        buf.add "{{" & key & "}}"

      i = j + 2
    else:
      buf.add tpl[i]
      inc i

  result = buf


proc getUsername*(): string =
  when defined(windows):
    getEnv("USERNAME")
  else:
    let username = getEnv("USER")
    if username.len > 0:
      username
    else:
      getEnv("LOGNAME")

proc getPlatform*(): string =
  when defined(windows):
    var info: OSVERSIONINFOW
    info.dwOSVersionInfoSize = sizeof(info).ULONG
    if RtlGetVersion(info.addr) == 0:
      let major = info.dwMajorVersion
      let minor = info.dwMinorVersion
      let build = info.dwBuildNumber
      hostOS & " " & $major & "." & $minor & " build " & $build
    else:
      hostOS
  else:
    hostOS
