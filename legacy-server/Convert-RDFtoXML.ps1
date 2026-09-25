$ErrorActionPreference = "Stop"

# -------------------- SETTINGS --------------------
$SearchRoot      = "C:\ASCON"
$OutputDir       = "C:\XML"
$RwConverterPath = "C:\Oracle\Middleware\as_1\bin\rwconverter.exe"
$ProcessTimeoutSeconds = 300   # 5 minutes timeout
$MaxThreads      = 4           # 1 / 2 / 4 / 8 / 16 depending on the machine

# Character set used by the reports (the produced XML files are WINDOWS-1256 = AR8MSWIN1256).
# Set to "" to fall back to the registry value.
$NlsLang         = "AMERICAN_AMERICA.AR8MSWIN1256"

# Optional: only process the .rdf paths listed in this file (one path per line, "#" = comment).
# Point it to the RDF_Failed.txt of a previous run to retry only the failures. "" = process everything.
$InputListFile   = ""

# $true = skip a report whose XML already exists and is newer than the .rdf
$SkipUpToDate    = $false

# JVM options for rwconverter's embedded Java (Oracle Reports reads REPORTS_JVM_OPTIONS).
# "-Xint" runs the old Java 6 runtime in interpreter-only mode. On this server the JIT stubs crash
# (EXCEPTION_ACCESS_VIOLATION in ntdll.dll) while rwconverter parses reports that have a JSP web layout;
# the interpreter path does not. Conversions take about a second each, so the slowdown does not matter.
# Set to "" to use the Oracle default.
$ReportsJvmOptions = "-Xint"

# --- LOGGING --------------------------------------
$DateSuffix     = Get-Date -Format "yyyy_MM_dd"
$LogDir         = "$OutputDir\Logs\$DateSuffix"
$LogFilePath    = "$LogDir\RDF_ConversionLog.txt"
$FailedListPath = "$LogDir\RDF_Failed.txt"
$ErrLogDir      = "$LogDir\RDF_Errors"       # one .log per failed report with rwconverter's output (+ JVM crash dump if any)

if (-not (Test-Path -LiteralPath $LogDir)) {
    [System.IO.Directory]::CreateDirectory($LogDir) | Out-Null
}

# --- ORACLE ENVIROMENT VARIABLES ------------------
$OracleHome     = "C:\Oracle\Middleware\as_1"
$OracleInstance = "C:\Oracle\Middleware\asinst_1"

$env:ORACLE_HOME     = $OracleHome
$env:ORACLE_INSTANCE = $OracleInstance
$env:REPORTS_PATH    = "$SearchRoot;$OracleHome\reports\templates"
$env:PATH            = "$OracleHome\bin;$OracleInstance\bin;" + $env:PATH
if (-not [string]::IsNullOrWhiteSpace($NlsLang))           { $env:NLS_LANG = $NlsLang }
if (-not [string]::IsNullOrWhiteSpace($ReportsJvmOptions)) { $env:REPORTS_JVM_OPTIONS = $ReportsJvmOptions }
# --------------------------------------------------

