import std/[os, macros]
import lazycli/utils


type
  Shell* = object
    name*: string
    version*: string

  Env = object
    platform*: string
    shell*: Shell
    proxy*: string
    dirSep: char


var env: Env


macro getEnv*(key: untyped): untyped =
  result = quote do:
    env.`key`


macro setEnv*(key: untyped, value: untyped): untyped =
  result = quote do:
    env.`key` = `value`


proc detectEnv*() =
  env.platform = getPlatform()
  env.dirSep = DirSep
