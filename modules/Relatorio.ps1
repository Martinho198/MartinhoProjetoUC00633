# ================================================================
#  Modulo: Relatorio Completo do Sistema
# ================================================================

function Export-FullReport {
    Write-Host "  [*] A gerar relatorio completo..." -ForegroundColor Cyan
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "$Global:REPORT_DIR\relatorio_completo_$ts.txt"
    $os   = Get-WmiObject Win32_OperatingSystem
    $cpu  = Get-WmiObject Win32_Processor | Select-Object -First 1

    $content  = "================================================================`n"
    $content += "  RELATORIO COMPLETO DO SISTEMA`n"
    $content += "  Gerado por: MartinhoProjetoUC00633`n"
    $content += "  Autor: Martinho Marques`n"
    $content += "  Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $content += "================================================================`n`n"

    # Sistema
    $content += "SISTEMA:`n"
    $content += "  Hostname  : $env:COMPUTERNAME`n"
    $content += "  OS        : $($os.Caption)`n"
    $content += "  Versao    : $($os.Version)`n"
    $content += "  Utilizador: $env:USERNAME`n"
    $uptime = (Get-Date) - $os.ConvertToDateTime($os.LastBootUpTime)
    $content += "  Uptime    : $([math]::Floor($uptime.TotalHours))h $($uptime.Minutes)m`n`n"

    # CPU
    $cpuLoad = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    $content += "CPU:`n"
    $content += "  Modelo : $($cpu.Name.Trim())`n"
    $content += "  Nucleos: $($cpu.NumberOfCores)`n"
    $content += "  Uso    : $cpuLoad%`n`n"

    # RAM
    $ramUsed  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 2)
    $ramTotal = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $content += "MEMORIA:`n"
    $content += "  Total : $ramTotal GB`n"
    $content += "  Usado : $ramUsed GB`n"
    $content += "  Livre : $([math]::Round($ramTotal - $ramUsed, 2)) GB`n`n"

    # Disco
    $content += "DISCO:`n"
    Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 } | ForEach-Object {
        $total = $_.Used + $_.Free
        $pct   = if ($total -gt 0) { [math]::Round($_.Used / $total * 100, 1) } else { 0 }
        $content += "  $($_.Name):\ ? $pct% | Usado: $(Format-Bytes $_.Used) | Livre: $(Format-Bytes $_.Free)`n"
    }
    $content += "`n"

    # Rede
    $content += "REDE:`n"
    $content += (Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4" -and $_.IPAddress -ne "127.0.0.1"} |
        Select-Object InterfaceAlias, IPAddress | Format-Table | Out-String)

    # Servicos criticos
    $content += "SERVICOS CRITICOS:`n"
    @("Spooler","LanmanServer","Dnscache","EventLog","DHCP") | ForEach-Object {
        $s = Get-Service -Name $_ -ErrorAction SilentlyContinue
        $status = if ($s) { $s.Status } else { "Nao encontrado" }
        $content += "  $_ : $status`n"
    }
    $content += "`n"

    # Top processos
    $content += "TOP 10 PROCESSOS (por RAM):`n"
    $content += (Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 |
        Select-Object Id, Name, @{N="RAM(MB)";E={[math]::Round($_.WorkingSet64/1MB,1)}} |
        Format-Table | Out-String)

    $content | Out-File $file -Encoding UTF8
    Write-Host "  [?] Relatorio completo guardado:" -ForegroundColor Green
    Write-Host "      $file" -ForegroundColor Yellow
    Write-Log "Relatorio completo gerado: $file" "SUCCESS"

    # Abrir a pasta de relatorios
    $open = Read-Host "  Abrir pasta de relatorios? (s/N)"
    if ($open -eq 's') { Invoke-Item $Global:REPORT_DIR }
}
