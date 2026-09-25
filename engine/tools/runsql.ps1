# Run a SQL file with SQL*Plus in UTF-8.  Usage: .\runsql.ps1 file.sql -User <schema>|sys [-Dsn host:port/service] [-Quiet]
# The password of a schema user comes from the Windows User environment variable <USER>_PWD.
param([Parameter(Mandatory=$true)][string]$File, [Parameter(Mandatory=$true)][string]$User, [string]$Dsn = "localhost:1521/ORCLPDB", [switch]$Quiet)
$pdb = $Dsn.Split("/")[-1]
$env:NLS_LANG = "AMERICAN_AMERICA.AL32UTF8"
$wrap = Join-Path $env:TEMP ("run_" + [guid]::NewGuid().ToString("N") + ".sql")
$full = (Resolve-Path -LiteralPath $File).Path
$dir = Split-Path $full
$pre = if ($User -eq "sys") { "alter session set container=$pdb;`r`n" } else { "alter session set nls_length_semantics=CHAR;`r`n" }
[IO.File]::WriteAllText($wrap, "set sqlblanklines on`r`n" + $pre + "@`"$full`"`r`nexit`r`n", (New-Object System.Text.UTF8Encoding($false)))
Push-Location $dir
try {
  if ($User -eq "sys") { $out = & sqlplus -S -L "/ as sysdba" "@$wrap" }
  else { $pw = [Environment]::GetEnvironmentVariable(($User.ToUpper() + "_PWD"), "User"); $out = & sqlplus -S -L "$User/$pw@$Dsn" "@$wrap" }
} finally { Pop-Location; [IO.File]::WriteAllText($wrap, "") }
if ($Quiet) { $out | Where-Object { $_ -match 'ORA-|PLS-|SP2-|Warning|ERROR|error' } } else { $out }
