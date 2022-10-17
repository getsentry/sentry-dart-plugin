$ErrorActionPreference = "Stop"
Set-StrictMode -Version latest

function RunApiServer([string] $ServerScript, [string] $Uri = "http://127.0.0.1:8000")
{
    $result = "" | Select-Object -Property process, outFile, errFile, stop, output, dispose
    Write-Host "Starting the $ServerScript on $Uri"
    $result.outFile = New-TemporaryFile
    $result.errFile = New-TemporaryFile

    $result.process = Start-Process "python3" -ArgumentList @("$PSScriptRoot/$ServerScript.py", $Uri) `
        -NoNewWindow -PassThru -RedirectStandardOutput $result.outFile -RedirectStandardError $result.errFile

    $result.output = { "$(Get-Content $result.outFile -Raw)`n$(Get-Content $result.errFile -Raw)" }.GetNewClosure()

    $result.dispose = {
        $result.stop.Invoke()

        Write-Host "Server stdout:" -ForegroundColor Yellow
        $stdout = Get-Content $result.outFile -Raw
        Write-Host $stdout

        Write-Host "Server stderr:" -ForegroundColor Yellow
        $stderr = Get-Content $result.errFile -Raw
        Write-Host $stderr

        Remove-Item $result.outFile -ErrorAction Continue
        Remove-Item $result.errFile -ErrorAction Continue
        return "$stdout`n$stderr"
    }.GetNewClosure()

    $result.stop = {
        # Stop the HTTP server
        Write-Host "Stopping the $ServerScript ... " -NoNewline
        try
        {
            Write-Host (Invoke-WebRequest -Uri "$Uri/STOP").StatusDescription
        }
        catch
        {
            Write-Host "/STOP request failed: $_ - killing the server process instead"
            $result.process | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        $result.process | Wait-Process -Timeout 10 -ErrorAction Continue
        $result.stop = {}
    }.GetNewClosure()

    # The process shouldn't finish by itself, if it did, there was an error, so let's check that
    Start-Sleep -Second 1
    if ($result.process.HasExited)
    {
        Write-Host "Couldn't start the $ServerScript" -ForegroundColor Red
        Write-Host "Standard Output:" -ForegroundColor Yellow
        Get-Content $result.outFile
        Write-Host "Standard Error:" -ForegroundColor Yellow
        Get-Content $result.errFile
        Remove-Item $result.outFile
        Remove-Item $result.errFile
        exit 1
    }

    return $result
}

function RunWithApiServer([ScriptBlock] $Callback)
{
    # start the server
    $httpServer = RunApiServer "test-server"
    # run the test
    try
    {
        $Callback.Invoke()
    }
    finally
    {
        $httpServer.stop.Invoke()
    }

    return $httpServer.dispose.Invoke()
}

function CheckSymbolServerOutput([string] $symbolServerOutput)
{
    Write-Host "Checking symbol server output" -ForegroundColor Yellow

    if ($IsWindows)
    {
        $expectedFiles = @(
            "libapp.so: count=6",
            'libflutter.so: count=6',
            "libhello_santry.so: count=12",
            "libhello_santry.so.sym: count=4"
        )
    }
    else
    {
        $expectedFiles = @(
            "app.so: count=3",
            "libapp.so: count=3",
            'libflutter.so: count=6',
            "libhello_santry.so: count=12",
            "libhello_santry.so.sym: count=4"
        )
    }

    Write-Host 'Verifying debug symbol upload...'
    $successful = $true
    :nextExpectedFile foreach ($file in $expectedFiles)
    {
        $alternatives = ($file -is [array]) ? $file : @($file)
        foreach ($file in $alternatives)
        {
            # It's enough if a single symbol alternative is found
            if ($symbolServerOutput -match "  $([Regex]::Escape($file))\b")
            {
                Write-Host "  $file - OK"
                continue nextExpectedFile
            }
        }
        # Note: control only gets here if none of the alternatives match...
        $successful = $false
        $fileWithoutCount = $file.Substring(0, $file.Length - 1)
        $filePattern = [Regex]::new('(?<=' + "$([Regex]::Escape($fileWithoutCount))" + ')[\w]+')
        $actualCount = $filePattern.Matches($symbolServerOutput)

        Write-Host "  $alternatives - MISSING `n    Server received '$actualCount' instead." -ForegroundColor Red
    }
    if ($successful)
    {
        Write-Host 'All expected debug symbols have been uploaded' -ForegroundColor Green
    }
    else
    {
        exit 1
    }
}
$serverOutput = RunWithApiServer -Callback {
    $pluginOutput = dart run sentry_dart_plugin | ForEach-Object {
        Write-Host $_
        $_
    }

    if (!"$pluginOutput".contains('sourcemap at main.dart.js.map'))
    {
        Write-Error "Source map not uploaded"
    }
}

CheckSymbolServerOutput $serverOutput

Write-Host "Test passed" -ForegroundColor Green
