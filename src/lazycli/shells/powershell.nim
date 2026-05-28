import std/[enumutils, strutils]
import lazycli/keybinding


const initScript* = """
Set-PSReadLineKeyHandler -Key {{key}} -LongDescription "lazycli" -ScriptBlock {
  [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
  #$OutputEncoding = [System.Text.UTF8Encoding]::new()

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

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "{{lazycli}}"
    $psi.Arguments = "query --shell=powershell,$version {{@if config}}--config="{{config}}"{{@end}} {{@if proxy}}--proxy="{{proxy}}"{{@end}} {{@if posix_path}}--posix-path{{@end}} $line"
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi
    $process.Start() | Out-Null

    $stdout = $process.StandardOutput.BaseStream
    $stderr = $process.StandardError.BaseStream

    $msOut = New-Object System.IO.MemoryStream
    $msErr = New-Object System.IO.MemoryStream

    $stdout.CopyTo($msOut)
    $stderr.CopyTo($msErr)

    $process.WaitForExit()

    $outBytes = $msOut.ToArray()
    $errBytes = $msErr.ToArray()

    $result = [System.Text.Encoding]::UTF8.GetString($outBytes + $errBytes)
    $result = [string]$result.TrimEnd("`r","`n")
    $exitCode = $process.ExitCode

    $readline::RevertLine()

    if ($exitCode -ne 0) {
        $readline::Insert("[lazycli failed] $result")
        return
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
