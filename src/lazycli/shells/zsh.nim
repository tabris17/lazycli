import std/strutils
import lazycli/keybinding


const initScript* = """
lazycli_query() {
  emulate -L zsh

  local line="$BUFFER"

  local trimmed
  trimmed="${line#"${line%%[![:space:]]*}"}"
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

  if [[ -z $trimmed ]]; then
    return 0
  fi

  zle -R "Processing..."

  local result
  result=$({{lazycli}} query \
    --config={{config}} \
    --shell="zsh,$ZSH_VERSION" \
    -- "$line")

  result="${result#"${result%%[![:space:]]*}"}"
  result="${result%"${result##*[![:space:]]}"}"

  if [[ -z $result ]]; then
    zle reset-prompt
    return 0
  fi

  BUFFER="$result"
  CURSOR=${#BUFFER}

  zle reset-prompt
}

zle -N lazycli_query

bindkey {{key}} lazycli_query
"""


proc getTerminfoName(key: Key): string =
  ## Returns the terminfo capability name (e.g. "f1", "cub1", "bs")
  ## that goes after "k" in "${terminfo[kXX]}".
  ## Returns "" when the key has no standard terminfo entry.
  case key:
    of Backspace: "bs"
    of PageUp:    "pp"
    of PageDown:  "np"
    of End:       "end"
    of Home:      "home"
    of Left:      "cub1"
    of Up:        "cuu1"
    of Right:     "cuf1"
    of Down:      "cud1"
    of Insert:    "ich1"
    of Delete:    "dch1"
    of F1:        "f1"
    of F2:        "f2"
    of F3:        "f3"
    of F4:        "f4"
    of F5:        "f5"
    of F6:        "f6"
    of F7:        "f7"
    of F8:        "f8"
    of F9:        "f9"
    of F10:       "f10"
    of F11:       "f11"
    of F12:       "f12"
    else:         ""


proc bindKey*(keyBinding: KeyBinding): string =
  if Super in keyBinding.modifiers:
    raise newException(ValueError,
      "Zsh does not support the Super modifier in key bindings")

  let hasCtrl = Ctrl in keyBinding.modifiers
  let hasAlt = Alt in keyBinding.modifiers
  let hasShift = Shift in keyBinding.modifiers
  var modCode = 1
  if hasShift: modCode += 1
  if hasAlt:   modCode += 2
  if hasCtrl:  modCode += 4
  let modParam = if modCode == 1: "" else: $modCode

  # ── Character key ────────────────────────────────────────────────
  if keyBinding.key == Key.Char:
    let ch = keyBinding.ch
    if hasCtrl and hasAlt:
      return "'^[^" & ch.toUpperAscii() & "'"
    elif hasCtrl:
      return "'^" & ch.toUpperAscii() & "'"
    elif hasAlt:
      return "'^[" & ch & "'"
    elif hasShift:
      return "'" & ch.toUpperAscii() & "'"
    else:
      return "'" & ch & "'"

  # ── Named key without modifiers → terminfo ───────────────────────
  let terminfoName = getTerminfoName(keyBinding.key)
  if not (hasCtrl or hasAlt or hasShift) and terminfoName.len > 0:
    return "\"${terminfo[k" & terminfoName & "]}\""

  # ── Named key with modifiers / no terminfo → raw escape sequence ─
  case keyBinding.key:
    of Backspace: "'^?'"
    of Tab:       "'^I'"
    of Enter:     "'^M'"
    of Escape:    "'^['"
    of Space:     "' '"
    of PageUp:
      if modParam == "": "'^[[5~'" else: "'^[[5;" & modParam & "~'"
    of PageDown:
      if modParam == "": "'^[[6~'" else: "'^[[6;" & modParam & "~'"
    of End:
      if modParam == "": "'^[[F'" else: "'^[[1;" & modParam & "F'"
    of Home:
      if modParam == "": "'^[[H'" else: "'^[[1;" & modParam & "H'"
    of Left:
      if modParam == "": "'^[[D'" else: "'^[[1;" & modParam & "D'"
    of Up:
      if modParam == "": "'^[[A'" else: "'^[[1;" & modParam & "A'"
    of Right:
      if modParam == "": "'^[[C'" else: "'^[[1;" & modParam & "C'"
    of Down:
      if modParam == "": "'^[[B'" else: "'^[[1;" & modParam & "B'"
    of Insert:
      if modParam == "": "'^[[2~'" else: "'^[[2;" & modParam & "~'"
    of Delete:
      if modParam == "": "'^[[3~'" else: "'^[[3;" & modParam & "~'"
    of F1:
      if modParam == "": "'^[OP'" else: "'^[[1;" & modParam & "P'"
    of F2:
      if modParam == "": "'^[OQ'" else: "'^[[1;" & modParam & "Q'"
    of F3:
      if modParam == "": "'^[OR'" else: "'^[[1;" & modParam & "R'"
    of F4:
      if modParam == "": "'^[OS'" else: "'^[[1;" & modParam & "S'"
    of F5:
      if modParam == "": "'^[[15~'" else: "'^[[15;" & modParam & "~'"
    of F6:
      if modParam == "": "'^[[17~'" else: "'^[[17;" & modParam & "~'"
    of F7:
      if modParam == "": "'^[[18~'" else: "'^[[18;" & modParam & "~'"
    of F8:
      if modParam == "": "'^[[19~'" else: "'^[[19;" & modParam & "~'"
    of F9:
      if modParam == "": "'^[[20~'" else: "'^[[20;" & modParam & "~'"
    of F10:
      if modParam == "": "'^[[21~'" else: "'^[[21;" & modParam & "~'"
    of F11:
      if modParam == "": "'^[[23~'" else: "'^[[23;" & modParam & "~'"
    of F12:
      if modParam == "": "'^[[24~'" else: "'^[[24;" & modParam & "~'"
    of Char:
      ""
