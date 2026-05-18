import std/[os, strutils, tables]


when defined(windows):
  import std/winlean

  const
    LOCALE_NAME_MAX_LENGTH = 85
    LOCALE_USER_DEFAULT = 0x0400
    LOCALE_SISO3166CTRYNAME = 0x0000005a
    LOCALE_SISO639LANGNAME = 0x00000059

  type
    WCHAR = uint16
    NTSTATUS = int32
    LCID = int32
    LCTYPE = int32
    LPWSTR = ptr WCHAR
    
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

  proc GetLocaleInfoW*(Locale: LCID, LCType: LCTYPE, lpLCData: LPWSTR, cchData: int32): int32
    {.stdcall, dynlib: "kernel32", importc.}


when defined(linux):
  import std/parsecfg
elif defined(macosx):
  import std/posix
  proc sysctlbyname(name: cstring, oldp: pointer, oldlenp: ptr csize_t, newp: pointer, newlen: csize_t): cint
    {.importc, header: "<sys/sysctl.h>".}
elif defined(posix):
  import std/[posix, posix_utils]


func render*(tpl: string, values: Table[string, string]): string =
  proc findTagEnd(s: string, start: int): int =
    var i = start

    while i + 1 < s.len:
      if s[i] == '}' and s[i + 1] == '}':
        return i
      inc i

    return -1

  proc renderRange(s: string, values: Table[string, string], startPos: int, endPos: int): string =
    var i = startPos
    var buf = newStringOfCap(endPos - startPos)

    while i < endPos:
      if i + 1 < endPos and s[i] == '{' and s[i + 1] == '{':
        let tagEnd = findTagEnd(s, i + 2)

        if tagEnd < 0 or tagEnd >= endPos:
          buf.add s[i]
          inc i
          continue

        let tag = s[i + 2 ..< tagEnd].strip

        # {{@if key}}
        if tag.startsWith("@if "):
          let condKey = tag[4 .. ^1].strip

          var depth = 1
          var searchPos = tagEnd + 2
          var blockEnd = -1

          while searchPos < endPos:
            if searchPos + 1 < endPos and
               s[searchPos] == '{' and
               s[searchPos + 1] == '{':

              let nestedEnd = findTagEnd(s, searchPos + 2)

              if nestedEnd < 0:
                break

              let nestedTag = s[searchPos + 2 ..< nestedEnd].strip

              if nestedTag.startsWith("@if "):
                inc depth
              elif nestedTag == "@end":
                dec depth

                if depth == 0:
                  blockEnd = searchPos
                  let contentStart = tagEnd + 2

                  if values.hasKey(condKey) and values[condKey].len > 0:
                    buf.add renderRange(
                      s,
                      values,
                      contentStart,
                      blockEnd
                    )

                  i = nestedEnd + 2
                  break

              searchPos = nestedEnd + 2
            else:
              inc searchPos

          if blockEnd < 0:
            buf.add s[i]
            inc i
        # {{@end}}
        elif tag == "@end":
          i = tagEnd + 2
        else:
          if values.hasKey(tag):
            buf.add values[tag]
          else:
            buf.add "{{" & tag & "}}"

          i = tagEnd + 2

      else:
        buf.add s[i]
        inc i

    result = buf

  result = renderRange(tpl, values, 0, tpl.len)


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
  elif defined(linux):
    if fileExists("/etc/os-release"):
      let cfg = loadConfig("/etc/os-release")
      cfg.getSectionValue("", "PRETTY_NAME")
    else:
      hostOS
  elif defined(macosx):
    var size: csize_t = 0
    if sysctlbyname("kern.osproductversion", nil, size.addr, nil, 0) == 0:
      var buf = newString(size.uint)
      if sysctlbyname("kern.osproductversion", buf.cstring, size.addr, nil, 0) == 0:
        hostOS & " " & buf.strip(chars = {'\0'})
      else:
        hostOS
    else:
      hostOS
  elif defined(posix):
    hostOS & " " & uname().release
  else:
    hostOS


proc getLocale*(): string =
  when defined(windows):
    var buf: array[LOCALE_NAME_MAX_LENGTH, WCHAR]
    if GetLocaleInfoW(LOCALE_USER_DEFAULT, LOCALE_SISO639LANGNAME, buf[0].addr, LOCALE_NAME_MAX_LENGTH) > 0:
      result = $cast[WideCString](buf.addr)
      if GetLocaleInfoW(LOCALE_USER_DEFAULT, LOCALE_SISO3166CTRYNAME, buf[0].addr, LOCALE_NAME_MAX_LENGTH) > 0:
        result &= "_" & $cast[WideCString](buf.addr)
  else:
    return getEnv("LANG")
