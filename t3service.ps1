[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Action = 'status',
    [switch] $Follow,
    [Alias('h')]
    [switch] $Help
)

$ErrorActionPreference = 'Stop'
$taskName = 'T3 Code Server (User Logon)'
$serviceName = 'T3CodeServer'
$serviceDir = Join-Path $HOME '.t3service'
$runner = Join-Path $serviceDir 'run-t3-logon.ps1'
$localUrl = 'http://127.0.0.1:3773'
$t3Command = Join-Path $HOME '.t3\bin\t3.cmd'
$account = [Security.Principal.WindowsIdentity]::GetCurrent().Name

if ($Help -or $Action -in @('help', '--help', '-h', '/?', '-help')) {
    @'
t3service - manage the T3 Code user-logon server

Usage:
  t3service <command>

Commands:
  help                 Show this help
  status               Show task and runner status
  start                Start the installed task now
  stop                 Stop the task and its T3 process tree
  restart              Restart the task and its T3 process tree
  disable              Disable future logon starts; leave a running server alone
  enable               Re-enable starts at user logon
  install              Register the passwordless user-logon task
  uninstall            Remove the task and stop its T3 process tree (confirmation required)
  update               Refresh the task launcher
  pair                 Create a short-lived, single-use browser pairing token
  logs [-Follow]       Show recent task logs
  uninstall-service    Remove the legacy Windows service (Administrator required)

The task runs as the signed-in user; it does not store an account password.
T3 data and credentials remain in %USERPROFILE%\.t3. Disabling/removing the
task does not delete T3 data or helper files.
'@ | Write-Host
    exit 0
}

$validActions = @('install', 'update', 'start', 'stop', 'restart', 'status', 'pair', 'logs', 'disable', 'enable', 'uninstall', 'uninstall-service')
if ($Action -notin $validActions) {
    Write-Error "Unknown command '$Action'. Run 't3service help' or 't3service --help' for usage."
    exit 2
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-T3Task {
    Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}

function Get-T3RunnerProcess {
    $runnerPattern = [regex]::Escape($runner)
    Get-CimInstance Win32_Process | Where-Object {
        $_.Name -match '^(powershell|pwsh)\.exe$' -and $_.CommandLine -match $runnerPattern
    }
}

function Stop-T3RunnerProcessTree {
    $taskkill = Join-Path $env:WINDIR 'System32\taskkill.exe'
    foreach ($process in @(Get-T3RunnerProcess)) {
        & $taskkill /PID $process.ProcessId /T /F | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not terminate task-owned process tree rooted at PID $($process.ProcessId)."
        }
    }
}

