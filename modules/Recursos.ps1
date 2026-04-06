# ================================================================
#  Modulo 3: Monitorizacao de Recursos (CPU / RAM / Disco / Rede)
# ================================================================

function Get-SystemSnapshot {
    Write-Title "PAINEL DE RECURSOS DO SISTEMA"

    # CPU
    try {
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        Write-Host "  CPU" -ForegroundColor White
        Draw-ProgressBar -Percent $cpu
    } catch {
        Write-Host "  CPU: nao disponivel" -ForegroundColor DarkGray
        $cpu = 0
    }

    # RAM
    try {
        $os      = Get-WmiObject Win32_OperatingSystem
        $ramUsed = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
        $ramTotal= [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $ramPct  = [math]::Round($ramUsed / $ramTotal * 100, 1)
        Write-Host ""
        Write-Host "  RAM  ($ramUsed GB usados de $ramTotal GB)" -ForegroundColor White
        Draw-ProgressBar -Percent $ramPct
    } catch {
        Write-Host "  RAM: nao disponivel" -ForegroundColor DarkGray
        $ramPct = 0
    }

    # Disco
    Write-Host ""
    Write-Host "  DISCO" -ForegroundColor White
    Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Used -gt 0 } | ForEach-Object {
        $total = $_.Used + $_.Free
        $pct   = if ($total -gt 0) { [math]::Round($_.Used / $total * 100, 1) } else { 0 }
        $used  = Format-Bytes ($_.Used)
        $free  = Format-Bytes ($_.Free)
        Write-Host "  $($_.Name):\ - Usado: $used | Livre: $free" -ForegroundColor DarkGray
        Draw-ProgressBar -Percent $pct
    }

    # Rede
    Write-Host ""
    Write-Host "  REDE" -ForegroundColor White
    try {
        $netStats = Get-NetAdapterStatistics -ErrorAction Stop | Where-Object { $_.ReceivedBytes -gt 0 }
        $netStats | Select-Object -First 3 | ForEach-Object {
            $tx = Format-Bytes $_.SentBytes
            $rx = Format-Bytes $_.ReceivedBytes
            Write-Host "  $($_.Name): TX=$tx | RX=$rx" -ForegroundColor DarkGray
        }
    } catch {
        try {
            $netIf = Get-WmiObject Win32_NetworkAdapterConfiguration -ErrorAction Stop |
                     Where-Object { $_.IPEnabled -eq $true } | Select-Object -First 1
            if ($netIf) {
                Write-Host "  Interface: $($netIf.Description)" -ForegroundColor DarkGray
                Write-Host "  IP: $($netIf.IPAddress[0])" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "  Estatisticas de rede nao disponiveis" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "  Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
    Write-Log "Snapshot do sistema: CPU=$cpu% RAM=$ramPct%" "INFO"
}

function Start-ContinuousMonitor {
    param([int]$IntervalSec = 5)
    Write-Host ""
    Write-Host "  [*] Monitorizacao continua iniciada (intervalo: ${IntervalSec}s)." -ForegroundColor Yellow
    Write-Host "  [*] Prima Q + ENTER para parar." -ForegroundColor Yellow
    Write-Host ""
    Write-Log "Monitorizacao continua iniciada (${IntervalSec}s)" "INFO"

    while ($true) {
        Get-SystemSnapshot

        # Esperar o intervalo verificando se o utilizador quer sair
        $waited = 0
        while ($waited -lt $IntervalSec) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.KeyChar -eq 'q' -or $key.KeyChar -eq 'Q') {
                    Write-Host ""
                    Write-Host "  [*] Monitorizacao parada." -ForegroundColor Yellow
                    Write-Log "Monitorizacao continua parada pelo utilizador" "INFO"
                    return
                }
            }
            Start-Sleep -Milliseconds 500
            $waited++
        }
        Clear-Host
    }
}

function Export-ResourceReport {
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "$Global:REPORT_DIR\recursos_$ts.txt"

    try {
        $cpu     = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os      = Get-WmiObject Win32_OperatingSystem
        $ramUsed = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
        $ramTotal= [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
        $uptime  = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)

        $lines = @()
        $lines += "RELATORIO DE RECURSOS - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $lines += "=" * 60
        $lines += ""
        $lines += "CPU    : $cpu%"
        $lines += "RAM    : $ramUsed GB / $ramTotal GB"
        $lines += "Uptime : $([math]::Floor($uptime.TotalHours))h $($uptime.Minutes)m"
        $lines += ""
        $lines += "DISCO:"
        Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Where-Object { $_.Used -gt 0 } | ForEach-Object {
            $total = $_.Used + $_.Free
            $pct   = if ($total -gt 0) { [math]::Round($_.Used / $total * 100, 1) } else { 0 }
            $lines += "  $($_.Name):\ - $pct% | Usado: $(Format-Bytes $_.Used) | Livre: $(Format-Bytes $_.Free)"
        }
        $lines += ""
        $lines += "SISTEMA:"
        $lines += "  Hostname : $env:COMPUTERNAME"
        $lines += "  OS       : $($os.Caption)"

        $lines | Out-File $file -Encoding UTF8
        Write-Host "  [OK] Relatorio guardado: $file" -ForegroundColor Green
        Write-Log "Relatorio de recursos gerado: $file" "SUCCESS"
    } catch {
        Write-Host "  [ERRO] $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Show-ResourceMenu {
    while ($true) {
        Write-Title "MONITORIZACAO DE RECURSOS"
        Write-Host "  1. Painel de recursos (snapshot)"
        Write-Host "  2. Monitorizacao continua (prima Q para parar)"
        Write-Host "  3. Gerar relatorio de recursos"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" { Get-SystemSnapshot; Pause-Menu }
            "2" {
                $iv = Read-Host "  Intervalo em segundos (Enter = 5)"
                if (-not $iv) { $iv = 5 }
                Start-ContinuousMonitor -IntervalSec ([int]$iv)
                Pause-Menu
            }
            "3" { Export-ResourceReport; Pause-Menu }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
