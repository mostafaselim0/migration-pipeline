# Run SQLcl commands.  Usage:  .\sqlcl.ps1 -User <schema> [-Dsn host:port/service] -Commands "apex export ...","exit"   or  -File script.sql
param([Parameter(Mandatory=$true)][string]$User, [string]$Dsn = "localhost:1521/ORCLPDB", [string[]]$Commands, [string]$File,
      [string]$WorkDir = (Get-Location).Path, [string]$Sql = $(if ($env:MP_SQLCL) { $env:MP_SQLCL } else { "C:\sqlcl\bin\sql.exe" }))
$pw = [Environment]::GetEnvironmentVariable(($User.ToUpper() + "_PWD"), "User")
$tmp = Join-Path $env:TEMP ("sqlcl_" + [guid]::NewGuid().ToString("N") + ".sql")
if ($File) { $body = Get-Content -Raw -LiteralPath $File } else { $body = ($Commands -join "`r`n") }
if ($body -notmatch '(?im)^\s*exit\s*;?\s*$') { $body += "`r`nexit`r`n" }
[IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding($false)))
$OutputEncoding = [System.Text.Encoding]::ASCII
Push-Location $WorkDir
try { "" | & $Sql -S -thin "$User/$pw@//$Dsn" "@$tmp" }
finally { Pop-Location; [IO.File]::WriteAllText($tmp, "") }


