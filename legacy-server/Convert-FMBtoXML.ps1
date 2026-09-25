$ErrorActionPreference = "Stop"

# -------------------- SETTINGS --------------------
$SearchRoot   = "C:\ASCON"
$OutputDir    = "C:\XML"
$ProcessTimeoutSeconds = 300   # 5 minutes timeout for NORMAL files
$MaxThreads   = 4              # 1 / 2 / 4 / 8 / 16 depending on the machine

# Character set used by the forms (the produced XML files are WINDOWS-1256 = AR8MSWIN1256).
# Set to "" to fall back to the registry value.
$NlsLang      = "AMERICAN_AMERICA.AR8MSWIN1256"

# Optional: only process the .fmb paths listed in this file (one path per line, "#" = comment).
# Point it to the FMB_Failed.txt of a previous run to retry only the failures. "" = process everything.
$InputListFile = ""

# $true = skip a form whose XML already exists and is newer than the .fmb
$SkipUpToDate  = $false

# --- LOGGING --------------------------------------
$DateSuffix     = Get-Date -Format "yyyy_MM_dd"
$LogDir         = "$OutputDir\Logs\$DateSuffix"
$LogFilePath    = "$LogDir\FMB_ConversionLog.txt"
$FailedListPath = "$LogDir\FMB_Failed.txt"
$ErrLogDir      = "$LogDir\FMB_Errors"       # one .log per failed form with Forms2XML's output

if (-not (Test-Path -LiteralPath $LogDir)) {
    [System.IO.Directory]::CreateDirectory($LogDir) | Out-Null
}

# --- ORACLE ENVIROMENT VARIABLES ------------------
$OracleHome     = "C:\Oracle\Middleware\as_1"
$OracleInstance = "C:\Oracle\Middleware\asinst_1"

$env:ORACLE_HOME     = $OracleHome
$env:ORACLE_INSTANCE = $OracleInstance
$env:FORMS_PATH      = "$SearchRoot;$OracleHome\forms"
$env:PATH            = "$OracleInstance\bin;$OracleHome\bin;" + $env:PATH
if (-not [string]::IsNullOrWhiteSpace($NlsLang)) { $env:NLS_LANG = $NlsLang }

# --- DIRECT JAVA EXECUTION VARIABLES --------------
$JavaExe   = "$OracleHome\jdk\bin\java.exe"
$ClassPath = "$OracleHome\jlib\frmxmltools.jar;$OracleHome\jlib\frmjdapi.jar;$OracleHome\lib\xmlparserv2.jar;$OracleHome\lib\xschema.jar"
$MainClass = "oracle.forms.util.xmltools.Forms2XML"
# --------------------------------------------------

if (-not (Test-Path -LiteralPath $SearchRoot)) {
  throw "SearchRoot not accessible: $SearchRoot"
}
[System.IO.Directory]::CreateDirectory($OutputDir) | Out-Null

if (-not (Test-Path -LiteralPath $JavaExe)) {
  throw "Java executable not found at: $JavaExe"
}

# NOTE: Forms2XML 11.1 ignores OUTPUTDIR and always writes <name>_fmb.xml beside the source .fmb.
# The script therefore passes OVERWRITE=YES, picks the file up from there and copies it to $OutputDir
# only on success, so a failed conversion never destroys the previous XML.

Start-Transcript -Path $LogFilePath -Append

