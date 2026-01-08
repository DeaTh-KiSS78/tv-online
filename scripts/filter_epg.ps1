# ============================
#  filter_epg.ps1
#  Cristian – filtrare EPG completă
# ============================

Write-Host "=== Pornire script filtrare EPG ==="

# ----------------------------
# 1. Setări directoare
# ----------------------------
$TempFolder = "temp"
$OutputFolder = "epg"
$CustomFile = "scripts/custom.xml"
$OutputFile = "$OutputFolder/epg.xml"
$CountFile = "$TempFolder/count.txt"

# Creează folderele necesare
New-Item -ItemType Directory -Force -Path $TempFolder | Out-Null
New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null

# ----------------------------
# 2. Download EPG complet
# ----------------------------
$epgUrl = "https://github.com/iptv-org/epg/releases/latest/download/epg.xml.gz"
$gzFile = "$TempFolder/epg.xml.gz"
$xmlFile = "$TempFolder/epg.xml"

Write-Host "Descarc EPG complet..."
Invoke-WebRequest -Uri $epgUrl -OutFile $gzFile

# ----------------------------
# 3. Dezarhivare epg.xml.gz
# ----------------------------
Write-Host "Dezarhivez epg.xml.gz..."
gunzip $gzFile

# ----------------------------
# 4. Încarcă EPG și custom.xml
# ----------------------------
Write-Host "Încarc epg.xml..."
[xml]$epg = Get-Content $xmlFile

Write-Host "Încarc custom.xml..."
[xml]$custom = Get-Content $CustomFile

# ----------------------------
# 5. Construiește lista canalelor dorite
# ----------------------------
$desired = @()

foreach ($ch in $custom.channels.channel) {
    $desired += [PSCustomObject]@{
        xmltv_id = $ch.xmltv_id
        name     = $ch.'#text'
    }
}

Write-Host "Canale dorite: $($desired.Count)"

# ----------------------------
# 6. Filtrare canale
# ----------------------------
Write-Host "Filtrez canalele..."

$filteredChannels = New-Object System.Collections.ArrayList

foreach ($ch in $epg.tv.channel) {

    $id = $ch.id
    $name = $ch.'display-name'.'#text'

    # Match după xmltv_id
    $match = $desired | Where-Object { $_.xmltv_id -eq $id }

    # Dacă nu găsim după xmltv_id → fallback pe nume
    if (-not $match) {
        $match = $desired | Where-Object { $_.name -eq $name }
    }

    if ($match) {
        $null = $filteredChannels.Add($ch)
    }
}

Write-Host "Canale filtrate: $($filteredChannels.Count)"

# ----------------------------
# 7. Filtrare programe
# ----------------------------
Write-Host "Filtrez programele..."

$filteredProgrammes = New-Object System.Collections.ArrayList

foreach ($pr in $epg.tv.programme) {
    $channelId = $pr.channel

    if ($filteredChannels.id -contains $channelId) {
        $null = $filteredProgrammes.Add($pr)
    }
}

Write-Host "Programe filtrate: $($filteredProgrammes.Count)"

# ----------------------------
# 8. Construiește XML final
# ----------------------------
Write-Host "Construiesc epg.xml final..."

$final = New-Object System.Xml.XmlDocument
$decl = $final.CreateXmlDeclaration("1.0", "UTF-8", $null)
$final.AppendChild($decl) | Out-Null

$tv = $final.CreateElement("tv")
$final.AppendChild($tv) | Out-Null

foreach ($ch in $filteredChannels) {
    $node = $final.ImportNode($ch, $true)
    $tv.AppendChild($node) | Out-Null
}

foreach ($pr in $filteredProgrammes) {
    $node = $final.ImportNode($pr, $true)
    $tv.AppendChild($node) | Out-Null
}

$final.Save($OutputFile)

# ----------------------------
# 9. Scrie numărul de canale pentru workflow
# ----------------------------
$filteredChannels.Count | Out-File $CountFile -Encoding utf8

# ----------------------------
# 10. Curățenie finală
# ----------------------------
Write-Host "Șterg folderul temp..."
Remove-Item $TempFolder -Recurse -Force

Write-Host "=== Script finalizat cu succes ==="