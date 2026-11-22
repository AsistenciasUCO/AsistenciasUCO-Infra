# Utilidades compartidas: resolucion de Python 3 de Windows y aprovisionamiento aditivo del PDP.
# Se carga con dot-sourcing desde stack.ps1 y cargar-datos-variados.ps1.

function Test-PythonUsable {
    # True si el ejecutable corre `-c "import sys"` en 15 s. Descarta el alias de la Microsoft Store (WindowsApps),
    # que abre la tienda o se queda esperando, y los python de MSYS/Cygwin.
    param([string]$Exe, [string[]]$PrefixArgs = @())
    if (-not $Exe) { return $false }
    if ($Exe -match 'WindowsApps|msys|cygwin') { return $false }
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Exe
        $psi.Arguments = (($PrefixArgs + @('-c', '"import sys"')) -join ' ')
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        if (-not $p.WaitForExit(15000)) { try { $p.Kill() } catch {}; return $false }
        return ($p.ExitCode -eq 0)
    }
    catch { return $false }
}

function Resolve-PythonWindows {
    # Orden: parametro explicito, ASISTENCIAS_PYTHON, lanzador py, python/python3 reales, instalacion por usuario.
    # Falla rapido con un mensaje claro si no hay ninguno utilizable.
    param([string]$Explicit)
    $msg = 'No se encontro un Python 3 de Windows utilizable (el alias de la Microsoft Store en WindowsApps no sirve). ' +
        'Instale Python 3 y defina la variable ASISTENCIAS_PYTHON con la ruta a python.exe, por ejemplo: ' +
        '$env:ASISTENCIAS_PYTHON = "C:\Users\<usuario>\AppData\Local\Programs\Python\Python312\python.exe".'
    foreach ($c in @($Explicit, $env:ASISTENCIAS_PYTHON)) {
        if ($c) {
            if (Test-PythonUsable $c) { return $c }
            throw "El Python indicado ($c) no se puede ejecutar. $msg"
        }
    }
    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($py -and (Test-PythonUsable $py.Source @('-3'))) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $py.Source; $psi.Arguments = '-3 -c "import sys; print(sys.executable)"'
        $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.CreateNoWindow = $true
        $p = [System.Diagnostics.Process]::Start($psi)
        $exe = $p.StandardOutput.ReadToEnd().Trim(); [void]$p.WaitForExit(15000)
        if ($exe -and (Test-Path $exe)) { return $exe }
    }
    foreach ($cmd in @('python', 'python3')) {
        $c = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($c -and (Test-PythonUsable $c.Source)) { return $c.Source }
    }
    $base = Join-Path $env:LOCALAPPDATA 'Programs\Python'
    if (Test-Path $base) {
        foreach ($f in (Get-ChildItem $base -Filter python.exe -Recurse -ErrorAction SilentlyContinue)) {
            if (Test-PythonUsable $f.FullName) { return $f.FullName }
        }
    }
    throw $msg
}

function Invoke-PdpProvision {
    # verify; si hay lineas FALTA, `pdp` (aditivo, nunca --prune) y verify de nuevo. Solo imprime conteos.
    param([string]$BackendRepo, [string]$PythonExe)
    $script = Join-Path $BackendRepo 'infra\security-baseline\scripts\provision_asistencias.py'
    if (-not (Test-Path $script)) { Write-Host "    !!  PDP: no se encontro $script" -ForegroundColor Yellow; return $false }
    $run = {
        param($cmd)
        Push-Location $BackendRepo
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try { $out = @(& $PythonExe -X utf8 -I $script $cmd 2>&1 | ForEach-Object { "$_" }); $code = $LASTEXITCODE }
        finally { $ErrorActionPreference = $prev; Pop-Location }
        [pscustomobject]@{ Code = $code; Lines = $out; Falta = @($out | Where-Object { $_ -match '^FALTA\b' }).Count; Sobra = @($out | Where-Object { $_ -match '^SOBRA\b' }).Count }
    }
    Write-Host '  * PDP: verificando concesiones de los endpoints contra el catalogo.' -ForegroundColor Cyan
    $r = & $run 'verify'
    if ($r.Falta -gt 0) {
        Write-Host "    PDP: $($r.Falta) concesiones/recursos FALTA; aprovisionando (aditivo, sin --prune)." -ForegroundColor Yellow
        $p = & $run 'pdp'
        if ($p.Code -ne 0) { Write-Host "    !!  PDP: el aprovisionamiento termino con codigo $($p.Code)." -ForegroundColor Red; return $false }
        $r = & $run 'verify'
    }
    Write-Host ("    PDP: FALTA={0}, SOBRA={1}, codigo={2}" -f $r.Falta, $r.Sobra, $r.Code) -ForegroundColor $(if ($r.Falta -eq 0) { 'Green' } else { 'Red' })
    return ($r.Falta -eq 0)
}
