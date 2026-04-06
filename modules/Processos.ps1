# ================================================================
#  Modulo 1: Gestao de Processos e Memoria
# ================================================================

$SUSPICIOUS_NAMES = @("miner","cryptominer","keylogger","trojan","malware","ransomware","backdoor","rootkit","rat")

function Get-TopProcesses {
    param(
        [ValidateSet("CPU","Memory")][string]$SortBy = "CPU",
        [int]$Top = 20
    )
    Write-Title "PROCESSOS ? Top $Top por $SortBy"

    $procs = Get-Process | Select-Object Id, Name,
        @{N="CPU(s)";  E={[math]::Round($_.CPU, 2)}},
        @{N="RAM(MB)"; E={[math]::Round($_.WorkingSet64 / 1MB, 1)}},
        @{N="Estado";  E={"A correr"}}

    if ($SortBy -eq "CPU") {
        $procs = $procs | Sort-Object "CPU(s)" -Descending
    } else {
        $procs = $procs | Sort-Object "RAM(MB)" -Descending
    }

    $procs | Select-Object -First $Top | Format-Table -AutoSize
    Write-Log "Listagem de processos por $SortBy executada" "INFO"
}

function Stop-ProcessById {
    param([int]$PID_Target)
    try {
        $proc = Get-Process -Id $PID_Target -ErrorAction Stop
        $name = $proc.Name
        $confirm = Read-Host "  Encerrar '$name' (PID $PID_Target)? (s/N)"
        if ($confirm -eq 's') {
            Stop-Process -Id $PID_Target -Force
            Write-Log "Processo encerrado: $name (PID $PID_Target)" "WARNING"
            Write-Host "  [?] Processo '$name' encerrado." -ForegroundColor Green
        } else {
            Write-Host "  Cancelado." -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  [?] PID $PID_Target nao encontrado." -ForegroundColor Red
        Write-Log "PID $PID_Target nao encontrado" "ERROR"
    }
}

function Find-SuspiciousProcesses {
    Write-Title "DETECAO DE PROCESSOS SUSPEITOS"
    $found = @()
    Get-Process | ForEach-Object {
        $n = $_.Name.ToLower()
        foreach ($kw in $SUSPICIOUS_NAMES) {
            if ($n -like "*$kw*") {
                $found += $_
                Write-Log "Processo suspeito detetado: $($_.Name) (PID $($_.Id))" "WARNING"
            }
        }
    }
    if ($found.Count -gt 0) {
        Write-Host "  [?] PROCESSOS SUSPEITOS DETETADOS:" -ForegroundColor Red
        $found | Format-Table Id, Name, CPU -AutoSize
    } else {
        Write-Host "  [?] Nenhum processo suspeito detetado." -ForegroundColor Green
        Write-Log "Nenhum processo suspeito detetado" "SUCCESS"
    }
}

function Stop-HighUsageProcesses {
    param([double]$CpuThreshold = 80, [double]$MemThresholdMB = 1000)
    Write-Title "AUTO-ENCERRAR PROCESSOS COM USO ELEVADO"
    Write-Host "  Limite CPU: ${CpuThreshold}s acumulados | Limite RAM: ${MemThresholdMB}MB" -ForegroundColor DarkGray
    Write-Host ""
    $killed = 0
    Get-Process | ForEach-Object {
        $ram = $_.WorkingSet64 / 1MB
        if ($_.CPU -gt $CpuThreshold -or $ram -gt $MemThresholdMB) {
            Write-Host "  [?] A encerrar: $($_.Name) | CPU=$([math]::Round($_.CPU,1))s | RAM=$([math]::Round($ram,1))MB" -ForegroundColor Yellow
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
            Write-Log "Auto-encerrado: $($_.Name) CPU=$($_.CPU) RAM=${ram}MB" "WARNING"
            $killed++
        }
    }
    if ($killed -eq 0) {
        Write-Host "  [?] Nenhum processo excedeu os limites." -ForegroundColor Green
    } else {
        Write-Host "  [?] $killed processo(s) encerrado(s)." -ForegroundColor Yellow
    }
}

function Export-ProcessReport {
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "$Global:REPORT_DIR\processos_$ts.txt"
    $content  = "RELATORIO DE PROCESSOS ? $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $content += "=" * 70 + "`n`n"
    $content += (Get-Process | Sort-Object CPU -Descending |
        Select-Object Id, Name,
            @{N="CPU(s)";E={[math]::Round($_.CPU,2)}},
            @{N="RAM(MB)";E={[math]::Round($_.WorkingSet64/1MB,1)}} |
        Format-Table -AutoSize | Out-String)
    $content | Out-File $file -Encoding UTF8
    Write-Host "  [?] Relatorio guardado: $file" -ForegroundColor Green
    Write-Log "Relatorio de processos gerado: $file" "SUCCESS"
}

function Show-ProcessMenu {
    while ($true) {
        Write-Title "GESTAO DE PROCESSOS E MEMORIA"
        Write-Host "  1. Listar processos (por CPU)"
        Write-Host "  2. Listar processos (por Memoria)"
        Write-Host "  3. Encerrar processo por PID"
        Write-Host "  4. Detetar processos suspeitos"
        Write-Host "  5. Auto-encerrar processos com uso elevado"
        Write-Host "  6. Gerar relatorio de processos"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" { Get-TopProcesses -SortBy "CPU";    Pause-Menu }
            "2" { Get-TopProcesses -SortBy "Memory"; Pause-Menu }
            "3" {
                $pid_in = Read-Host "  PID do processo"
                if ($pid_in -match '^\d+$') { Stop-ProcessById -PID_Target ([int]$pid_in) }
                Pause-Menu
            }
            "4" { Find-SuspiciousProcesses; Pause-Menu }
            "5" { Stop-HighUsageProcesses;  Pause-Menu }
            "6" { Export-ProcessReport;     Pause-Menu }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
