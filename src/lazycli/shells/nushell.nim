import std/[enumutils, strformat, strutils]
import lazycli/keybinding


const initScript* = """
def query_lazycli [] {
  let ver = (version).version
  let line = (commandline)
  if ($line | str trim | is-empty) {
    return
  }
  print -n "\r\e[2KProcessing..."

  let result = (
    {{lazycli}} query --config={{config}} --shell=$'nushell,($ver)' $line |
    str trim
  )
  if ($result | is-empty) {
    return
  }

  commandline edit --replace $result
}

$env.config.keybindings ++= [
  {
    name: lazycli
    {{key}}
    mode: emacs
    event: {
      send: executehostcommand
      cmd: "query_lazycli"
    }
  }
]
"""


proc bindKey*(keyBinding: KeyBinding): string =
  var modifiers: seq[string] = @[]

  for m in [Alt, Super, Shift]:
    if m in keyBinding.modifiers:
      modifiers.add m.symbolName().toLowerAscii()

  if Ctrl in keyBinding.modifiers:
    modifiers.add "control"

  let modifiersLiteral = 
    case modifiers.len:
      of 0:
        "none"
      of 1:
        modifiers[0]
      else:
        "[ " & modifiers.join(" ") & " ]"

  let keyCode = 
    if keyBinding.key == Key.Char:
      if keyBinding.ch == '\\':
        "char_\\\\"
      else:
        "char_" & $keyBinding.ch
    else:
      keyBinding.key.symbolName().toLowerAscii()

  fmt"modifier: {modifiersLiteral}{'\n'}    keycode: {keyCode}"