if (-not (Test-Path -LiteralPath $SearchRoot)) {
  throw "SearchRoot not accessible: $SearchRoot"
}
[System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null

if (-not (Test-Path -LiteralPath $RwConverterPath)) {
  throw "rwconverter not found at: $RwConverterPath"
}

# Scratch directory: rwconverter writes here, the file is copied to $OutputDir only on success,
# so a failed conversion never destroys the previous XML and nothing is written into $SearchRoot.
$WorkDir = Join-Path $env:TEMP ("RDF2XML_work_" + $PID)
[System.IO.Directory]::CreateDirectory($WorkDir) | Out-Null

Start-Transcript -Path $LogFilePath -Append

$SearchRootFull = [System.IO.Path]::GetFullPath($SearchRoot)
if (-not $SearchRootFull.EndsWith("\")) { $SearchRootFull += "\" }

# ---- Enumerate .rdf files ----
if (-not [string]::IsNullOrWhiteSpace($InputListFile)) {
    if (-not (Test-Path -LiteralPath $InputListFile)) { throw "InputListFile not found: $InputListFile" }
    $rdfList = @(Get-Content -LiteralPath $InputListFile |
                 ForEach-Object { $_.Trim() } |
                 Where-Object { $_ -ne "" -and -not $_.StartsWith("#") })
    Write-Host "Using input list: $InputListFile"
} else {
    $rdfList = @([System.IO.Directory]::EnumerateFiles($SearchRootFull, "*.rdf", [System.IO.SearchOption]::AllDirectories))
}

if ($rdfList.Count -eq 0) {
  Write-Host "No .rdf files found under: $SearchRoot"
  Stop-Transcript
  exit
}

Write-Host "Found $($rdfList.Count) .rdf file(s)."
Write-Host "NLS_LANG = $($env:NLS_LANG)"
if ($env:REPORTS_JVM_OPTIONS) { Write-Host "REPORTS_JVM_OPTIONS = $($env:REPORTS_JVM_OPTIONS)" }
Write-Host "Starting Parallel Processing with $MaxThreads Cores..."
Write-Host ""

# ====================================================================
# --- WORKER BLOCK: The code for the background threads ---
# ====================================================================
$WorkerBlock = {
    param($rdfPath, $SearchRootFull, $OutputDir, $WorkDir, $ErrLogDir, $RwConverterPath, $ProcessTimeoutSeconds, $SkipUpToDate)

    $result = [PSCustomObject]@{ Status = "OK"; Message = ""; Source = $rdfPath }
    $workXmlPath = $null
    $toolOutput  = ""
    $arguments   = ""
    $p           = $null
    $workOut     = $null

    try {
        if (-not [System.IO.File]::Exists($rdfPath)) { throw "Source file not found" }

        $rdfDirFull = [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($rdfPath))
        if (-not $rdfDirFull.StartsWith($SearchRootFull.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Input file not under SearchRoot"
        }

        $relDir = ""
        if ($rdfDirFull.Length -gt $SearchRootFull.Length) {
            $relDir = $rdfDirFull.Substring($SearchRootFull.Length).TrimStart("\")
        }
        $outDir  = if ([string]::IsNullOrWhiteSpace($relDir)) { $OutputDir } else { [System.IO.Path]::Combine($OutputDir, $relDir) }
        $workOut = if ([string]::IsNullOrWhiteSpace($relDir)) { $WorkDir }   else { [System.IO.Path]::Combine($WorkDir, $relDir) }
        [System.IO.Directory]::CreateDirectory($outDir)  | Out-Null
        [System.IO.Directory]::CreateDirectory($workOut) | Out-Null

        $baseName    = [System.IO.Path]::GetFileNameWithoutExtension($rdfPath)
        $xmlName     = "${baseName}_RDF.xml"
        $workXmlPath = [System.IO.Path]::Combine($workOut, $xmlName)
        $destXmlPath = [System.IO.Path]::Combine($outDir, $xmlName)

        if ($SkipUpToDate -and [System.IO.File]::Exists($destXmlPath) -and
            ([System.IO.File]::GetLastWriteTimeUtc($destXmlPath) -ge [System.IO.File]::GetLastWriteTimeUtc($rdfPath))) {
            $result.Status  = "SKIP"
            $result.Message = "SKIP: $rdfPath (XML already up to date)"
            return $result
        }

        if ([System.IO.File]::Exists($workXmlPath)) { [System.IO.File]::Delete($workXmlPath) }

        # ---- run rwconverter ----
        $arguments = 'source="{0}" dest="{1}" stype=rdffile dtype=xmlfile batch=yes overwrite=yes' -f $rdfPath, $workXmlPath

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $RwConverterPath
        $psi.Arguments              = $arguments
        $psi.WorkingDirectory       = $workOut
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $psi
        [void]$p.Start()

        # Read both streams asynchronously: without this a chatty process blocks on a full pipe
        # and the error text is lost.
        $stdoutTask = $p.StandardOutput.ReadToEndAsync()
        $stderrTask = $p.StandardError.ReadToEndAsync()

        $timedOut = $false
        if (-not $p.WaitForExit($ProcessTimeoutSeconds * 1000)) {
            try { $p.Kill() } catch {}
            $timedOut = $true
        }
        $p.WaitForExit()
        $exitCode   = $p.ExitCode
        $toolOutput = (($stdoutTask.Result, $stderrTask.Result) -join "`n").Trim()

        if ($timedOut) { throw "rwconverter timeout after $ProcessTimeoutSeconds seconds" }

        if ($exitCode -ne 0) {
            $lines  = $toolOutput -split "`r?`n"
            $reason = ($lines | Where-Object { $_ -match 'REP-\d+' } | Select-Object -First 1)
            if (-not $reason) { $reason = ($lines | Where-Object { $_ -match 'EXCEPTION_[A-Z_]+|Exception' } | Select-Object -First 1) }
            if (-not $reason) { $reason = ($lines | Where-Object { $_.Trim() -ne "" -and $_.Trim() -ne "#" } | Select-Object -First 1) }
            if (-not $reason) { $reason = "no output captured, see error log" }
            throw "rwconverter failed (ExitCode=$exitCode): $($reason.Trim().TrimStart('#').Trim())"
        }
        if (-not [System.IO.File]::Exists($workXmlPath)) { throw "Expected XML not found after conversion (ExitCode=0)" }
        if ((Get-Item -LiteralPath $workXmlPath).Length -eq 0) { throw "rwconverter produced an empty XML file" }

        # ---- replace the previous XML only now that we have a good one ----
        if ([System.IO.File]::Exists($destXmlPath)) {
            try { [System.IO.File]::SetAttributes($destXmlPath, [System.IO.FileAttributes]::Normal) } catch {}
        }
        $attempt = 0
        while ($true) {
            try {
                [System.IO.File]::Copy($workXmlPath, $destXmlPath, $true)
                break
            } catch {
                $attempt++
                if ($attempt -ge 5) { throw "Could not replace $destXmlPath ($($_.Exception.Message))" }
                Start-Sleep -Milliseconds 500   # transient lock (antivirus / indexer / open viewer)
            }
        }
        [System.IO.File]::Delete($workXmlPath)

        $result.Message = "OK  : $rdfPath -> $destXmlPath"
    }
    catch {
        $result.Status  = "FAIL"
        $result.Message = "FAIL: $rdfPath ($($_.Exception.Message))"
        try {
            $errRel = if ([string]::IsNullOrWhiteSpace($relDir)) { $ErrLogDir } else { [System.IO.Path]::Combine($ErrLogDir, $relDir) }
            [System.IO.Directory]::CreateDirectory($errRel) | Out-Null
            $errFile = [System.IO.Path]::Combine($errRel, ([System.IO.Path]::GetFileNameWithoutExtension($rdfPath) + ".log"))
            $srcInfo = ""
            try { $fi = Get-Item -LiteralPath $rdfPath; $srcInfo = "$($fi.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))  size=$($fi.Length)" } catch {}
            $lines = @(
                "Source   : $rdfPath",
                "Modified : $srcInfo",
                "Command  : $RwConverterPath $arguments",
                "Error    : $($_.Exception.Message)",
                "",
                "---- rwconverter output ----",
                $toolOutput
            )
            [System.IO.File]::WriteAllLines($errFile, $lines)
            # keep the JVM crash dump (hs_err_pid<pid>.log is written to the process working directory);
            # the pid comes from the crash banner, falling back to the process we started
            if ($workOut) {
                $pids = @()
                if ($toolOutput -match 'pid=(\d+)') { $pids += $matches[1] }
                if ($p) { $pids += $p.Id }
                foreach ($crashPid in $pids) {
                    $dump = [System.IO.Path]::Combine($workOut, "hs_err_pid$crashPid.log")
                    if ([System.IO.File]::Exists($dump)) {
                        $dumpDest = [System.IO.Path]::Combine($errRel, ([System.IO.Path]::GetFileNameWithoutExtension($rdfPath) + "_hs_err.log"))
                        [System.IO.File]::Copy($dump, $dumpDest, $true)
                        [System.IO.File]::Delete($dump)
                        break
                    }
                }
            }
        } catch {}
        if ($workXmlPath -and [System.IO.File]::Exists($workXmlPath)) { try { [System.IO.File]::Delete($workXmlPath) } catch {} }
    }
    return $result
}

# ====================================================================
# --- RUNSPACE POOL SETUP ---
# ====================================================================
$pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$pool.Open()
$jobs = [System.Collections.Generic.List[psobject]]::new()

foreach ($rdfPath in $rdfList) {
    $ps = [powershell]::Create().AddScript($WorkerBlock).
        AddArgument($rdfPath).AddArgument($SearchRootFull).AddArgument($OutputDir).AddArgument($WorkDir).
        AddArgument($ErrLogDir).AddArgument($RwConverterPath).AddArgument($ProcessTimeoutSeconds).AddArgument($SkipUpToDate)
    $ps.RunspacePool = $pool
    $jobs.Add([PSCustomObject]@{ PowerShell = $ps; Handle = $ps.BeginInvoke() })
}

$converted = 0
$failed    = 0
$skipped   = 0
$completedJobs = 0
$totalJobs = $jobs.Count
$failedSources = [System.Collections.Generic.List[string]]::new()

# ====================================================================
# --- MONITORING LOOP ---
# ====================================================================
while ($jobs.Count -gt 0) {
    $doneJobs = @($jobs | Where-Object { $_.Handle.IsCompleted })
    foreach ($job in $doneJobs) {
        $result = $job.PowerShell.EndInvoke($job.Handle)
        switch ($result.Status) {
            "OK"   { $converted++; Write-Host $result.Message }
            "SKIP" { $skipped++;   Write-Host $result.Message }
            default {
                $failed++
                $failedSources.Add($result.Source)
                Write-Warning $result.Message
            }
        }
        $job.PowerShell.Dispose()
        $jobs.Remove($job) | Out-Null
        $completedJobs++
        Write-Progress -Activity "RDF2XML ($MaxThreads Threads)" -Status "Processed $completedJobs / $totalJobs files" -PercentComplete (($completedJobs / $totalJobs) * 100)
    }
    Start-Sleep -Milliseconds 50
}

$pool.Close()
$pool.Dispose()
try { Remove-Item -LiteralPath $WorkDir -Recurse -Force -ErrorAction SilentlyContinue } catch {}

Write-Progress -Activity "RDF2XML ($MaxThreads Threads)" -Completed
Write-Host ""
Write-Host ("Done. Converted: {0} | Skipped: {1} | Failed: {2}" -f $converted, $skipped, $failed)

if ($failed -gt 0) {
    [System.IO.File]::WriteAllLines($FailedListPath, $failedSources)
    Write-Host "Failed list  : $FailedListPath   (set `$InputListFile to this path to retry only these)"
    Write-Host "Error details: $ErrLogDir"
}

Stop-Transcript
