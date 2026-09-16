import std/strutils
import lazycli/keybinding


const initScript* = """
function lazycli_query
  set line (commandline)
  if test -z (string trim -- $line)
    return
  end

  printf "\r\e[2KProcessing..."

  set result (
    {{lazycli}} query \
      --config={{config}} \
      --shell="fish,$FISH_VERSION" \
      $line | string trim
  )

  if test -z "$result"
    return
  end

  commandline -f repaint
  commandline -r "$result"
end

bind {{key}} lazycli_query
"""


proc getFishKeyName(key: Key): string =
  ## Returns the Fish `-k` key name for a named key.
  case key:
    of Backspace: "backspace"
    of Tab:      "tab"
    of Enter:    "enter"
    of Escape:   "escape"
    of Space:    "space"
    of PageUp:   "pageup"
    of PageDown: "pagedown"
    of End:      "end"
    of Home:     "home"
    of Left:     "left"
    of Up:       "up"
    of Right:    "right"
    of Down:     "down"
    of Insert:   "insert"
    of Delete:   "delete"
    of F1:       "f1"
    of F2:       "f2"
    of F3:       "f3"
    of F4:       "f4"
    of F5:       "f5"
    of F6:       "f6"
    of F7:       "f7"
    of F8:       "f8"
    of F9:       "f9"
    of F10:      "f10"
    of F11:      "f11"
    of F12:      "f12"
    of Char:     ""


proc bindKey*(keyBinding: KeyBinding): string =
  if Super in keyBinding.modifiers:
    raise newException(ValueError,
      "Fish shell does not support the Super modifier in key bindings")

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
      return "\\e\\c" & ch
    elif hasCtrl:
      return "\\c" & ch
    elif hasAlt:
      return "\\e" & ch
    elif hasShift:
      return $ch.toUpperAscii()
    else:
      return $ch

  # ── Named key without modifiers → Fish -k style ──────────────────
  let keyName = getFishKeyName(keyBinding.key)
  if not (hasCtrl or hasAlt or hasShift):
    return "-k " & keyName

  # ── Named key with modifiers → escape sequence ───────────────────
  case keyBinding.key:
    of Backspace: "\\c?"
    of Tab:       "\\c-i"
    of Enter:     "\\c-m"
    of Escape:    "\\e"
    of Space:     " "
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
