# win-t3service

A small Windows helper for running the T3 Code server at user logon when T3 Code's native `t3 service install` is unavailable on Windows. It uses Task Scheduler with the signed-in user's interactive session—no account password is stored and no console window is shown.

This is a community workaround, not an official T3 Code component. T3 Code itself is installed separately and is not included here.

## Requirements

- Windows 10/11
- T3 Code desktop app with its `t3` command installed (`%USERPROFILE%\.t3\bin\t3.cmd`)
- Windows PowerShell (included with Windows)

## Install

Clone this repository to `%USERPROFILE%\.t3service`, then run:

```powershell
git clone https://github.com/mynameistito/win-t3service.git "$HOME\.t3service"
Set-Location "$HOME\.t3service"
.\install.ps1
```

The installer copies the `t3service` command shim into `%USERPROFILE%\.t3\bin` and registers a Task Scheduler task for your next sign-in. It does not start the server immediately. Ensure `%USERPROFILE%\.t3\bin` is on `PATH`; open a new terminal if you just installed T3's CLI.

If the T3 desktop app's local environment is enabled, turn it off before starting this task to avoid two servers using the same T3 data directory.

## Commands

```powershell
t3service status
t3service start
t3service stop
t3service restart
t3service logs
t3service logs -Follow
t3service uninstall
```

The task starts at **user logon**, not before sign-in. `start` and `stop` control the task now; `uninstall` removes the task but keeps your T3 data and logs.

### Updating T3 Code

The task launches the T3 CLI bundled with the desktop app. Stop the task, update T3 Code with its normal desktop updater, then start the task again:

```powershell
t3service stop
# Update T3 Code in the desktop app, then:
t3service start
```

### Removing the old boot service

If you previously installed the experimental WinSW Windows service, remove its registration from an elevated PowerShell window:

```powershell
t3service uninstall-service
```

This removes only the old Windows service registration. It keeps the logon task and T3 data.

## Logs and data

Task output is written to timestamped files under `%USERPROFILE%\.t3service\logs`. Those logs and the local WinSW executable/configuration are ignored by Git and must not be committed. T3 projects, threads, and credentials remain in `%USERPROFILE%\.t3` and are not part of this repository.

## Contributing

Issues and pull requests are welcome. Test script syntax with PowerShell's parser before submitting changes; test task behavior on a non-production Windows account because installing or starting it changes the current user's scheduled tasks and T3 server process.

## License

MIT. See [LICENSE](LICENSE).
