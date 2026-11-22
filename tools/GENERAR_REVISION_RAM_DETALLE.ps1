$ErrorActionPreference = "Stop"
$Repo = "C:\Users\ZuKA\Videos\CANAL_REPO"
$Ffmpeg = "C:\Users\ZuKA\AppData\Local\Programs\FFmpeg\bin\ffmpeg.exe"
$Ffprobe = "C:\Users\ZuKA\AppData\Local\Programs\FFmpeg\bin\ffprobe.exe"
$Out = Join-Path $Repo "REVISION_RAM_DETALLE"
if (!(Test-Path $Ffmpeg) -or !(Test-Path $Ffprobe)) { throw "No encuentro FFmpeg/FFprobe." }
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Out | Out-Null
$sources = @()
1..4 | ForEach-Object { $sources += [pscustomobject]@{ Group="EVO_PARTES_03"; Path=(Join-Path $Repo ("EVO_PARTES_03\PARTE_{0:D3}.mp4" -f $_)) } }
Get-ChildItem $Repo -File -Filter "*.mp4" | Where-Object { $_.Name -like "2026-11-22 04-37-42 (online-video-cutter.com)*" } | ForEach-Object { $sources += [pscustomobject]@{ Group="MP4_SUELTOS"; Path=$_.FullName } }
$index = @("GRUPO;ARCHIVO;SEGUNDO;CAPTURA")
foreach ($s in $sources) {
    if (!(Test-Path $s.Path)) { Write-Warning "No existe: $($s.Path)"; continue }
    $groupDir = Join-Path $Out $s.Group
    New-Item -ItemType Directory -Path $groupDir -Force | Out-Null
    $durationText = & $Ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$($s.Path)"
    $duration = [double]::Parse($durationText.Trim(), [Globalization.CultureInfo]::InvariantCulture)
    $base = [IO.Path]::GetFileNameWithoutExtension($s.Path)
    foreach ($fraction in @(0.10,0.30,0.50,0.70,0.90)) {
        $sec = [Math]::Max(0,[Math]::Min($duration-0.15,$duration*$fraction))
        $tag = [int]($sec*100)
        $dest = Join-Path $groupDir ("{0}_{1:D4}ms.jpg" -f $base,$tag)
        & $Ffmpeg -hide_banner -loglevel error -y -ss $sec -i "$($s.Path)" -frames:v 1 -q:v 2 "$dest"
        if ($LASTEXITCODE -eq 0 -and (Test-Path $dest)) { $index += "{0};{1};{2:N2};{3}" -f $s.Group,$base,$sec,[IO.Path]::GetFileName($dest) }
    }
    Write-Host "Capturas: $base" -ForegroundColor Cyan
}
$index | Set-Content (Join-Path $Out "INDICE.csv") -Encoding UTF8
Write-Host "TERMINADO: $Out" -ForegroundColor Green