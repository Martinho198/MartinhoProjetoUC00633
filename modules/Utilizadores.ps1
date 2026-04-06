# ================================================================
#  Modulo 5: Gestao de Utilizadores e Grupos
#  Usa comandos net user / net localgroup (compativeis com todos os Windows)
# ================================================================

function Get-AllUsers {
    Write-Title "UTILIZADORES LOCAIS"
    Write-Host "  A listar utilizadores..." -ForegroundColor Cyan
    net user
    Write-Host ""
    Write-Log "Listagem de utilizadores executada" "INFO"
}

function New-SystemUser {
    param([string]$Username, [string]$Password, [bool]$IsAdmin = $false)
    Write-Host "  A criar utilizador '$Username'..." -ForegroundColor Cyan
    $result = net user $Username $Password /add 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Utilizador '$Username' criado." -ForegroundColor Green
        if ($IsAdmin) {
            net localgroup Administrators $Username /add | Out-Null
            Write-Host "  [OK] '$Username' adicionado ao grupo Administrators." -ForegroundColor Green
        }
        Write-Log "Utilizador criado: $Username (Admin=$IsAdmin)" "SUCCESS"
    } else {
        Write-Host "  [ERRO] $result" -ForegroundColor Red
        Write-Log "Erro ao criar utilizador $Username" "ERROR"
    }
}

function Remove-SystemUser {
    param([string]$Username)
    $confirm = Read-Host "  Tem a certeza que quer remover '$Username'? (s/N)"
    if ($confirm -eq 's') {
        $result = net user $Username /delete 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Utilizador '$Username' removido." -ForegroundColor Green
            Write-Log "Utilizador removido: $Username" "WARNING"
        } else {
            Write-Host "  [ERRO] $result" -ForegroundColor Red
            Write-Log "Erro ao remover utilizador $Username" "ERROR"
        }
    } else {
        Write-Host "  Operacao cancelada." -ForegroundColor DarkGray
    }
}

function Get-AllGroups {
    Write-Title "GRUPOS LOCAIS"
    net localgroup
    Write-Host ""
    Write-Log "Listagem de grupos executada" "INFO"
}

function New-SystemGroup {
    param([string]$GroupName)
    $result = net localgroup $GroupName /add 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Grupo '$GroupName' criado." -ForegroundColor Green
        Write-Log "Grupo criado: $GroupName" "SUCCESS"
    } else {
        Write-Host "  [ERRO] $result" -ForegroundColor Red
        Write-Log "Erro ao criar grupo $GroupName" "ERROR"
    }
}

function Add-UserToGroup {
    param([string]$Username, [string]$GroupName)
    $result = net localgroup $GroupName $Username /add 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] '$Username' adicionado ao grupo '$GroupName'." -ForegroundColor Green
        Write-Log "Utilizador $Username adicionado ao grupo $GroupName" "SUCCESS"
    } else {
        Write-Host "  [ERRO] $result" -ForegroundColor Red
        Write-Log "Erro ao adicionar $Username ao grupo $GroupName" "ERROR"
    }
}

function Get-GroupMembers-Custom {
    param([string]$GroupName)
    Write-Title "MEMBROS DO GRUPO: $GroupName"
    net localgroup $GroupName
    Write-Host ""
    Write-Log "Membros do grupo $GroupName consultados" "INFO"
}

function Export-UserReport {
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "$Global:REPORT_DIR\utilizadores_$ts.txt"
    $lines = @()
    $lines += "RELATORIO DE UTILIZADORES - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "Hostname: $env:COMPUTERNAME"
    $lines += "=" * 70
    $lines += ""
    $lines += "UTILIZADORES (net user):"
    $lines += (net user | Out-String)
    $lines += ""
    $lines += "GRUPOS (net localgroup):"
    $lines += (net localgroup | Out-String)
    $lines += ""
    $lines += "MEMBROS DO GRUPO ADMINISTRATORS:"
    $lines += (net localgroup Administrators | Out-String)
    $lines | Out-File $file -Encoding UTF8
    Write-Host "  [OK] Relatorio guardado: $file" -ForegroundColor Green
    Write-Log "Relatorio de utilizadores gerado: $file" "SUCCESS"
}

function Show-UserMenu {
    while ($true) {
        Write-Title "GESTAO DE UTILIZADORES E GRUPOS"
        Write-Host "  1. Listar utilizadores"
        Write-Host "  2. Criar utilizador"
        Write-Host "  3. Remover utilizador"
        Write-Host "  4. Listar grupos"
        Write-Host "  5. Criar grupo"
        Write-Host "  6. Adicionar utilizador a grupo"
        Write-Host "  7. Ver membros de um grupo"
        Write-Host "  8. Gerar relatorio de utilizadores"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" { Get-AllUsers; Pause-Menu }
            "2" {
                $u = Read-Host "  Nome do utilizador"
                $p = Read-Host "  Password"
                $a = Read-Host "  Adicionar ao grupo Administrators? (s/N)"
                if ($u -and $p) { New-SystemUser -Username $u -Password $p -IsAdmin ($a -eq 's') }
                Pause-Menu
            }
            "3" {
                $u = Read-Host "  Nome do utilizador a remover"
                if ($u) { Remove-SystemUser -Username $u }
                Pause-Menu
            }
            "4" { Get-AllGroups; Pause-Menu }
            "5" {
                $g = Read-Host "  Nome do grupo"
                if ($g) { New-SystemGroup -GroupName $g }
                Pause-Menu
            }
            "6" {
                $u = Read-Host "  Nome do utilizador"
                $g = Read-Host "  Nome do grupo"
                if ($u -and $g) { Add-UserToGroup -Username $u -GroupName $g }
                Pause-Menu
            }
            "7" {
                $g = Read-Host "  Nome do grupo (ex: Administrators)"
                if ($g) { Get-GroupMembers-Custom -GroupName $g }
                Pause-Menu
            }
            "8" { Export-UserReport; Pause-Menu }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
