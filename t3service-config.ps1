# T3SERVICE_HOST and T3SERVICE_PORT are optional user environment variables,
# read by run-t3-logon.ps1 and t3service.ps1. Set T3SERVICE_HOST=0.0.0.0 to
# accept LAN or Tailscale clients; the Windows firewall is then the only gate.
# Both values reach cmd.exe, so anything that is not a host name, IP address,
# or port number falls back to the default.
function Test-T3ServiceHost([string]$value) {
    # An IPv4 address in dotted-quad form, an IPv6 address, or a DNS host name.
    if ($value -notmatch '^[A-Za-z0-9.:-]+$') { return $false }
    $ip = $null
    if ($value.Contains(':')) {
        return [Net.IPAddress]::TryParse($value, [ref]$ip) -and $ip.AddressFamily -eq 'InterNetworkV6'
    }
    if ($value -match '^[0-9.]+$') {
        return [Net.IPAddress]::TryParse($value, [ref]$ip) -and $ip.ToString() -eq $value
    }
    $label = '[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    return $value.Length -le 253 -and $value -match "^$label(\.$label)*$"
}

function Get-T3ServiceConfig {
    $warnings = @()
    $hostName = '127.0.0.1'
    if ($env:T3SERVICE_HOST) {
        if (Test-T3ServiceHost $env:T3SERVICE_HOST) { $hostName = $env:T3SERVICE_HOST }
        else { $warnings += "[t3service] ignoring invalid T3SERVICE_HOST; using $hostName" }
    }
    $port = 3773
    if ($env:T3SERVICE_PORT) {
        $parsed = 0
        if ([int]::TryParse($env:T3SERVICE_PORT, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le 65535) { $port = $parsed }
        else { $warnings += "[t3service] ignoring invalid T3SERVICE_PORT; using $port" }
    }
    [pscustomobject]@{ Host = $hostName; Port = $port; Warnings = $warnings }
}
