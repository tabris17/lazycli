import std/[enumutils, strutils]


type
  Modifier* = enum
    Alt
    Ctrl
    Shift
    Super

  Key* = enum
    Backspace
    Tab
    Enter
    Escape
    Space
    PageUp
    PageDown
    End
    Home
    Left
    Up
    Right
    Down
    Insert
    Delete
    F1
    F2
    F3
    F4
    F5
    F6
    F7
    F8
    F9
    F10
    F11
    F12
    Char

  KeyBinding* = object
    key*: Key
    ch*: char
    modifiers*: set[Modifier]


proc parseKey[T: enum](s: string): T =
  let keyName = s.strip().toLowerAscii()

  for k in T:
    if k.symbolName().toLowerAscii() == keyName:
      return k

  raise newException(ValueError, "Unknown key: " & s)


proc parseKeyBinding*(text: string): KeyBinding =
  let parts = text.split('+')
  if parts.len == 0:
    raise newException(ValueError, "Empty key binding")

  var mods: set[Modifier] = {}
  
  for i in 0 ..< parts.len - 1:
    let m = parseKey[Modifier](parts[i].strip())
    mods.incl m

  let keyName = parts[^1].strip()
  if keyName.len == 0:
    raise newException(ValueError, "Empty key")

  if keyName.len == 1:
    let c = keyName[0]

    if c.isAlphaNumeric or c in {'-', '=', '[', ']', '\\', ';', '\'', ',', '.', '/'}:
      return KeyBinding(key: Key.Char, ch: c, modifiers: mods)

    raise newException(ValueError, "Unsupported key: " & $c)

  let key = parseKey[Key](keyName)
  KeyBinding(key: key, ch: '\0', modifiers: mods)


proc `$`*(keyBinding: KeyBinding): string =
  var parts: seq[string] = @[]

  for m in [Alt, Ctrl, Shift, Super]:
    if m in keyBinding.modifiers:
      parts.add m.symbolName()

  let keyStr =
    if keyBinding.key == Key.Char:
      $keyBinding.ch
    else:
      keyBinding.key.symbolName()

  parts.add keyStr
  parts.join("+")
