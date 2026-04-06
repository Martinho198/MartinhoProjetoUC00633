# ================================================================
#  Modulo 8: Backup e Recuperacao
# ================================================================

function Get-BackupRegisto {
    $file = "$Global:BACKUP_DIR\registo.txt"
    if (-not (Test-Path $file)) { return @() }
    $records = @()
    foreach ($line in (Get-Content $file -ErrorAction SilentlyContinue)) {
        $p = $line -split "\|"
        if ($p.Count -ge 6) {
            $records += [PSCustomObject]@{
                timestamp = $p[0]
                type      = $p[1]
                name      = $p[2]
                path      = $p[3]
                source    = $p[4]
                files     = $p[5]
                size_mb   = if ($p.Count -gt 6) { $p[6] } else { "0" }
            }
        }
    }
    return $records
}

function Add-BackupRegisto {
    param([string]$Type, [string]$Name, [string]$BPath, [string]$Source, [int]$Files, [string]$SizeMB)
    $file = "$Global:BACKUP_DIR\registo.txt"
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')|$Type|$Name|$BPath|$Source|$Files|$SizeMB"
    Add-Content -Path $file -Value $line -Encoding UTF8
}

function Start-FullBackup {
    param([string]$SourcePath, [string]$BackupName = "backup_full")

    if (-not (Test-Path $SourcePath)) {
        Write-Host "  [ERRO] Caminho nao existe: $SourcePath" -ForegroundColor Red
        return
    }

    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $dest = Join-Path $Global:BACKUP_DIR "${BackupName}_${ts}"

    Write-Host "  [*] A copiar '$SourcePath' para backup..." -ForegroundColor Cyan

    try {
        Copy-Item -Path $SourcePath -Destination $dest -Recurse -Force
        Write-Host "  [OK] Copia concluida." -ForegroundColor Green
    } catch {
        Write-Host "  [ERRO] Falha ao copiar: $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Erro no backup: $_" "ERROR"
        return
    }

    $allF  = Get-ChildItem -Path $dest -Recurse -File -ErrorAction SilentlyContinue
    $fCount = if ($allF) { @($allF).Count } else { 0 }
    $bytes  = if ($allF) { ($allF | Measure-Object -Property Length -Sum).Sum } else { 0 }
    $sizeMB = [math]::Round($bytes / 1MB, 2)

    Add-BackupRegisto -Type "full" -Name "${BackupName}_${ts}" -BPath $dest `
                      -Source $SourcePath -Files $fCount -SizeMB "$sizeMB"

    Write-Host "  Destino   : $dest" -ForegroundColor DarkGray
    Write-Host "  Ficheiros : $fCount | Tamanho: ${sizeMB} MB" -ForegroundColor DarkGray
    Write-Log "Backup completo criado: $dest ($fCount ficheiros)" "SUCCESS"
}

function Start-IncrementalBackup {
    param([string]$SourcePath, [string]$BackupName = "backup_inc")

    if (-not (Test-Path $SourcePath)) {
        Write-Host "  [ERRO] Caminho nao existe: $SourcePath" -ForegroundColor Red
        return
    }

    $records    = @(Get-BackupRegisto)
    $lastBackup = $records | Where-Object { $_.source -eq $SourcePath } | Select-Object -Last 1

    if (-not $lastBackup) {
        Write-Host "  [*] Sem backup anterior. A fazer backup completo..." -ForegroundColor Yellow
        Start-FullBackup -SourcePath $SourcePath -BackupName $BackupName
        return
    }

    $lastTime = [datetime]::ParseExact($lastBackup.timestamp, "yyyy-MM-dd HH:mm:ss", $null)
    $ts       = Get-Date -Format "yyyyMMdd_HHmmss"
    $dest     = Join-Path $Global:BACKUP_DIR "${BackupName}_${ts}"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null

    Write-Host "  [*] Backup incremental desde $($lastBackup.timestamp)..." -ForegroundColor Cyan

    $srcClean  = $SourcePath.TrimEnd('\')
    $newFiles  = Get-ChildItem -Path $SourcePath -Recurse -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -gt $lastTime }

    if (-not $newFiles -or @($newFiles).Count -eq 0) {
        Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Nenhum ficheiro novo desde o ultimo backup." -ForegroundColor Green
        Write-Log "Backup incremental: sem ficheiros novos" "INFO"
        return
    }

    foreach ($f in @($newFiles)) {
        $rel    = $f.FullName.Substring($srcClean.Length)
        $target = Join-Path $dest $rel
        $tDir   = Split-Path $target -Parent
        if (-not (Test-Path $tDir)) { New-Item -ItemType Directory -Path $tDir -Force | Out-Null }
        Copy-Item -Path $f.FullName -Destination $target -Force -ErrorAction SilentlyContinue
    }

    $copied = @($newFiles).Count
    $bytes  = ($newFiles | Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($bytes / 1MB, 2)

    Add-BackupRegisto -Type "incremental" -Name "${BackupName}_${ts}" -BPath $dest `
                      -Source $SourcePath -Files $copied -SizeMB "$sizeMB"

    Write-Host "  [OK] Backup incremental criado: $dest" -ForegroundColor Green
    Write-Host "  Ficheiros novos/alterados: $copied" -ForegroundColor DarkGray
    Write-Log "Backup incremental: $dest ($copied ficheiros)" "SUCCESS"
}

