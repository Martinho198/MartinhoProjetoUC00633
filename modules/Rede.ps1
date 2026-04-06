# ================================================================
#  Modulo 7: Monitorizacao de Rede
# ================================================================

function Get-NetworkInterfaces {
    Write-Title "INTERFACES DE REDE"
    try {
        Get-NetAdapter -ErrorAction Stop | Select-Object Name, Status, LinkSpeed, MacAddress |
            Format-Table -AutoSize
        Write-Host "  ENDERECOS IP:" -ForegroundColor Cyan
        Get-NetIPAddress -ErrorAction Stop | Where-Object { $_.AddressFamily -in @("IPv4","IPv6") } |
            Select-Object InterfaceAlias, AddressFamily, IPAddress, PrefixLength |
            Format-Table -AutoSize
    } catch {
        # Fallback para WMI
        Write-Host "  Interfaces (via WMI):" -ForegroundColor Cyan
        Get-WmiObject Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPEnabled } |
            Select-Object Description, @{N="IP";E={$_.IPAddress[0]}}, MACAddress |
            Format-Table -AutoSize
    }
    Write-Log "Interfaces de rede consultadas" "INFO"
}

function Get-NetworkStats {
    Write-Title "ESTATISTICAS DE REDE"
    try {
        Get-NetAdapterStatistics -ErrorAction Stop | Select-Object Name,
            @{N="TX (MB)"; E={[math]::Round($_.SentBytes/1MB,2)}},
            @{N="RX (MB)"; E={[math]::Round($_.ReceivedBytes/1MB,2)}},
            @{N="Pkts TX"; E={$_.SentUnicastPackets}},
            @{N="Pkts RX"; E={$_.ReceivedUnicastPackets}} |
            Format-Table -AutoSize
    } catch {
        Write-Host "  Estatisticas de rede nao disponiveis neste sistema." -ForegroundColor Yellow
        Write-Host "  A mostrar informacao de rede via WMI..." -ForegroundColor DarkGray
        Get-WmiObject Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPEnabled } |
            Select-Object Description, @{N="IP";E={$_.IPAddress[0]}} |
            Format-Table -AutoSize
    }
    Write-Log "Estatisticas de rede consultadas" "INFO"
}

function Start-PingTest {
    param([string]$Host_Target, [int]$Count = 4)
    Write-Title "PING - $Host_Target"
    try {
        $results = Test-Connection -ComputerName $Host_Target -Count $Count -ErrorAction Stop
        Write-Host "  [OK] $Host_Target esta ONLINE`n" -ForegroundColor Green
        $results | ForEach-Object {
            Write-Host ("  Resposta de {0}: tempo={1}ms TTL={2}" -f $_.Address, $_.ResponseTime, $_.TimeToLive) -ForegroundColor DarkGray
        }
        $avg = ($results | Measure-Object -Property ResponseTime -Average).Average
        Write-Host "`n  Tempo medio: $([math]::Round($avg,1))ms" -ForegroundColor Yellow
        Write-Log "Ping OK: $Host_Target (media $([math]::Round($avg,1))ms)" "SUCCESS"
    } catch {
        Write-Host "  [ERRO] $Host_Target esta OFFLINE ou inacessivel." -ForegroundColor Red
        Write-Log "Ping FALHOU: $Host_Target" "WARNING"
    }
}

function Start-Traceroute {
    param([string]$Host_Target)
    Write-Title "TRACEROUTE - $Host_Target"
    Write-Host "  A executar... aguarde (pode demorar ate 30 segundos).`n" -ForegroundColor DarkGray
    tracert $Host_Target
    Write-Log "Traceroute para $Host_Target executado" "INFO"
}

