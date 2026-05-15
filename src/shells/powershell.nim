import std/[enumutils, strutils]
import ../keybinding


const initScript* = """
Set-PSReadLineKeyHandler -Key {{key}} -LongDescription "lazycli" -ScriptBlock {
    $version = $PSVersionTable.PSVersion.ToString()
    $line = ""
    $cursor = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    if ([string]::IsNullOrWhiteSpace($line)) {
        return
    }

    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()

    $spinner = @('.','..','...','....','.....','......')
    $index = 0

    $job = Start-Job -ScriptBlock {
        param($lineText)
        $args = @(
            'query'
            "--shell=powershell,$version"
            '--config={{config}}'
            $lineText
        )
        {{lazycli}} @args
    } -ArgumentList $line

    while ($job.State -eq 'Running') {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("Processing$($spinner[$index])")
        Start-Sleep -Milliseconds 300
        $index = ($index + 1) % $spinner.Count
    }

    $result = Receive-Job $job
    Remove-Job $job
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($result)
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
