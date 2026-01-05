# ================================
#   EPG Extractor – Portabil
#   by Cristian + Copilot
# ================================

# Directorul scriptului
$base = $PSScriptRoot

# Căi relative
$playlistFile   = Join-Path $base "..\playlists\playlist.m3u"
$epgOutputDir   = Join-Path $base "..\epg"
$tempDir        = Join-Path $base "temp"
$epgSourcesFile = Join-Path $base "epg_sources.txt"
$logFile        = Join-Path $base "epg_log.txt"
$outPath        = Join-Path $epgOutputDir "epg_all.xml"

# Asigură directoarele
if (!(Test-Path $epgOutputDir)) { New-Item -ItemType Directory -Path $epgOutputDir | Out-Null }
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

"==== EPG Extract Log - $(Get-Date) ====" | Out-File $logFile

# ================================
# 1. Citește playlist.m3u și extrage tvg-id
# ================================
if (!(Test-Path $playlistFile)) {
    Add-Content $logFile "[ERROR] Playlistul nu există: $playlistFile"
    exit
}

$tvgIds = @()
$playlist = Get-Content $playlistFile

foreach ($line in $playlist) {
    if ($line -match 'tvg-id="([^"]+)"') {
        $tvgIds += $matches[1]
    }
}

$tvgIds = $tvgIds | Sort-Object -Unique
Add-Content $logFile "[INFO] Am găsit $($tvgIds.Count) canale în playlist."

# ================================
# 2. Citește sursele EPG
# ================================
if (!(Test-Path $epgSourcesFile)) {
    Add-Content $logFile "[ERROR] Fișierul epg_sources.txt nu există!"
    exit
}

$epgSources = Get-Content $epgSourcesFile | Where-Object { $_.Trim() -ne "" }

# ================================
# 3. Descarcă și dezarhivează EPG-urile (compatibil Windows + Linux)
# ================================
$downloadedXml = @()

foreach ($url in $epgSources) {
    $filename = Split-Path $url -Leaf
    $gzPath = Join-Path $tempDir $filename
    $xmlPath = $gzPath -replace ".xml.gz$", ".xml"

    Add-Content $logFile "[INFO] Descarc: $url"

    try {
        Invoke-WebRequest -Uri $url -OutFile $gzPath -ErrorAction Stop

        # Dezarhivare universală
        try {
            $bytes = [System.IO.File]::ReadAllBytes($gzPath)
            $inputStream = New-Object System.IO.MemoryStream
            $inputStream.Write($bytes, 0, $bytes.Length)
            $inputStream.Seek(0, 'Begin') | Out-Null

            $outputStream = New-Object System.IO.MemoryStream
            $gzipStream = New-Object System.IO.Compression.GzipStream($inputStream, [IO.Compression.CompressionMode]::Decompress)
            $gzipStream.CopyTo($outputStream)
            $gzipStream.Close()

            [System.IO.File]::WriteAllBytes($xmlPath, $outputStream.ToArray())
            $outputStream.Close()

            Remove-Item $gzPath -Force
            $downloadedXml += $xmlPath

            Add-Content $logFile "[VALID] Dezarhivat: $xmlPath"
        }
        catch {
            Add-Content $logFile "[ERROR] Eroare la dezarhivare: $_"
        }
    }
    catch {
        Add-Content $logFile "[ERROR] Eroare la descărcare: $url - $_"
    }
}

# ================================
# 4. Creează documentul final + detectare EPG
# ================================

$newDoc = New-Object System.Xml.XmlDocument
$root = $newDoc.CreateElement("tv")
$newDoc.AppendChild($root) | Out-Null

# Inițial presupunem că toate canalele NU au EPG
$channelsWithoutEPG = @{}
foreach ($ch in $tvgIds) {
    $channelsWithoutEPG[$ch] = $true
}

# Procesăm fiecare fișier XML descărcat
foreach ($file in $downloadedXml) {
    try {
        [xml]$doc = Get-Content -LiteralPath $file -ErrorAction Stop

        foreach ($ch in $tvgIds) {

            # Caută canalul în acest fișier
            $channelNode = $doc.tv.channel | Where-Object { $_.id -eq $ch }
            if ($channelNode) {
                # Importă canalul doar dacă nu există deja în documentul final
                if (-not ($newDoc.tv.channel | Where-Object { $_.id -eq $ch })) {
                    $imported = $newDoc.ImportNode($channelNode, $true)
                    $root.AppendChild($imported) | Out-Null
                }
                $channelsWithoutEPG[$ch] = $false
            }

            # Caută programele în acest fișier
            $programmes = $doc.tv.programme | Where-Object { $_.channel -eq $ch }
            if ($programmes.Count -gt 0) {
                foreach ($prog in $programmes) {
                    $imported = $newDoc.ImportNode($prog, $true)
                    $root.AppendChild($imported) | Out-Null
                }
                $channelsWithoutEPG[$ch] = $false
            }
        }

        Remove-Item $file -Force
        Add-Content $logFile "[INFO] Șters: $file"
    }
    catch {
        Add-Content $logFile "[ERROR] Eroare la procesarea $file - $_"
    }
}


# ================================
# 5. Salvează rezultatul final
# ================================
$newDoc.Save($outPath)
Add-Content $logFile "[DONE] EPG final creat: $outPath"

# ================================
# 6. Compresie epg_all.xml → epg_all.xml.gz
# ================================
$gzPath = "$outPath.gz"

try {
    if (Test-Path $gzPath) { Remove-Item $gzPath -Force }

    $src = [System.IO.File]::OpenRead($outPath)
    $dst = [System.IO.File]::Create($gzPath)
    $gzStream = New-Object System.IO.Compression.GzipStream($dst, [IO.Compression.CompressionMode]::Compress)
    $src.CopyTo($gzStream)
    $gzStream.Close(); $src.Close(); $dst.Close()

    Add-Content $logFile "[DONE] Compresie finală creată: $gzPath"
}
catch {
    Add-Content $logFile "[ERROR] Eroare la compresie: $_"
}

# ================================
# 7. Git Commit & Push
# ================================
$repoRoot = Join-Path $base ".."

if (Test-Path (Join-Path $repoRoot ".git")) {

    Add-Content $logFile "[INFO] Repo Git detectat. Încep commit & push."

    try {
        Push-Location $repoRoot

        git add epg/epg_all.xml epg/epg_all.xml.gz

        $status = git status --porcelain

        if ($status) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            git commit -m "Auto-update EPG $timestamp"
            git push

            Add-Content $logFile "[DONE] Git push realizat cu succes."
        }
        else {
            Add-Content $logFile "[INFO] Nicio modificare. Git push nu este necesar."
        }

        Pop-Location
    }
    catch {
        Add-Content $logFile "[ERROR] Git push a eșuat: $_"
    }
}
else {
    Add-Content $logFile "[INFO] Directorul nu este repo Git. Sar peste git push."
}

# ================================
# 8. Salvează numărul de canale procesate pentru GitHub Actions
# ================================
$tvgCount = $tvgIds.Count
Set-Content -Path "$base/channel_count.txt" -Value $tvgCount

# ================================
# 9. Salvează numărul de canale fără EPG
# ================================
$noEpgCount = ($channelsWithoutEPG.Values | Where-Object { $_ -eq $true }).Count
Set-Content -Path "$base/no_epg_count.txt" -Value $noEpgCount


Write-Host "EPG generat și încărcat cu succes!"