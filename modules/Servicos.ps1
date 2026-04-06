# ================================================================
#  Modulo 6: Gestao de Servicos
#  Usa sc.exe e Get-Service (compativeis com todos os Windows)
# ================================================================

$CRITICAL_SERVICES = @("Spooler","LanmanServer","Dnscache","EventLog","DHCP","Netlogon")

function Get-AllServices {
    param([string]$Filter = "")
    Write-Title "SERVICOS DO SISTEMA"
    if ($Filter -eq "Running") {
        Get-Service | Where-Object { $_.Status -eq "Running" } |
            Select-Object @{N="Nome";E={$_.Name}}, @{N="Estado";E={$_.Status}}, @{N="Descricao";E={$_.DisplayName}} |
            Format-Table -AutoSize
    } elseif ($Filter -eq "Stopped") {
        Get-Service | Where-Object { $_.Status -eq "Stopped" } |
            Select-Object @{N="Nome";E={$_.Name}}, @{N="Estado";E={$_.Status}}, @{N="Descricao";E={$_.DisplayName}} |
            Format-Table -AutoSize
    } else {
        Get-Service | Select-Object @{N="Nome";E={$_.Name}}, @{N="Estado";E={$_.Status}}, @{N="Descricao";E={$_.DisplayName}} |
            Format-Table -AutoSize
    }
    Write-Log "Listagem de servicos executada (filtro: $Filter)" "INFO"
}

function Start-SystemService {
    param([string]$ServiceName)
    Write-Host "  A iniciar servico '$ServiceName'..." -ForegroundColor Cyan
    $out = sc.exe start $ServiceName 2>&1
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Host "  [OK] Servico '$ServiceName' esta a correr." -ForegroundColor Green
        Write-Log "Servico iniciado: $ServiceName" "SUCCESS"
    } else {
        # Tentar via Start-Service como fallback
        try {
            Start-Service -Name $ServiceName -ErrorAction Stop
            Write-Host "  [OK] Servico '$ServiceName' iniciado." -ForegroundColor Green
            Write-Log "Servico iniciado: $ServiceName" "SUCCESS"
        } catch {
            Write-Host "  [INFO] $out" -ForegroundColor DarkGray
            Write-Log "Tentativa de iniciar servico $ServiceName" "INFO"
        }
    }
}

function Stop-SystemService {
    param([string]$ServiceName)
    $confirm = Read-Host "  Parar o servico '$ServiceName'? (s/N)"
    if ($confirm -ne 's') { Write-Host "  Cancelado." -ForegroundColor DarkGray; return }

    Write-Host "  A parar servico '$ServiceName'..." -ForegroundColor Cyan
    $out = sc.exe stop $ServiceName 2>&1
    Start-Sleep -Seconds 2
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Stopped") {
        Write-Host "  [OK] Servico '$ServiceName' parado." -ForegroundColor Yellow
        Write-Log "Servico parado: $ServiceName" "WARNING"
    } else {
        try {
            Stop-Service -Name $ServiceName -Force -ErrorAction Stop
            Write-Host "  [OK] Servico '$ServiceName' parado." -ForegroundColor Yellow
            Write-Log "Servico parado: $ServiceName" "WARNING"
        } catch {
            Write-Host "  [INFO] $out" -ForegroundColor DarkGray
        }
    }
}

function Restart-SystemService {
    param([string]$ServiceName)
    Write-Host "  A reiniciar servico '$ServiceName'..." -ForegroundColor Cyan
    sc.exe stop $ServiceName | Out-Null
    Start-Sleep -Seconds 2
    $out = sc.exe start $ServiceName 2>&1
    Start-Sleep -Seconds 2
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        Write-Host "  [OK] Servico '$ServiceName' reiniciado." -ForegroundColor Green
        Write-Log "Servico reiniciado: $ServiceName" "SUCCESS"
    } else {
        Write-Host "  [INFO] $out" -ForegroundColor DarkGray
        Write-Log "Tentativa de reiniciar servico $ServiceName" "INFO"
    }
}

