# ================================================================
#  Modulo 2: Sistema de Ficheiros
# ================================================================

function Get-DiskUsage {
    param([string]$Path)
    Write-Title "ANALISE DE DISCO - $Path"

    $items = Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue
    $files = $items | Where-Object { -not $_.PSIsContainer }
    $dirs  = $items | Where-Object { $_.PSIsContainer }
    $totalSize = if ($files) { ($files | Measure-Object -Property Length -Sum).Sum } else { 0 }

    Write-Host "  Ficheiros : $($files.Count)" -ForegroundColor White
    Write-Host "  Pastas    : $($dirs.Count)"  -ForegroundColor White
    Write-Host "  Tamanho   : $(Format-Bytes $totalSize)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  TOP 10 FICHEIROS MAIORES:" -ForegroundColor Cyan
    $files | Sort-Object Length -Descending | Select-Object -First 10 |
        ForEach-Object {
            Write-Host ("  {0,-15} {1}" -f (Format-Bytes $_.Length), $_.FullName) -ForegroundColor DarkGray
        }
    Write-Log "Analise de disco '$Path': $($files.Count) ficheiros, $(Format-Bytes $totalSize)" "INFO"
}

function New-DirectoryStructure {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            Write-Host "  [!] Diretorio ja existe: $Path" -ForegroundColor Yellow
            return
        }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "  [OK] Diretorio criado: $Path" -ForegroundColor Green
        Write-Log "Diretorio criado: $Path" "SUCCESS"
    } catch {
        Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
        Write-Log "Erro ao criar diretorio: $_" "ERROR"
    }
}

function Get-FilePermissions {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        Write-Host "  [ERRO] Caminho nao encontrado: $Path" -ForegroundColor Red
        return
    }
    Write-Title "PERMISSOES - $Path"
    $acl = Get-Acl -Path $Path
    Write-Host "  Proprietario: $($acl.Owner)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ACESSOS:" -ForegroundColor Cyan
    $acl.Access | ForEach-Object {
        Write-Host ("  {0,-40} {1,-15} {2}" -f $_.IdentityReference, $_.AccessControlType, $_.FileSystemRights) -ForegroundColor DarkGray
    }
    Write-Log "Permissoes consultadas: $Path" "INFO"
}

function Find-LargeFiles {
    param([string]$Path, [int]$MinSizeMB = 10)
    Write-Title "FICHEIROS GRANDES (> ${MinSizeMB}MB)"
    $minBytes = $MinSizeMB * 1MB
    $found = Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer -and $_.Length -ge $minBytes } |
        Sort-Object Length -Descending

    if ($found.Count -eq 0) {
        Write-Host "  Nenhum ficheiro maior que ${MinSizeMB}MB encontrado." -ForegroundColor Green
    } else {
        Write-Host "  Encontrados $($found.Count) ficheiros:" -ForegroundColor Yellow
        $found | ForEach-Object {
            Write-Host ("  {0,-15} {1}" -f (Format-Bytes $_.Length), $_.FullName) -ForegroundColor DarkGray
        }
    }
    Write-Log "Pesquisa ficheiros grandes: $($found.Count) encontrados" "INFO"
}

function Get-FileHash-Custom {
    param([string]$Path, [string]$Algorithm = "SHA256")
    if (-not (Test-Path $Path)) {
        Write-Host "  [ERRO] Ficheiro nao encontrado: $Path" -ForegroundColor Red
        return
    }
    $hash = Get-FileHash -Path $Path -Algorithm $Algorithm
    Write-Host "  Algoritmo : $Algorithm" -ForegroundColor White
    Write-Host "  Hash      : $($hash.Hash)" -ForegroundColor Yellow
    Write-Host "  Ficheiro  : $Path" -ForegroundColor DarkGray
    Write-Log "Hash $Algorithm calculado para $Path" "INFO"
}

function Start-DirectoryAudit {
    param([string]$Path)
    $ts    = Get-Date -Format "yyyyMMdd_HHmmss"
    $file  = "$Global:REPORT_DIR\auditoria_$ts.txt"
    $count = 0
    $lines = @()
    $lines += "AUDITORIA DE FICHEIROS - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "Diretorio: $Path"
    $lines += "=" * 80

    Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue |
        Where-Object { -not $_.PSIsContainer } | ForEach-Object {
            $lines += "$($_.FullName) | $(Format-Bytes $_.Length) | $($_.LastWriteTime)"
            $count++
        }

    $lines | Out-File $file -Encoding UTF8
    Write-Host "  [OK] Auditoria completa: $count ficheiros registados" -ForegroundColor Green
    Write-Host "  Guardado em: $file" -ForegroundColor DarkGray
    Write-Log "Auditoria '$Path': $count ficheiros" "SUCCESS"
}

function Show-FilesystemMenu {
    while ($true) {
        Write-Title "SISTEMA DE FICHEIROS"
        Write-Host "  1. Analisar uso de disco"
        Write-Host "  2. Criar diretorio"
        Write-Host "  3. Ver permissoes de ficheiro/pasta"
        Write-Host "  4. Encontrar ficheiros grandes"
        Write-Host "  5. Calcular hash de ficheiro"
        Write-Host "  6. Auditoria de diretorio"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" {
                Write-Host "  Exemplos: C:\Users\Escola   ou   C:\Users\Escola\Documents" -ForegroundColor DarkGray
                $p = Read-Host "  Caminho a analisar"
                if ($p -and (Test-Path $p)) {
                    Get-DiskUsage -Path $p
                } else {
                    Write-Host "  [ERRO] Caminho invalido ou nao existe: $p" -ForegroundColor Red
                }
                Pause-Menu
            }
            "2" {
                $p = Read-Host "  Caminho do novo diretorio (ex: C:\Teste\NovaPasta)"
                if ($p) { New-DirectoryStructure -Path $p }
                Pause-Menu
            }
            "3" {
                $p = Read-Host "  Caminho do ficheiro ou pasta"
                if ($p) { Get-FilePermissions -Path $p }
                Pause-Menu
            }
            "4" {
                Write-Host "  Exemplos: C:\Users\Escola   ou   C:\Users\Escola\Downloads" -ForegroundColor DarkGray
                $p = Read-Host "  Caminho a pesquisar"
                $s = Read-Host "  Tamanho minimo em MB (Enter = 10)"
                if (-not $s) { $s = 10 }
                if ($p -and (Test-Path $p)) {
                    Find-LargeFiles -Path $p -MinSizeMB ([int]$s)
                } else {
                    Write-Host "  [ERRO] Caminho invalido ou nao existe: $p" -ForegroundColor Red
                }
                Pause-Menu
            }
            "5" {
                $p = Read-Host "  Caminho completo do ficheiro"
                $a = Read-Host "  Algoritmo SHA256 ou MD5 (Enter = SHA256)"
                if (-not $a) { $a = "SHA256" }
                if ($p) { Get-FileHash-Custom -Path $p -Algorithm $a }
                Pause-Menu
            }
            "6" {
                Write-Host "  Exemplos: C:\Users\Escola   ou   C:\Users\Escola\Documents" -ForegroundColor DarkGray
                $p = Read-Host "  Diretorio a auditar"
                if ($p -and (Test-Path $p)) {
                    Start-DirectoryAudit -Path $p
                } else {
                    Write-Host "  [ERRO] Caminho invalido ou nao existe: $p" -ForegroundColor Red
                }
                Pause-Menu
            }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
