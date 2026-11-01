$ErrorActionPreference = 'Stop'
$homeDir = $HOME
$logDir = Join-Path $homeDir '.t3service\logs'
$t3 = Join-Path $homeDir '.t3\bin\t3.cmd'
. (Join-Path $PSScriptRoot 't3service-config.ps1')
$config = Get-T3ServiceConfig
$hostName = $config.Host
$port = $config.Port
$warnings = $config.Warnings
$keepLogs = 200
# Write config warnings now, not after the first exit, so `t3service status`
# shows them while the server runs.
$configLog = Join-Path $logDir 't3service-config.log'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
if ($warnings) { Set-Content -Path $configLog -Value $warnings } else { Remove-Item -Path $configLog -ErrorAction SilentlyContinue }

$env:T3CODE_HOME = Join-Path $homeDir '.t3'
$command = '""{0}" serve --host {1} --port {2} --no-browser"' -f $t3, $hostName, $port

# Restart the server when it exits, for example after a crash or while another
# server owns the T3 home (exit code 78). `t3service stop` ends this loop by
# stopping the whole process tree rooted at this script.
while ($true) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    # Keep the newest log files so a server that keeps failing cannot fill the disk.
    Get-ChildItem -Path $logDir -Filter 't3-serve-*.log' -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip ($keepLogs - 2) |
        Remove-Item -Force -ErrorAction SilentlyContinue
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stdoutLog = Join-Path $logDir "t3-serve-$stamp.out.log"
    $stderrLog = Join-Path $logDir "t3-serve-$stamp.err.log"
    $process = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d', '/s', '/c', $command) -WorkingDirectory $homeDir -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutLog -RedirectStandardError $stderrLog
    # 78 means another server owns the T3 home; wait longer so the log folder does not fill.
    $delay = if ($process.ExitCode -eq 78) { 60 } else { 10 }
    Add-Content -Path $stderrLog -Value ("[t3service] t3 serve exited with code $($process.ExitCode); restarting in $delay s")
    Start-Sleep -Seconds $delay
}
