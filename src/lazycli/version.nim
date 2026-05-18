import std/[strformat, strutils]


proc generateCalendarVersion(suffix: string = ""): string =
  let s = CompileDate.split('-')
  let version = s[0] & "." & $parseInt(s[1]) & "." & $parseInt(s[2])
  if suffix.len > 0:
    version & "-" & suffix
  else:
    version


const
  NimblePkgVersion {.strdefine.} = static:
    generateCalendarVersion("dev")
 
  author* = "Fournoas"
  appName* = "lazycli"
  buildVersion* = NimblePkgVersion
  displayVersion* = fmt"{appName} v{buildVersion}"
  homepage* = "https://github.com/tabris17/lazycli"
