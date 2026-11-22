# EVO LABS - Generador de hojas de contacto para revision visual
# Windows PowerShell 5.1 | No modifica ni elimina videos originales.

$ErrorActionPreference = "Stop"
$Repo = "C:\Users\ZuKA\Videos\CANAL_REPO"
$Ffmpeg = "$env:LOCALAPPDATA\Programs\FFmpeg\bin\ffmpeg.exe"
$Ffprobe = "$env:LOCALAPPDATA\Programs\FFmpeg\bin\ffprobe.exe"

if (-not (Test-Path $Repo)) { throw "No existe el repositorio: $Repo" }
if (-not (Test-Path $Ffmpeg)) { throw "No se encontro ffmpeg.exe en: $Ffmpeg" }
if (-not (Test-Path $Ffprobe)) { throw "No se encontro ffprobe.exe en: $Ffprobe" }

$OutDir = Join-Path $Repo "REVISION_VISUAL"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Primero revisa los MP4 originales de la raiz (escritorio y Administrador de tareas).
$Videos = @(Get-ChildItem -LiteralPath $Repo -File -Filter "*.mp4" | Sort-Object Name)
if ($Videos.Count -eq 0) { throw "No se encontraron MP4 en la raiz del repositorio." }

foreach ($Video in $Videos) {
    Write-Host "Procesando: $($Video.Name)" -ForegroundColor Cyan
    $DurationText = & $Ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($Video.FullName)"
    $Duration = [double]::Parse(($DurationText | Select-Object -First 1), [Globalization.CultureInfo]::InvariantCulture)
    if ($Duration -le 0) { Write-Warning "Duracion invalida: $($Video.Name)"; continue }

    $SafeName = [IO.Path]::GetFileNameWithoutExtension($Video.Name) -replace '[^A-Za-z0-9_-]', '_'
    $Work = Join-Path $env:TEMP ("EVO_CONTACT_" + $SafeName)
    New-Item -ItemType Directory -Force -Path $Work | Out-Null

    for ($i = 1; $i -le 6; $i++) {
        $Seconds = [Math]::Round(($Duration * $i / 7), 3)
        $Stamp = $Seconds.ToString("0.000", [Globalization.CultureInfo]::InvariantCulture)
        $Frame = Join-Path $Work ("frame_{0:D2}.jpg" -f $i)
        & $Ffmpeg -hide_banner -loglevel error -ss $Stamp -i "$($Video.FullName)" -frames:v 1 -vf "scale=640:-2" -q:v 3 -y "$Frame"
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $Frame)) { Write-Warning "No se pudo extraer el fotograma $i de $($Video.Name)" }
    }

    $Pattern = Join-Path $Work "frame_%02d.jpg"
    $Sheet = Join-Path $OutDir ($SafeName + "_CONTACTO.jpg")
    & $Ffmpeg -hide_banner -loglevel error -framerate 1 -start_number 1 -i "$Pattern" -vf "tile=3x2:padding=12:margin=12:color=black" -frames:v 1 -q:v 2 -y "$Sheet"
    if ($LASTEXITCODE -eq 0 -and (Test-Path $Sheet)) {
        Write-Host "OK: $Sheet" -ForegroundColor Green
    } else {
        Write-Warning "No se pudo crear la hoja de contacto para $($Video.Name)"
    }
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Hojas generadas en: $OutDir" -ForegroundColor Green
Write-Host "Videos originales intactos. No se modifico ningun MP4." -ForegroundColor Green