switch ($Action) {
    'install' {
        if (Get-T3Task) { throw "Task '$taskName' already exists. Use 't3service status' or 't3service uninstall'." }
        if (-not (Test-Path $runner)) { throw "Task runner missing: $runner" }
        $hiddenLauncher = Join-Path $serviceDir 'run-t3-hidden.vbs'
        $windowsScriptHost = Join-Path $env:WINDIR 'System32\wscript.exe'
        if (-not (Test-Path $hiddenLauncher)) { throw "Hidden launcher missing: $hiddenLauncher" }
        $taskAction = New-ScheduledTaskAction -Execute $windowsScriptHost -Argument "`"$hiddenLauncher`"" -WorkingDirectory $serviceDir
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $account
        $principal = New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $trigger -Principal $principal -Settings $settings -Description 'Starts T3 Code headless server at this user logon.' | Out-Null
        Write-Host "Installed logon task for $account. It will run at your next sign-in."
        Write-Host 'This is a Task Scheduler task, not a boot-time Windows service.'
    }
    'update' {
        if (-not (Get-T3Task)) { throw "Logon task is not installed. Run 't3service install'." }
        $hiddenLauncher = Join-Path $serviceDir 'run-t3-hidden.vbs'
        $windowsScriptHost = Join-Path $env:WINDIR 'System32\wscript.exe'
        if (-not (Test-Path $hiddenLauncher)) { throw "Hidden launcher missing: $hiddenLauncher" }
        $taskAction = New-ScheduledTaskAction -Execute $windowsScriptHost -Argument "`"$hiddenLauncher`"" -WorkingDirectory $serviceDir
        Set-ScheduledTask -TaskName $taskName -Action $taskAction | Out-Null
        Write-Host 'Updated the task to use the hidden Windows Script Host launcher.'
    }
    'start' {
        if (-not (Get-T3Task)) { throw "Logon task is not installed. Run 't3service install'." }
        Start-ScheduledTask -TaskName $taskName
        Write-Host 'Started T3 Code server task.'
        Write-Host "Local UI:    $localUrl"
    }
    'disable' {
        $task = Get-T3Task
        if (-not $task) { Write-Host 'T3 Code logon task is not installed'; break }
        Disable-ScheduledTask -TaskName $taskName | Out-Null
        Write-Host 'Disabled future user-logon starts. A currently running server was left untouched.'
        Write-Host "Re-enable with 't3service enable'; remove the task with 't3service uninstall'."
    }
    'enable' {
        $task = Get-T3Task
        if (-not $task) { throw "Logon task is not installed. Run 't3service install'." }
        Enable-ScheduledTask -TaskName $taskName | Out-Null
        Write-Host 'Enabled T3 Code server at user logon. It will start at the next sign-in.'
    }
    'stop' {
        if (-not (Get-T3Task)) { throw "Logon task is not installed. Run 't3service install'." }
        Stop-T3RunnerProcessTree
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Host 'Stopped T3 Code server task.'
    }
    'restart' {
        if (-not (Get-T3Task)) { throw "Logon task is not installed. Run 't3service install'." }
        Stop-T3RunnerProcessTree
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-ScheduledTask -TaskName $taskName
        Write-Host 'Restarted T3 Code server task.'
    }
    'status' {
        $task = Get-T3Task
        if (-not $task) { Write-Host 'T3 Code logon task: not installed'; exit 1 }
        $info = Get-ScheduledTaskInfo -TaskName $taskName
        $runnerProcesses = @(Get-T3RunnerProcess)
        $lastResultMeaning = switch ([uint32]$info.LastTaskResult) {
            0 { 'Success' }
            267009 { 'Task is currently running' }
            267014 { 'Task was terminated by a stop request' }
            default { 'See Task Scheduler result code' }
        }
        Write-Host "Task:        $($task.TaskName)"
        Write-Host "State:       $($task.State)"
        Write-Host "Auto-start:  $(if ($task.State -eq 'Disabled') { 'Disabled' } else { 'Enabled' })"
        Write-Host "Run as:      $($task.Principal.UserId)"
        Write-Host 'Trigger:     At user logon'
        Write-Host "Last run:    $($info.LastRunTime)"
        Write-Host "Last result: $($info.LastTaskResult) ($lastResultMeaning)"
        Write-Host "Local UI:    $localUrl"
        if ($runnerProcesses) {
            Write-Host "T3 runner:   still alive (PID $($runnerProcesses.ProcessId -join ', '))"
        } else {
            Write-Host 'T3 runner:   no orphaned task process found'
        }
        Write-Host "Logs:        $($serviceDir)\logs\t3-serve-*.log"
    }
    'pair' {
        if (-not (Get-T3Task) -or (Get-T3Task).State -ne 'Running') {
            throw "T3 Code server is not running. Start it with 't3service start' first."
        }
        $env:T3CODE_HOME = Join-Path $HOME '.t3'
        & $t3Command pair --label 'Local browser'
        if ($LASTEXITCODE -ne 0) { throw "T3 pairing command exited with code $LASTEXITCODE." }
        Write-Host 'Pairing tokens are single-use and expire after five minutes. Pair once; do not save or share the token.'
    }
    'logs' {
        $files = @(Get-ChildItem (Join-Path $serviceDir 'logs') -Filter 't3-serve-*.log' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)
        if (-not $files) { throw "No task output logs found under $(Join-Path $serviceDir 'logs')" }
        if ($Follow) { Get-Content -Path $files.FullName -Tail 100 -Wait }
        else { foreach ($file in $files) { Write-Host "--- $($file.Name) ---"; Get-Content $file.FullName -Tail 100 } }
    }
    'uninstall' {
        if (-not (Get-T3Task)) { Write-Host 'T3 Code logon task is not installed'; break }
        $answer = Read-Host 'Remove the logon task and stop its T3 process tree? T3 data and files will be kept (y/N)'
        if ($answer -notmatch '^(y|yes)$') { Write-Host 'Cancelled'; break }
        Stop-T3RunnerProcessTree
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host 'Logon task removed. T3 data and .t3service files were kept.'
    }
    'uninstall-service' {
        if (-not (Test-Administrator)) { throw "Run this action in Administrator PowerShell: t3service uninstall-service" }
        $service = Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
        if (-not $service) { Write-Host 'Old Windows service is not installed'; break }
        $answer = Read-Host 'Remove the old boot-service registration? T3 data and the new logon task will be kept (y/N)'
        if ($answer -notmatch '^(y|yes)$') { Write-Host 'Cancelled'; break }
        if ($service.State -eq 'Running') {
            Stop-Service -Name $serviceName -Force
            (Get-Service -Name $serviceName).WaitForStatus('Stopped', [TimeSpan]::FromSeconds(30))
        }
        & sc.exe delete $serviceName
        if ($LASTEXITCODE -ne 0) { throw "sc.exe exited with code $LASTEXITCODE" }
        Write-Host 'Old boot service removed. Logon task and T3 data were kept.'
    }
}
