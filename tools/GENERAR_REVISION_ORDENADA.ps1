# EVO LABS - Revision visual por etapas (orden controlado)
# Orden: EVO_PARTES_01 -> EVO_PARTES_02 -> EVO_PARTES_03 -> MP4 sueltos de la raiz.
# Extrae 1 fotograma central por video. No modifica ni elimina los MP4 originales.
# Windows PowerShell 5.1

$ErrorActionPreference = "Stop"

$Repo = "C:\Users\ZuKA\Videos\CANAL_REPO"
$Ffmpeg = "$env:LOCALAPPDATA\Programs\FFmpeg\bin\ffmpeg.exe"
$Ffprobe = "$env:LOCALAPPDATA\Programs\FFmpeg\bin\ffprobe.exe"
$OutputRoot = Join-Path $Repo "REVISION_ORDENADA"
$BatchSize = 20
$Columns = 4

if (-not (Test-Path -LiteralPath $Repo)) { throw "No existe el repositorio: $Repo" }
if (-not (Test-Path -LiteralPath $Ffmpeg)) { throw "No se encontro ffmpeg.exe: $Ffmpeg" }
if (-not (Test-Path -LiteralPath $Ffprobe)) { throw "No se encontro ffprobe.exe: $Ffprobe" }

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

# El orden es intencional: primero las carpetas 1, 2 y 3; la raiz queda al final.
$Stages = @(
    [pscustomobject]@{ Name = "01_EVO_PARTES_01"; Path = (Join-Path $Repo "EVO_PARTES_01"); RootFiles = $false },
    [pscustomobject]@{ Name = "02_EVO_PARTES_02"; Path = (Join-Path $Repo "EVO_PARTES_02"); RootFiles = $false },
    [pscustomobject]@{ Name = "03_EVO_PARTES_03"; Path = (Join-Path $Repo "EVO_PARTES_03"); RootFiles = $false },
    [pscustomobject]@{ Name = "04_MP4_SUELTOS_RAIZ"; Path = $Repo; RootFiles = $true }
)

$GlobalSequence = 0
$Summary = [System.Collections.Generic.List[string]]::new()

