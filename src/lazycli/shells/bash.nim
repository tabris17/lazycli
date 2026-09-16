import std/strutils
import lazycli/keybinding


const initScript* = """
lazycli_query() {
  local line="$READLINE_LINE"

  if [[ -z "${line//[[:space:]]/}" ]]; then
    return
  fi

  printf "\r\033[2KProcessing...\r"

  local result
  result=$(
    {{lazycli}} query --shell="bash,$BASH_VERSION" {{@if config}}--config="{{config}}" {{@end}}{{@if proxy}}--proxy="{{proxy}}" {{@end}}{{@if posix_path}}--posix-path {{@end}}\
      -- "$line"
  )

  if [[ -z "$result" ]]; then
    return
  fi

  READLINE_LINE="$result"
  READLINE_POINT=${#READLINE_LINE}
}

bind -x '"{{key}}":lazycli_query'
"""


proc bindKey*(keyBinding: KeyBinding): string =
  if Super in keyBinding.modifiers:
    raise newException(ValueError, "Bash does not support the Super modifier")

  let hasCtrl = Ctrl in keyBinding.modifiers
  let hasAlt = Alt in keyBinding.modifiers
  let hasShift = Shift in keyBinding.modifiers

  # Modifier parameter for CSI sequences (xterm standard):
  #   1=None  2=Shift  3=Alt  4=Alt+Shift  5=Ctrl  6=Ctrl+Shift  7=Ctrl+Alt  8=Ctrl+Alt+Shift
  var modCode = 1
  if hasShift: modCode += 1
  if hasAlt: modCode += 2
  if hasCtrl: modCode += 4
  let modParam = if modCode == 1: "" else: $modCode

  if keyBinding.key == Key.Char:
    let ch = keyBinding.ch
    if hasCtrl and hasAlt:
      return "\\C-\\M-" & ch
    elif hasCtrl:
      return "\\C-" & ch
    elif hasAlt:
      return "\\M-" & ch
    elif hasShift:
      return $ch.toUpperAscii()
    else:
      return $ch

  case keyBinding.key:
    of Backspace:
      "\\C-?"
    of Tab:
      "\\C-i"
    of Enter:
      "\\C-m"
    of Escape:
      "\\e"
    of Space:
      " "
    of PageUp:
      if modParam == "": "\\e[5~" else: "\\e[5;" & modParam & "~"
    of PageDown:
      if modParam == "": "\\e[6~" else: "\\e[6;" & modParam & "~"
    of End:
      if modParam == "": "\\e[F" else: "\\e[1;" & modParam & "F"
    of Home:
      if modParam == "": "\\e[H" else: "\\e[1;" & modParam & "H"
    of Left:
      if modParam == "": "\\e[D" else: "\\e[1;" & modParam & "D"
    of Up:
      if modParam == "": "\\e[A" else: "\\e[1;" & modParam & "A"
    of Right:
      if modParam == "": "\\e[C" else: "\\e[1;" & modParam & "C"
    of Down:
      if modParam == "": "\\e[B" else: "\\e[1;" & modParam & "B"
    of Insert:
      if modParam == "": "\\e[2~" else: "\\e[2;" & modParam & "~"
    of Delete:
      if modParam == "": "\\e[3~" else: "\\e[3;" & modParam & "~"
    of F1:
      if modParam == "": "\\eOP" else: "\\e[1;" & modParam & "P"
    of F2:
      if modParam == "": "\\eOQ" else: "\\e[1;" & modParam & "Q"
    of F3:
      if modParam == "": "\\eOR" else: "\\e[1;" & modParam & "R"
    of F4:
      if modParam == "": "\\eOS" else: "\\e[1;" & modParam & "S"
    of F5:
      if modParam == "": "\\e[15~" else: "\\e[15;" & modParam & "~"
    of F6:
      if modParam == "": "\\e[17~" else: "\\e[17;" & modParam & "~"
    of F7:
      if modParam == "": "\\e[18~" else: "\\e[18;" & modParam & "~"
    of F8:
      if modParam == "": "\\e[19~" else: "\\e[19;" & modParam & "~"
    of F9:
      if modParam == "": "\\e[20~" else: "\\e[20;" & modParam & "~"
    of F10:
      if modParam == "": "\\e[21~" else: "\\e[21;" & modParam & "~"
    of F11:
      if modParam == "": "\\e[23~" else: "\\e[23;" & modParam & "~"
    of F12:
      if modParam == "": "\\e[24~" else: "\\e[24;" & modParam & "~"
    of Char:
      ""
