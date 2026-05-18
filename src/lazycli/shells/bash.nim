import std/tables
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
    {{lazycli}} query \
      --shell="bash,$BASH_VERSION" \
      {{@if config}}--config="{{config}}"{{@end}} \
      {{@if proxy}}--proxy="{{proxy}}"{{@end}} \
      {{@if posix_path}}--posix_path{{@end}} \
      "$line"
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

  case keyBinding.key:
    of Backspace:
      "\\C-?"
    of Tab:
      ""
    of Enter:
      ""
    of Escape:
      ""
    of Space:
      ""
    of PageUp:
      ""
    of PageDown:
      ""
    of End:
      ""
    of Home:
      ""
    of Left:
      ""
    of Up:
      ""
    of Right:
      ""
    of Down:
      ""
    of Insert:
      ""
    of Delete:
      ""
    of F1:
      "\\eOP"
    of F2:
      ""
    of F3:
      ""
    of F4:
      ""
    of F5:
      ""
    of F6:
      ""
    of F7:
      ""
    of F8:
      ""
    of F9:
      ""
    of F10:
      ""
    of F11:
      ""
    of F12:
      ""
    of Char:
      ""
