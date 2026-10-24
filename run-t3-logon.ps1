$ErrorActionPreference = 'Stop'
$homeDir = $HOME
$logDir = Join-Path $homeDir '.t3service\logs'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stdoutLog = Join-Path $logDir "t3-serve-$stamp.out.log"
$stderrLog = Join-Path $logDir "t3-serve-$stamp.err.log"
$t3 = Join-Path $homeDir '.t3\bin\t3.cmd'

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$env:T3CODE_HOME = Join-Path $homeDir '.t3'
$command = '""{0}" serve --host 127.0.0.1 --no-browser"' -f $t3
$process = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/s', '/c', $command) -WorkingDirectory $homeDir -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
exit $process.ExitCode
