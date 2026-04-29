const script* = """
Set-PSReadLineKeyHandler -Key F1 -LongDescription "AI Command Helper" -ScriptBlock {
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
            'query',
            "--shell=powershell,$version",
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