function Get-ServiceDetails {
    param([string]$ServiceName)
    Write-Title "DETALHES DO SERVICO: $ServiceName"
    sc.exe query $ServiceName
    Write-Host ""
    Write-Log "Detalhes do servico $ServiceName consultados" "INFO"
}

function Watch-CriticalServices {
    Write-Title "VERIFICACAO DE SERVICOS CRITICOS"
    Write-Host "  A verificar $($CRITICAL_SERVICES.Count) servicos criticos...`n" -ForegroundColor Cyan

    foreach ($svcName in $CRITICAL_SERVICES) {
        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
        if (-not $svc) {
            Write-Host "  [--] $svcName - Nao disponivel neste sistema" -ForegroundColor DarkGray
        } elseif ($svc.Status -eq "Running") {
            Write-Host "  [OK] $svcName - A correr" -ForegroundColor Green
        } else {
            Write-Host "  [!!] $svcName - PARADO. A tentar reiniciar..." -ForegroundColor Yellow
            sc.exe start $svcName | Out-Null
            Start-Sleep -Seconds 2
            $svc2 = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc2 -and $svc2.Status -eq "Running") {
                Write-Host "       [OK] Reiniciado com sucesso." -ForegroundColor Green
                Write-Log "Servico critico reiniciado: $svcName" "WARNING"
            } else {
                Write-Host "       [!] Nao foi possivel reiniciar (sem permissao?)" -ForegroundColor Red
            }
        }
    }
}

function Export-ServiceReport {
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "$Global:REPORT_DIR\servicos_$ts.txt"
    $lines = @()
    $lines += "RELATORIO DE SERVICOS - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "=" * 70
    $lines += ""
    $lines += "SERVICOS ATIVOS:"
    $lines += (Get-Service | Where-Object {$_.Status -eq "Running"} |
        Select-Object Name, DisplayName | Format-Table | Out-String)
    $lines += "SERVICOS PARADOS:"
    $lines += (Get-Service | Where-Object {$_.Status -eq "Stopped"} |
        Select-Object Name, DisplayName | Format-Table | Out-String)
    $lines | Out-File $file -Encoding UTF8
    Write-Host "  [OK] Relatorio guardado: $file" -ForegroundColor Green
    Write-Log "Relatorio de servicos gerado: $file" "SUCCESS"
}

function Show-ServiceMenu {
    while ($true) {
        Write-Title "GESTAO DE SERVICOS"
        Write-Host "  1. Listar todos os servicos"
        Write-Host "  2. Listar servicos ATIVOS"
        Write-Host "  3. Listar servicos PARADOS"
        Write-Host "  4. Iniciar servico"
        Write-Host "  5. Parar servico"
        Write-Host "  6. Reiniciar servico"
        Write-Host "  7. Detalhes de um servico"
        Write-Host "  8. Verificar servicos criticos (auto-reinicio)"
        Write-Host "  9. Gerar relatorio de servicos"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" { Get-AllServices;                   Pause-Menu }
            "2" { Get-AllServices -Filter "Running"; Pause-Menu }
            "3" { Get-AllServices -Filter "Stopped"; Pause-Menu }
            "4" {
                $s = Read-Host "  Nome do servico (ex: Spooler)"
                if ($s) { Start-SystemService -ServiceName $s }
                Pause-Menu
            }
            "5" {
                $s = Read-Host "  Nome do servico"
                if ($s) { Stop-SystemService -ServiceName $s }
                Pause-Menu
            }
            "6" {
                $s = Read-Host "  Nome do servico"
                if ($s) { Restart-SystemService -ServiceName $s }
                Pause-Menu
            }
            "7" {
                $s = Read-Host "  Nome do servico (ex: Spooler)"
                if ($s) { Get-ServiceDetails -ServiceName $s }
                Pause-Menu
            }
            "8" { Watch-CriticalServices; Pause-Menu }
            "9" { Export-ServiceReport;   Pause-Menu }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
