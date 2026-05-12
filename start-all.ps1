param(
  [int]$TimeoutSec = 60,
  [int]$PollIntervalMs = 1000
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendDir = Join-Path $root 'SOFT-rear'
$frontendDir = Join-Path $root 'web'
$runDir = Join-Path $root '.run'
$metaFile = Join-Path $runDir 'dev-processes.json'

$jdkHome = 'C:\Program Files\Eclipse Adoptium\jdk-17.0.18.8-hotspot'
$nodeBin = 'C:\Program Files\nodejs'

$javaExe = Join-Path $jdkHome 'bin\java.exe'
$nodeExe = Join-Path $nodeBin 'node.exe'
$npmCmd = Join-Path $nodeBin 'npm.cmd'

if (!(Test-Path $backendDir)) { throw "Backend directory not found: $backendDir" }
if (!(Test-Path $frontendDir)) { throw "Frontend directory not found: $frontendDir" }
if (!(Test-Path $javaExe)) { throw "Java 17 not found: $javaExe" }
if (!(Test-Path $nodeExe)) { throw "Node.js not found: $nodeExe" }
if (!(Test-Path $npmCmd)) { throw "npm not found: $npmCmd" }

if ($TimeoutSec -lt 5) { $TimeoutSec = 5 }
if ($PollIntervalMs -lt 200) { $PollIntervalMs = 200 }

New-Item -Path $runDir -ItemType Directory -Force | Out-Null

$backendLogOut = Join-Path $runDir 'backend.out.log'
$backendLogErr = Join-Path $runDir 'backend.err.log'
$frontendLogOut = Join-Path $runDir 'frontend.out.log'
$frontendLogErr = Join-Path $runDir 'frontend.err.log'

$backendCommand = @"
`$env:JAVA_HOME = '$jdkHome'
`$javaBin = Join-Path `$env:JAVA_HOME 'bin'
`$env:Path = `$javaBin + ';' + `$env:Path
Set-Location '$backendDir'
.\mvnw.cmd spring-boot:run
"@

$frontendCommand = @"
`$env:Path = '$nodeBin;`$env:Path'
Set-Location '$frontendDir'
& '$npmCmd' run dev -- --host
"@

function Test-PortListening {
  param([int]$Port)

  $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
  return [bool]$listener
}

function Test-HttpReachable {
  param(
    [string]$Url,
    [int[]]$AllowedStatusCodes
  )

  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
    return ($AllowedStatusCodes -contains [int]$response.StatusCode)
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $code = [int]$_.Exception.Response.StatusCode
      return ($AllowedStatusCodes -contains $code)
    }
    return $false
  }
}

function Stop-IfRunning {
  param([int]$ProcessId)

  if ($ProcessId -le 0) { return }
  $p = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
  if ($p) {
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
  }
}

function Stop-ByPort {
  param([int]$Port)

  $listeners = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  foreach ($listener in $listeners) {
    if ($listener.OwningProcess -gt 0) {
      Stop-Process -Id $listener.OwningProcess -Force -ErrorAction SilentlyContinue
    }
  }
}

function Wait-ServiceReady {
  param(
    [string]$Name,
    [int]$Port,
    [string]$Url,
    [int[]]$AllowedStatusCodes,
    [int]$ParentProcessId,
    [int]$TimeoutSeconds,
    [int]$IntervalMs
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $parentAlive = Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue
    if (-not $parentAlive) {
      throw "$Name start process exited early."
    }

    $portOk = Test-PortListening -Port $Port
    $httpOk = Test-HttpReachable -Url $Url -AllowedStatusCodes $AllowedStatusCodes

    if ($portOk -and $httpOk) {
      Write-Host "$Name ready: $Url"
      return
    }

    Start-Sleep -Milliseconds $IntervalMs
  }

  throw "$Name startup timeout after $TimeoutSeconds seconds."
}

$backendProcess = Start-Process -FilePath 'powershell.exe' `
  -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $backendCommand `
  -PassThru -WindowStyle Minimized `
  -RedirectStandardOutput $backendLogOut -RedirectStandardError $backendLogErr

$frontendProcess = Start-Process -FilePath 'powershell.exe' `
  -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $frontendCommand `
  -PassThru -WindowStyle Minimized `
  -RedirectStandardOutput $frontendLogOut -RedirectStandardError $frontendLogErr

$meta = [PSCustomObject]@{
  backendPid = $backendProcess.Id
  frontendPid = $frontendProcess.Id
  startedAt = (Get-Date).ToString('s')
  backendOutLog = $backendLogOut
  backendErrLog = $backendLogErr
  frontendOutLog = $frontendLogOut
  frontendErrLog = $frontendLogErr
}

$meta | ConvertTo-Json | Set-Content -Path $metaFile -Encoding UTF8

try {
  Wait-ServiceReady -Name 'backend' -Port 8080 -Url 'http://localhost:8080' -AllowedStatusCodes @(200, 401, 403, 404) `
    -ParentProcessId $backendProcess.Id -TimeoutSeconds $TimeoutSec -IntervalMs $PollIntervalMs

  Wait-ServiceReady -Name 'frontend' -Port 3000 -Url 'http://localhost:3000' -AllowedStatusCodes @(200) `
    -ParentProcessId $frontendProcess.Id -TimeoutSeconds $TimeoutSec -IntervalMs $PollIntervalMs
} catch {
  Write-Error $_.Exception.Message
  Stop-IfRunning -ProcessId $backendProcess.Id
  Stop-IfRunning -ProcessId $frontendProcess.Id
  Stop-ByPort -Port 8080
  Stop-ByPort -Port 3000
  if (Test-Path $metaFile) { Remove-Item -Path $metaFile -Force }
  exit 1
}

Write-Host "Started backend PID: $($backendProcess.Id)"
Write-Host "Started frontend PID: $($frontendProcess.Id)"
Write-Host "Meta file: $metaFile"
Write-Host "Backend URL: http://localhost:8080"
Write-Host "Frontend URL: http://localhost:3000"
Write-Host "Startup check: passed"
