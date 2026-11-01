$ErrorActionPreference = 'Stop'
$homeDir = $HOME
$logDir = Join-Path $homeDir '.t3service\logs'
$t3 = Join-Path $homeDir '.t3\bin\t3.cmd'
# T3SERVICE_HOST and T3SERVICE_PORT are optional user environment variables.
# Set T3SERVICE_HOST=0.0.0.0 to accept LAN or Tailscale clients; the Windows
# firewall is then the only gate. Both values reach cmd.exe, so anything that
# is not a plain host name, IP address, or port number falls back to the default.
$warnings = @()
$hostName = '127.0.0.1'
if ($env:T3SERVICE_HOST) {
    if ($env:T3SERVICE_HOST -match '^[A-Za-z0-9.:-]+$') { $hostName = $env:T3SERVICE_HOST }
    else { $warnings += "[t3service] ignoring invalid T3SERVICE_HOST; using $hostName" }
}
$port = 3773
if ($env:T3SERVICE_PORT) {
    $parsed = 0
    if ([int]::TryParse($env:T3SERVICE_PORT, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le 65535) { $port = $parsed }
    else { $warnings += "[t3service] ignoring invalid T3SERVICE_PORT; using $port" }
}
$keepLogs = 200

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
    Add-Content -Path $stderrLog -Value ($warnings + "[t3service] t3 serve exited with code $($process.ExitCode); restarting in $delay s")
    Start-Sleep -Seconds $delay
}
