# EVO LABS - Auditoria visual densa de todos los segmentos MP4
# Windows PowerShell 5.1 | Extrae 1 fotograma central por archivo.
# No modifica, mueve ni elimina videos originales.

$ErrorActionPreference = "Stop"
$Repo = "C:\Users\ZuKA\Videos\CANAL_REPO"
$Ffmpeg = "$env:LOCALAPPDATA\Programs\FFmpeg\bin\ffmpeg.exe"
$Ffprobe = "$env:LOCALAPPDATA\Programs\FFmpeg\bin\ffprobe.exe"
$OutDir = Join-Path $Repo "REVISION_VISUAL_DENSO"

if (-not (Test-Path $Repo)) { throw "No existe el repositorio: $Repo" }
if (-not (Test-Path $Ffmpeg)) { throw "No se encontro ffmpeg.exe: $Ffmpeg" }
if (-not (Test-Path $Ffprobe)) { throw "No se encontro ffprobe.exe: $Ffprobe" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$Videos = @(Get-ChildItem -LiteralPath $Repo -Recurse -File -Filter "*.mp4" |
    Where-Object { $_.FullName -notlike "$OutDir*" } |
    Sort-Object DirectoryName, Name)

if ($Videos.Count -eq 0) { throw "No se encontraron videos MP4." }

$Groups = $Videos | Group-Object DirectoryName
foreach ($Group in $Groups) {
    $Dir = $Group.Name
    $FolderName = Split-Path $Dir -Leaf
    if ($Dir -eq $Repo) { $FolderName = "RAIZ" }
    $SafeFolder = $FolderName -replace '[^A-Za-z0-9_-]', '_'
    $TempDir = Join-Path $env:TEMP ("EVO_DENSO_" + $SafeFolder)
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

    $Index = 0
    $Map = [System.Collections.Generic.List[string]]::new()
    foreach ($Video in ($Group.Group | Sort-Object Name)) {
        $Index++
        $DurationText = & $Ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($Video.FullName)"
        if ($LASTEXITCODE -ne 0 -or -not $DurationText) {
            $Map.Add(("{0:D3} | ERROR METADATA | {1}" -f $Index, $Video.FullName))
            continue
        }
        $Duration = [double]::Parse(($DurationText | Select-Object -First 1), [Globalization.CultureInfo]::InvariantCulture)
        $Midpoint = [Math]::Max(0, $Duration / 2)
        $Stamp = $Midpoint.ToString("0.000", [Globalization.CultureInfo]::InvariantCulture)
        $Frame = Join-Path $TempDir ("frame_{0:D4}.jpg" -f $Index)

        & $Ffmpeg -hide_banner -loglevel error -ss $Stamp -i "$($Video.FullName)" -frames:v 1 -vf "scale=480:-2" -q:v 4 -y "$Frame"
        if ($LASTEXITCODE -eq 0 -and (Test-Path $Frame)) {
            $Map.Add(("{0:D3} | {1:N1}s / {2:N1}s | {3}" -f $Index, $Midpoint, $Duration, $Video.Name))
        } else {
            $Map.Add(("{0:D3} | ERROR FRAME | {1}" -f $Index, $Video.Name))
        }
        Write-Progress -Activity "Extrayendo muestras" -Status "$FolderName - $Index de $($Group.Count)" -PercentComplete (($Index / $Group.Count) * 100)
    }

    $Rows = [Math]::Ceiling($Index / 4)
    $Pattern = Join-Path $TempDir "frame_%04d.jpg"
    $Sheet = Join-Path $OutDir ($SafeFolder + "_SECUENCIA.jpg")
    # Si faltan indices por error, tile procesa los fotogramas existentes consecutivos.
    & $Ffmpeg -hide_banner -loglevel error -framerate 1 -i "$Pattern" -vf "tile=4x$Rows:padding=10:margin=10:color=black" -frames:v 1 -q:v 3 -y "$Sheet"
    if ($LASTEXITCODE -eq 0 -and (Test-Path $Sheet)) {
        Write-Host "HOJA OK: $Sheet" -ForegroundColor Green
    } else {
        Write-Warning "No se pudo crear hoja para $FolderName"
    }
    $MapPath = Join-Path $OutDir ($SafeFolder + "_INDICE.txt")
    $Map | Set-Content -LiteralPath $MapPath -Encoding UTF8
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Progress -Activity "Extrayendo muestras" -Completed
Write-Host ""
Write-Host "AUDITORIA VISUAL DENSA TERMINADA" -ForegroundColor Green
Write-Host "Videos procesados: $($Videos.Count)"
Write-Host "Resultados: $OutDir"
Write-Host "Se extrajo un fotograma central por cada MP4. Videos originales intactos." -ForegroundColor Green