$SearchRootFull = [System.IO.Path]::GetFullPath($SearchRoot)
if (-not $SearchRootFull.EndsWith("\")) { $SearchRootFull += "\" }

# ---- Enumerate .fmb files ----
if (-not [string]::IsNullOrWhiteSpace($InputListFile)) {
    if (-not (Test-Path -LiteralPath $InputListFile)) { throw "InputListFile not found: $InputListFile" }
    $fmbList = @(Get-Content -LiteralPath $InputListFile |
                 ForEach-Object { $_.Trim() } |
                 Where-Object { $_ -ne "" -and -not $_.StartsWith("#") })
    Write-Host "Using input list: $InputListFile"
} else {
    $fmbList = @([System.IO.Directory]::EnumerateFiles($SearchRootFull, "*.fmb", [System.IO.SearchOption]::AllDirectories))
}

if ($fmbList.Count -eq 0) {
  Write-Host "No .fmb files found under: $SearchRoot"
  Stop-Transcript
  exit
}

Write-Host "Found $($fmbList.Count) total .fmb file(s)."
Write-Host "NLS_LANG = $($env:NLS_LANG)"
Write-Host "======================================================"
Write-Host "Parallel Processing ($MaxThreads Cores)"
Write-Host "======================================================"

# ====================================================================
# --- WORKER BLOCK: The code for the background threads ---
# ====================================================================
$WorkerBlock = {
    param($fmbPath, $SearchRootFull, $OutputDir, $ErrLogDir, $JavaExe, $ClassPath, $MainClass, $ProcessTimeoutSeconds, $SkipUpToDate)

    $result = [PSCustomObject]@{ Status = "OK"; Message = ""; Source = $fmbPath }
    $srcXmlPath = $null
    $toolOutput  = ""
    $arguments   = ""

    try {
        if (-not [System.IO.File]::Exists($fmbPath)) { throw "Source file not found" }

        $fmbDirFull = [System.IO.Path]::GetFullPath([System.IO.Path]::GetDirectoryName($fmbPath))
        if (-not $fmbDirFull.StartsWith($SearchRootFull.TrimEnd("\"), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Input file not under SearchRoot"
        }

        $relDir = ""
        if ($fmbDirFull.Length -gt $SearchRootFull.Length) {
            $relDir = $fmbDirFull.Substring($SearchRootFull.Length).TrimStart("\")
        }
        $outDir = if ([string]::IsNullOrWhiteSpace($relDir)) { $OutputDir } else { [System.IO.Path]::Combine($OutputDir, $relDir) }
        [System.IO.Directory]::CreateDirectory($outDir) | Out-Null

        $baseName    = [System.IO.Path]::GetFileNameWithoutExtension($fmbPath)
        $xmlName     = $baseName + "_fmb.xml"
        $srcXmlPath  = [System.IO.Path]::Combine($fmbDirFull, $xmlName)   # Forms2XML always writes here
        $destXmlPath = [System.IO.Path]::Combine($outDir, $xmlName)

        if ($SkipUpToDate -and [System.IO.File]::Exists($destXmlPath) -and
            ([System.IO.File]::GetLastWriteTimeUtc($destXmlPath) -ge [System.IO.File]::GetLastWriteTimeUtc($fmbPath))) {
            $result.Status  = "SKIP"
            $result.Message = "SKIP: $fmbPath (XML already up to date)"
            return $result
        }

        # A leftover from an earlier run must not be mistaken for this run's result
        if ([System.IO.File]::Exists($srcXmlPath)) {
            try { [System.IO.File]::SetAttributes($srcXmlPath, [System.IO.FileAttributes]::Normal) } catch {}
            [System.IO.File]::Delete($srcXmlPath)
        }

        # ---- run Forms2XML ----
        $arguments = '-classpath "{0}" {1} OVERWRITE=YES "{2}"' -f $ClassPath, $MainClass, $fmbPath

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $JavaExe
        $psi.Arguments              = $arguments
        $psi.WorkingDirectory       = $fmbDirFull
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

        if ($timedOut) { throw "Forms2XML timeout after $ProcessTimeoutSeconds seconds" }

        if ($exitCode -ne 0) {
            $reason = ($toolOutput -split "`r?`n" | Where-Object { $_ -match '(FRM-\d+|Exception|Error)' } | Select-Object -First 1)
            if (-not $reason) { $reason = ($toolOutput -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1) }
            if (-not $reason) { $reason = "no output captured, see error log" }
            throw "Forms2XML failed (ExitCode=$exitCode): $($reason.Trim())"
        }

        if (-not [System.IO.File]::Exists($srcXmlPath)) {
            $reason = ($toolOutput -split "`r?`n" | Where-Object { $_ -match '(FRM-\d+|Exception|Error|already exists)' } | Select-Object -First 1)
            if ($reason) { throw "Expected XML not found after conversion (ExitCode=0): $($reason.Trim())" }
            throw "Expected XML not found after conversion (ExitCode=0)"
        }
        if ((Get-Item -LiteralPath $srcXmlPath).Length -eq 0) { throw "Forms2XML produced an empty XML file" }

        # ---- replace the previous XML only now that we have a good one ----
        if ([System.IO.File]::Exists($destXmlPath)) {
            try { [System.IO.File]::SetAttributes($destXmlPath, [System.IO.FileAttributes]::Normal) } catch {}
        }
        $attempt = 0
        while ($true) {
            try {
                [System.IO.File]::Copy($srcXmlPath, $destXmlPath, $true)
                break
            } catch {
                $attempt++
                if ($attempt -ge 5) { throw "Could not replace $destXmlPath ($($_.Exception.Message))" }
                Start-Sleep -Milliseconds 500   # transient lock (antivirus / indexer / open viewer)
            }
        }
        [System.IO.File]::Delete($srcXmlPath)

        $result.Message = "OK  : $fmbPath -> $destXmlPath"
    }
    catch {
        $result.Status  = "FAIL"
        $result.Message = "FAIL: $fmbPath ($($_.Exception.Message))"
        try {
            $errRel = if ([string]::IsNullOrWhiteSpace($relDir)) { $ErrLogDir } else { [System.IO.Path]::Combine($ErrLogDir, $relDir) }
            [System.IO.Directory]::CreateDirectory($errRel) | Out-Null
            $errFile = [System.IO.Path]::Combine($errRel, ([System.IO.Path]::GetFileNameWithoutExtension($fmbPath) + ".log"))
            $lines = @(
                "Source   : $fmbPath",
                "Command  : $JavaExe $arguments",
                "Error    : $($_.Exception.Message)",
                "",
                "---- Forms2XML output ----",
                $toolOutput
            )
            [System.IO.File]::WriteAllLines($errFile, $lines)
        } catch {}
        if ($srcXmlPath -and [System.IO.File]::Exists($srcXmlPath)) { try { [System.IO.File]::Delete($srcXmlPath) } catch {} }
    }
    return $result
}

# ====================================================================
# --- PARALLEL EXECUTION ---
# ====================================================================
$pool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$pool.Open()
$jobs = [System.Collections.Generic.List[psobject]]::new()

foreach ($fmbPath in $fmbList) {
    $ps = [powershell]::Create().AddScript($WorkerBlock).
        AddArgument($fmbPath).AddArgument($SearchRootFull).AddArgument($OutputDir).AddArgument($ErrLogDir).
        AddArgument($JavaExe).AddArgument($ClassPath).AddArgument($MainClass).AddArgument($ProcessTimeoutSeconds).AddArgument($SkipUpToDate)
    $ps.RunspacePool = $pool
    $jobs.Add([PSCustomObject]@{ PowerShell = $ps; Handle = $ps.BeginInvoke() })
}

$converted = 0
$failed    = 0
$skipped   = 0
$completedJobs = 0
$totalJobs = $jobs.Count
$failedSources = [System.Collections.Generic.List[string]]::new()

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
        Write-Progress -Activity "Forms2XML Parallel Processing ($MaxThreads Threads)" -Status "Processed $completedJobs / $totalJobs files" -PercentComplete (($completedJobs / $totalJobs) * 100)
    }
    Start-Sleep -Milliseconds 50
}
$pool.Close()
$pool.Dispose()

Write-Progress -Activity "Forms2XML Parallel Processing ($MaxThreads Threads)" -Completed
Write-Host ""
Write-Host ("Done. Converted: {0} | Skipped: {1} | Failed: {2}" -f $converted, $skipped, $failed)

if ($failed -gt 0) {
    [System.IO.File]::WriteAllLines($FailedListPath, $failedSources)
    Write-Host "Failed list  : $FailedListPath   (set `$InputListFile to this path to retry only these)"
    Write-Host "Error details: $ErrLogDir"
}

Stop-Transcript