foreach ($Stage in $Stages) {
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor DarkGray
    Write-Host "ETAPA: $($Stage.Name)" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor DarkGray

    if (-not (Test-Path -LiteralPath $Stage.Path)) {
        Write-Warning "No existe la carpeta: $($Stage.Path). Se omite."
        $Summary.Add("$($Stage.Name) | CARPETA NO ENCONTRADA")
        continue
    }

    if ($Stage.RootFiles) {
        $Videos = @(Get-ChildItem -LiteralPath $Stage.Path -File -Filter "*.mp4" | Sort-Object Name)
    } else {
        $Videos = @(Get-ChildItem -LiteralPath $Stage.Path -File -Filter "*.mp4" | Sort-Object {
            if ($_.BaseName -match '(\d+)') { [int]$Matches[1] } else { [int]::MaxValue }
        }, Name)
    }

    if ($Videos.Count -eq 0) {
        Write-Warning "No hay MP4 en $($Stage.Name)."
        $Summary.Add("$($Stage.Name) | 0 videos")
        continue
    }

    $StageOut = Join-Path $OutputRoot $Stage.Name
    New-Item -ItemType Directory -Force -Path $StageOut | Out-Null
    $TempDir = Join-Path $env:TEMP ("EVO_ORDERED_" + $Stage.Name)
    if (Test-Path $TempDir) { Remove-Item -LiteralPath $TempDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

    $StageManifest = [System.Collections.Generic.List[string]]::new()
    $Frames = [System.Collections.Generic.List[string]]::new()
    $LocalIndex = 0

    foreach ($Video in $Videos) {
        $LocalIndex++
        $GlobalSequence++
        Write-Progress -Activity "Revision visual ordenada" -Status "$($Stage.Name): $LocalIndex / $($Videos.Count) - $($Video.Name)" -PercentComplete (($LocalIndex / $Videos.Count) * 100)

        $DurationText = & $Ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($Video.FullName)"
        if ($LASTEXITCODE -ne 0 -or -not $DurationText) {
            $Line = "{0:D3} | ERROR_METADATA | {1}" -f $LocalIndex, $Video.Name
            $StageManifest.Add($Line)
            $Summary.Add("$($Stage.Name) | ERROR metadata | $($Video.Name)")
            continue
        }

        $Duration = [double]::Parse(($DurationText | Select-Object -First 1), [Globalization.CultureInfo]::InvariantCulture)
        if ($Duration -le 0) {
            $StageManifest.Add(("{0:D3} | DURACION_INVALIDA | {1}" -f $LocalIndex, $Video.Name))
            continue
        }

        $Midpoint = $Duration / 2
        $Stamp = $Midpoint.ToString("0.000", [Globalization.CultureInfo]::InvariantCulture)
        $FramePath = Join-Path $TempDir ("frame_{0:D4}.jpg" -f $LocalIndex)

        & $Ffmpeg -hide_banner -loglevel error -ss $Stamp -i "$($Video.FullName)" -frames:v 1 -vf "scale=480:-2" -q:v 4 -y "$FramePath"
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $FramePath)) {
            $Frames.Add($FramePath)
            $StageManifest.Add(("{0:D3} | {1:N2}s de {2:N2}s | {3}" -f $LocalIndex, $Midpoint, $Duration, $Video.Name))
        } else {
            $StageManifest.Add(("{0:D3} | ERROR_FRAME | {1}" -f $LocalIndex, $Video.Name))
        }
    }

    # Contact sheets de hasta 20 videos cada una, en el mismo orden de la carpeta.
    for ($Start = 0; $Start -lt $Frames.Count; $Start += $BatchSize) {
        $Batch = @($Frames | Select-Object -Skip $Start -First $BatchSize)
        $BatchNumber = [int]([Math]::Floor($Start / $BatchSize) + 1)
        $ListFile = Join-Path $TempDir ("batch_{0:D2}.txt" -f $BatchNumber)
        $ConcatLines = foreach ($Frame in $Batch) {
            $Escaped = $Frame.Replace('\', '/').Replace("'", "'\''")
            "file '$Escaped'"
        }
        Set-Content -LiteralPath $ListFile -Value $ConcatLines -Encoding UTF8

        $Rows = [int][Math]::Ceiling($Batch.Count / [double]$Columns)
        $SheetPath = Join-Path $StageOut ("HOJA_{0:D2}.jpg" -f $BatchNumber)
        & $Ffmpeg -hide_banner -loglevel error -f concat -safe 0 -i "$ListFile" -vf "tile=$($Columns)x$($Rows):padding=10:margin=10:color=black" -frames:v 1 -q:v 3 -y "$SheetPath"
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $SheetPath)) {
            Write-Host "Generada: $SheetPath" -ForegroundColor Green
        } else {
            Write-Warning "Fallo al crear $SheetPath"
        }
    }

    $StageManifest | Set-Content -LiteralPath (Join-Path $StageOut "INDICE.txt") -Encoding UTF8
    $Summary.Add("$($Stage.Name) | $($Videos.Count) videos | $($Frames.Count) capturas | $($StageOut)")
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "ETAPA TERMINADA: $($Stage.Name) - $($Videos.Count) videos." -ForegroundColor Cyan
}

Write-Progress -Activity "Revision visual ordenada" -Completed
$Summary | Set-Content -LiteralPath (Join-Path $OutputRoot "RESUMEN.txt") -Encoding UTF8

Write-Host ""
Write-Host "REVISION ORDENADA TERMINADA" -ForegroundColor Green
$Summary | ForEach-Object { Write-Host $_ }
Write-Host ""
Write-Host "Resultados: $OutputRoot" -ForegroundColor Green
Write-Host "Orden aplicado: carpeta 1, carpeta 2, carpeta 3 y finalmente los MP4 sueltos de la raiz."
Write-Host "No se modifico ni elimino ningun video original."
