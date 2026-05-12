param(
  [switch]$Watch,
  [int]$IntervalSec = 5
)

$ErrorActionPreference = 'SilentlyContinue'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$runDir = Join-Path $root '.run'
$metaFile = Join-Path $runDir 'dev-processes.json'

function Get-PortInfo {
  param([int]$Port)

  $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($listener) {
    return [PSCustomObject]@{
      Port = $Port
      Listening = $true
      OwningProcess = $listener.OwningProcess
    }
  }

  return [PSCustomObject]@{
    Port = $Port
    Listening = $false
    OwningProcess = $null
  }
}

function Get-HttpStatus {
  param([string]$Url)

  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
    return "$($response.StatusCode) $($response.StatusDescription)"
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $code = [int]$_.Exception.Response.StatusCode
      return "$code (reachable)"
    }
    return 'unreachable'
  }
}

function Get-ProcessNameSafe {
  param([int]$ProcessId)

  if ($ProcessId -le 0) { return '' }
  $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($p) { return $p.ProcessName }
  return 'not found'
}

function Read-Meta {
  if (Test-Path $metaFile) {
    try {
      return Get-Content -Path $metaFile -Raw | ConvertFrom-Json
    } catch {
      return $null
    }
  }
  return $null
}

function Show-Status {
  $backend = Get-PortInfo -Port 8080
  $frontend = Get-PortInfo -Port 3000
  $backendHttp = Get-HttpStatus -Url 'http://localhost:8080'
  $frontendHttp = Get-HttpStatus -Url 'http://localhost:3000'
  $meta = Read-Meta

  $rows = @(
    [PSCustomObject]@{
      Service = 'backend'
      Port = 8080
      Listening = $backend.Listening
      Http = $backendHttp
      PortPid = $backend.OwningProcess
      PortProcess = (Get-ProcessNameSafe -ProcessId $backend.OwningProcess)
      ScriptPid = if ($meta) { [int]$meta.backendPid } else { $null }
      ScriptPidProcess = if ($meta) { Get-ProcessNameSafe -ProcessId ([int]$meta.backendPid) } else { '' }
    },
    [PSCustomObject]@{
      Service = 'frontend'
      Port = 3000
      Listening = $frontend.Listening
      Http = $frontendHttp
      PortPid = $frontend.OwningProcess
      PortProcess = (Get-ProcessNameSafe -ProcessId $frontend.OwningProcess)
      ScriptPid = if ($meta) { [int]$meta.frontendPid } else { $null }
      ScriptPidProcess = if ($meta) { Get-ProcessNameSafe -ProcessId ([int]$meta.frontendPid) } else { '' }
    }
  )

  Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  if ($meta -and $meta.startedAt) {
    Write-Host "StartedAt(from meta): $($meta.startedAt)"
  } else {
    Write-Host 'StartedAt(from meta): n/a'
  }

  ($rows | Format-Table -AutoSize | Out-String) | Write-Host
}

if ($IntervalSec -lt 1) { $IntervalSec = 1 }

if ($Watch) {
  while ($true) {
    Clear-Host
    Show-Status
    Start-Sleep -Seconds $IntervalSec
  }
} else {
  Show-Status
}
