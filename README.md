# win-t3service

A small Windows helper for running the T3 Code server at user logon when T3 Code's native `t3 service install` is unavailable on Windows. It uses Task Scheduler with the signed-in user's interactive session—no account password is stored and no console window is shown.

This is a community workaround, not an official T3 Code component. T3 Code itself is installed separately and is not included here.

## Relationship to T3 Code

This helper launches the `t3` CLI distributed with the official [T3 Code desktop app](https://github.com/pingdotgg/t3code). T3 Code's native background-service installer supports Linux with systemd and macOS with launchd; it currently reports Windows (`win32`) as unsupported. This project uses Windows Task Scheduler as a user-logon alternative. It is not affiliated with or endorsed by the T3 Code maintainers.

- [T3 Code repository](https://github.com/pingdotgg/t3code)
- [T3 Code installation guide](https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md)
- [T3 Code background-service guide](https://github.com/pingdotgg/t3code/blob/main/docs/user/background-service.md)

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
t3service pair
t3service uninstall
```

The task starts at **user logon**, not before sign-in. It listens on `127.0.0.1:3773`; open `http://127.0.0.1:3773` in a browser on the host for local access. `start` prints this URL, and `status` reports it. If you need a fresh pairing code, run `t3service pair` and use the displayed link/QR promptly; T3 pairing tokens are single-use and expire after five minutes. Pair once—the browser session is retained separately, so a permanent code is neither needed nor stored. Stop/restart terminates the task-owned T3 process tree, so wait for active agent turns to finish first. `status` reports if a runner process was left behind.

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