function Resolve-DNS {
    param([string]$Hostname)
    Write-Title "RESOLUCAO DNS - $Hostname"
    try {
        $result = Resolve-DnsName -Name $Hostname -ErrorAction Stop
        $result | Format-Table -AutoSize
        Write-Log "DNS resolvido: $Hostname" "SUCCESS"
    } catch {
        Write-Host "  [ERRO] Nao foi possivel resolver '$Hostname'" -ForegroundColor Red
        Write-Log "DNS falhou: $Hostname" "WARNING"
    }
}

function Get-NetstatOutput {
    Write-Title "NETSTAT - PORTAS EM ESCUTA"
    netstat -ano | Select-String "LISTENING"
    Write-Log "Netstat executado" "INFO"
}

function Test-MultipleHosts {
    param([string[]]$Hosts = @("8.8.8.8","1.1.1.1","google.com","microsoft.com","github.com"))
    Write-Title "TESTE DE CONECTIVIDADE"
    foreach ($h in $Hosts) {
        $ok    = Test-Connection -ComputerName $h -Count 1 -Quiet -ErrorAction SilentlyContinue
        $color  = if ($ok) { "Green" } else { "Red" }
        $icon   = if ($ok) { "OK" } else { "FALHOU" }
        Write-Host ("  [{0,-6}]  {1}" -f $icon, $h) -ForegroundColor $color
    }
    Write-Log "Teste de conectividade executado" "INFO"
}

function Export-NetworkReport {
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "$Global:REPORT_DIR\rede_$ts.txt"
    $lines = @()
    $lines += "RELATORIO DE REDE - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines += "Hostname: $env:COMPUTERNAME"
    $lines += "=" * 70
    $lines += ""
    $lines += "INTERFACES:"
    try {
        $lines += (Get-NetAdapter | Select-Object Name, Status, LinkSpeed | Format-Table | Out-String)
        $lines += "ENDERECOS IP:"
        $lines += (Get-NetIPAddress | Where-Object {$_.AddressFamily -eq "IPv4"} | Format-Table | Out-String)
    } catch {
        $lines += (Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled} |
            Select-Object Description, @{N="IP";E={$_.IPAddress[0]}} | Format-Table | Out-String)
    }
    $lines | Out-File $file -Encoding UTF8
    Write-Host "  [OK] Relatorio de rede guardado: $file" -ForegroundColor Green
    Write-Log "Relatorio de rede gerado: $file" "SUCCESS"
}

function Show-NetworkMenu {
    while ($true) {
        Write-Title "MONITORIZACAO DE REDE"
        Write-Host "  1. Interfaces de rede"
        Write-Host "  2. Estatisticas de trafego"
        Write-Host "  3. Ping a um host"
        Write-Host "  4. Teste de conectividade multipla"
        Write-Host "  5. Traceroute"
        Write-Host "  6. Resolucao DNS"
        Write-Host "  7. Netstat (portas em escuta)"
        Write-Host "  8. Gerar relatorio de rede"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" { Get-NetworkInterfaces; Pause-Menu }
            "2" { Get-NetworkStats;      Pause-Menu }
            "3" {
                $h = Read-Host "  Host a pingar (ex: google.com)"
                $c = Read-Host "  Numero de pacotes (Enter = 4)"
                if (-not $c) { $c = 4 }
                if ($h) { Start-PingTest -Host_Target $h -Count ([int]$c) }
                Pause-Menu
            }
            "4" {
                $h = Read-Host "  Hosts separados por virgula (Enter = padrao)"
                if ($h) { Test-MultipleHosts -Hosts ($h -split ',') }
                else    { Test-MultipleHosts }
                Pause-Menu
            }
            "5" {
                $h = Read-Host "  Host destino (ex: google.com)"
                if ($h) { Start-Traceroute -Host_Target $h }
                Pause-Menu
            }
            "6" {
                $h = Read-Host "  Hostname a resolver (ex: google.com)"
                if ($h) { Resolve-DNS -Hostname $h }
                Pause-Menu
            }
            "7" { Get-NetstatOutput;    Pause-Menu }
            "8" { Export-NetworkReport; Pause-Menu }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
