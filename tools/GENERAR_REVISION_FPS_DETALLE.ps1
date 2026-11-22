$ErrorActionPreference = "Stop"
$Repo = "C:\Users\ZuKA\Videos\CANAL_REPO"
$Ffmpeg = "C:\Users\ZuKA\AppData\Local\Programs\FFmpeg\bin\ffmpeg.exe"
$Ffprobe = "C:\Users\ZuKA\AppData\Local\Programs\FFmpeg\bin\ffprobe.exe"
$Out = Join-Path $Repo "REVISION_FPS_DETALLE"
if (!(Test-Path $Ffmpeg) -or !(Test-Path $Ffprobe)) { throw "No encuentro FFmpeg/FFprobe en la ruta configurada." }
if (Test-Path $Out) { Remove-Item $Out -Recurse -Force }
New-Item -ItemType Directory -Path $Out | Out-Null
$groups = @(
    @{ Name = "CS2"; Files = (5..29 | ForEach-Object { "EVO_PARTES_01\PARTE_{0:D3}.mp4" -f $_ }) },
    @{ Name = "VALORANT"; Files = ((35..66 | ForEach-Object { "EVO_PARTES_01\PARTE_{0:D3}.mp4" -f $_ }) + (1..5 | ForEach-Object { "EVO_PARTES_02\PARTE_{0:D3}.mp4" -f $_ })) }
)
foreach ($g in $groups) {
    $folder = Join-Path $Out $g.Name
    New-Item -ItemType Directory -Path $folder | Out-Null
    $i = 0
    foreach ($rel in $g.Files) {
        $src = Join-Path $Repo $rel
        if (!(Test-Path $src)) { Write-Warning "Falta: $rel"; continue }
        $d = & $Ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$src"
        $duration = [double]::Parse($d.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        foreach ($part in @(0.25,0.50,0.75)) {
            $i++
            $sec = [Math]::Min($duration - 0.15, $duration * $part)
            $outFile = Join-Path $folder ("{0}_{1:D3}_{2}.jpg" -f ([IO.Path]::GetFileNameWithoutExtension($rel)), $i, ([int]($sec*100)))
            & $Ffmpeg -hide_banner -loglevel error -y -ss $sec -i "$src" -frames:v 1 -q:v 2 "$outFile"
            if ($LASTEXITCODE -ne 0) { Write-Warning "Error: $rel en $sec segundos" }
        }
        Write-Host ("{0}: {1}" -f $g.Name,$rel)
    }
}
@("CS2: EVO_PARTES_01 PARTE_005 a PARTE_029","VALORANT: EVO_PARTES_01 PARTE_035 a PARTE_066 y EVO_PARTES_02 PARTE_001 a PARTE_005","Tres fotogramas por video: 25%, 50% y 75%. Resolucion original.") | Set-Content (Join-Path $Out "LEEME.txt") -Encoding UTF8
Write-Host "TERMINADO: $Out" -ForegroundColor Green