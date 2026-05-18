import std/[enumutils, strutils]
import lazycli/keybinding


const initScript* = """
Set-PSReadLineKeyHandler -Key {{key}} -LongDescription "lazycli" -ScriptBlock {
  $readline = [Microsoft.PowerShell.PSConsoleReadLine]
  $version = $PSVersionTable.PSVersion.ToString()

  $line = ""
  $cursor = 0

  $readline::GetBufferState([ref]$line, [ref]$cursor)
  if ([string]::IsNullOrWhiteSpace($line)) {
    return
  }

  try {
    $readline::RevertLine()
    $readline::Insert("Processing...")

    $result = & {{lazycli}} `
      query `
      "--shell=powershell,$version" `
      {{@if config}}'--config="{{config}}"'{{@end}} `
      {{@if proxy}}'--proxy="{{proxy}}"'{{@end}} `
      {{@if posix_path}}'--posix-path'{{@end}} `
      $line 2>&1

    $readline::RevertLine()

    if ($LASTEXITCODE -ne 0) {
        $rl::Insert("[lazycli failed] $result")
        return
    }

    if ($result -is [array]) {
        $result = $result -join [Environment]::NewLine
    }

    $readline::Insert([string]$result)
  } catch {
    $readline::RevertLine()
    $readline::Insert("[lazycli error] $_")
  }
}
"""


proc bindKey*(keyBinding: KeyBinding): string =
  var parts: seq[string] = @[]

  for m in [Alt, Ctrl, Shift]:
    if m in keyBinding.modifiers:
      parts.add m.symbolName()

  if Super in keyBinding.modifiers:
    parts.add "Win"

  let keyStr =
    if keyBinding.key == Key.Char:
      $keyBinding.ch
    else:
      let keyName = keyBinding.key.symbolName()
      case keyBinding.key:
        of Left, Right, Up, Down:
          keyName & "Arrow"
        of Space:
          "@"
        else:
          keyName

  parts.add keyStr
  parts.join("+")