function Restore-Backup {
    param([string]$BackupPath, [string]$Destination)
    if (-not (Test-Path $BackupPath)) {
        Write-Host "  [ERRO] Caminho do backup nao existe: $BackupPath" -ForegroundColor Red
        return
    }
    $confirm = Read-Host "  Restaurar para '$Destination'? (s/N)"
    if ($confirm -ne 's') { Write-Host "  Cancelado." -ForegroundColor DarkGray; return }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path "$BackupPath\*" -Destination $Destination -Recurse -Force -ErrorAction Stop
    Write-Host "  [OK] Restaurado para: $Destination" -ForegroundColor Green
    Write-Log "Backup restaurado: $BackupPath -> $Destination" "SUCCESS"
}

function Show-BackupList {
    Write-Title "HISTORICO DE BACKUPS"
    $records = @(Get-BackupRegisto)
    if ($records.Count -eq 0) {
        Write-Host "  Ainda nao ha backups registados." -ForegroundColor DarkGray
        return
    }
    $i = 1
    foreach ($b in $records) {
        $color = if ($b.type -eq "full") { "Green" } else { "Cyan" }
        Write-Host ("  [{0}] [{1,-12}] {2}  ({3} ficheiros, {4} MB)" -f `
            $i, $b.type, $b.timestamp, $b.files, $b.size_mb) -ForegroundColor $color
        Write-Host ("        Pasta: {0}" -f $b.path) -ForegroundColor DarkGray
        $i++
    }
}

function Show-BackupMenu {
    while ($true) {
        Write-Title "BACKUP E RECUPERACAO"
        Write-Host "  1. Backup completo"
        Write-Host "  2. Backup incremental"
        Write-Host "  3. Restaurar backup"
        Write-Host "  4. Listar backups"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" {
                Write-Host "  Exemplo: C:\Users\Escola\Documents" -ForegroundColor DarkGray
                $src  = Read-Host "  Caminho de origem"
                $name = Read-Host "  Nome do backup (Enter = backup_full)"
                if (-not $name) { $name = "backup_full" }
                if ($src) { Start-FullBackup -SourcePath $src -BackupName $name }
                Pause-Menu
            }
            "2" {
                Write-Host "  Exemplo: C:\Users\Escola\Documents" -ForegroundColor DarkGray
                $src  = Read-Host "  Caminho de origem"
                $name = Read-Host "  Nome do backup (Enter = backup_inc)"
                if (-not $name) { $name = "backup_inc" }
                if ($src) { Start-IncrementalBackup -SourcePath $src -BackupName $name }
                Pause-Menu
            }
            "3" {
                Show-BackupList
                $path = Read-Host "  Caminho da pasta de backup (ver lista acima)"
                $dest = Read-Host "  Pasta de destino"
                if ($path -and $dest) { Restore-Backup -BackupPath $path -Destination $dest }
                Pause-Menu
            }
            "4" { Show-BackupList; Pause-Menu }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
