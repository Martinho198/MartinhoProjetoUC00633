# ================================================================
#  Modulo 4: Monitorizacao de Seguranca
# ================================================================

$SUSPICIOUS_PORTS = @(4444, 1337, 31337, 6666, 12345, 54321)

function Get-FailedLogins {
    param([int]$MaxEvents = 20)
    Write-Title "TENTATIVAS DE LOGIN FALHADAS (Event ID 4625)"
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} `
                    -MaxEvents $MaxEvents -ErrorAction Stop
        if ($events.Count -eq 0) {
            Write-Host "  [?] Nenhuma tentativa de login falhada encontrada." -ForegroundColor Green
        } else {
            Write-Host "  [?] $($events.Count) tentativas encontradas:`n" -ForegroundColor Yellow
            $events | ForEach-Object {
                $xml  = [xml]$_.ToXml()
                $user = $xml.Event.EventData.Data | Where-Object {$_.Name -eq 'TargetUserName'} | Select-Object -ExpandProperty '#text'
                $ip   = $xml.Event.EventData.Data | Where-Object {$_.Name -eq 'IpAddress'}      | Select-Object -ExpandProperty '#text'
                Write-Host ("  {0}  Utilizador: {1,-25} IP: {2}" -f $_.TimeCreated, $user, $ip) -ForegroundColor DarkGray
            }
            Write-Log "$($events.Count) tentativas de login falhadas encontradas" "WARNING"
        }
    } catch {
        Write-Host "  [!] Requer execucao como Administrador para aceder aos logs de seguranca." -ForegroundColor Yellow
        Write-Log "Acesso negado aos logs de seguranca" "WARNING"
    }
}

function Get-OpenPorts {
    Write-Title "PORTAS ABERTAS / EM ESCUTA"
    $connections = netstat -ano | Select-String "LISTENING"
    Write-Host ("  {0,-10} {1,-30} {2}" -f "Proto", "Endereco Local", "PID") -ForegroundColor Cyan
    Write-Host "  " + "-" * 55 -ForegroundColor DarkGray
    $connections | ForEach-Object {
        $parts = $_.Line.Trim() -split '\s+'
        $port  = ($parts[1] -split ':')[-1]
        $flag  = if ($SUSPICIOUS_PORTS -contains [int]$port) { " ? SUSPEITA" } else { "" }
        $color = if ($flag) { "Red" } else { "White" }
        Write-Host ("  {0,-10} {1,-30} {2}{3}" -f $parts[0], $parts[1], $parts[4], $flag) -ForegroundColor $color
    }
    Write-Log "Verificacao de portas abertas executada" "INFO"
}

function Get-ActiveConnections {
    Write-Title "CONEXOES DE REDE ATIVAS"
    $connections = netstat -ano | Select-String "ESTABLISHED"
    if (-not $connections) {
        Write-Host "  Nenhuma conexao ativa encontrada." -ForegroundColor DarkGray
    } else {
        Write-Host ("  {0,-10} {1,-30} {2,-30} {3}" -f "Proto","Local","Remoto","PID") -ForegroundColor Cyan
        Write-Host "  " + "-" * 75 -ForegroundColor DarkGray
        $connections | ForEach-Object {
            $parts = $_.Line.Trim() -split '\s+'
            $remPort = ($parts[2] -split ':')[-1]
            $color   = if ($SUSPICIOUS_PORTS -contains [int]$remPort) { "Red" } else { "DarkGray" }
            Write-Host ("  {0,-10} {1,-30} {2,-30} {3}" -f $parts[0],$parts[1],$parts[2],$parts[4]) -ForegroundColor $color
        }
    }
    Write-Log "Listagem de conexoes ativas executada" "INFO"
}

function Test-Connectivity {
    param([string[]]$Hosts = @("8.8.8.8","1.1.1.1","google.com","microsoft.com"))
    Write-Title "TESTE DE CONECTIVIDADE"
    foreach ($h in $Hosts) {
        $ok = Test-Connection -ComputerName $h -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($ok) {
            Write-Host "  [?] Online   $h" -ForegroundColor Green
            Write-Log "Ping OK: $h" "SUCCESS"
        } else {
            Write-Host "  [?] Offline  $h" -ForegroundColor Red
            Write-Log "Ping FALHOU: $h" "WARNING"
        }
    }
}

function Get-SuspiciousUsers {
    Write-Title "VERIFICACAO DE UTILIZADORES"
    $users = Get-LocalUser
    Write-Host ("  {0,-20} {1,-10} {2,-25} {3}" -f "Nome","Ativo","Ultimo Login","Descricao") -ForegroundColor Cyan
    Write-Host "  " + "-" * 75 -ForegroundColor DarkGray
    foreach ($u in $users) {
        $color = if (-not $u.Enabled) { "Red" } else { "White" }
        $last  = if ($u.LastLogon) { $u.LastLogon.ToString("yyyy-MM-dd HH:mm") } else { "Nunca" }
        Write-Host ("  {0,-20} {1,-10} {2,-25} {3}" -f $u.Name, $u.Enabled, $last, $u.Description) -ForegroundColor $color
    }
    Write-Log "Verificacao de utilizadores executada" "INFO"
}

function Export-SecurityReport {
    $ts   = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "$Global:REPORT_DIR\seguranca_$ts.txt"
    $content  = "RELATORIO DE SEGURANCA ? $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $content += "Hostname: $env:COMPUTERNAME`n"
    $content += "=" * 70 + "`n`n"
    $content += "UTILIZADORES LOCAIS:`n"
    $content += (Get-LocalUser | Select-Object Name, Enabled, LastLogon | Format-Table | Out-String)
    $content += "`nPORTAS EM ESCUTA:`n"
    $content += (netstat -ano | Select-String "LISTENING" | Out-String)
    $content | Out-File $file -Encoding UTF8
    Write-Host "  [?] Relatorio de seguranca guardado: $file" -ForegroundColor Green
    Write-Log "Relatorio de seguranca gerado: $file" "SUCCESS"
}

function Show-SecurityMenu {
    while ($true) {
        Write-Title "MONITORIZACAO DE SEGURANCA"
        Write-Host "  1. Tentativas de login falhadas"
        Write-Host "  2. Portas abertas / em escuta"
        Write-Host "  3. Conexoes de rede ativas"
        Write-Host "  4. Teste de conectividade"
        Write-Host "  5. Verificar utilizadores (suspeitos/inativos)"
        Write-Host "  6. Gerar relatorio de seguranca"
        Write-Host "  0. Voltar"
        Write-Host ""
        $opt = Read-Host "  Opcao"
        switch ($opt) {
            "1" { Get-FailedLogins;      Pause-Menu }
            "2" { Get-OpenPorts;         Pause-Menu }
            "3" { Get-ActiveConnections; Pause-Menu }
            "4" {
                $h = Read-Host "  Hosts separados por virgula (Enter = padrao)"
                if ($h) { Test-Connectivity -Hosts ($h -split ',') }
                else    { Test-Connectivity }
                Pause-Menu
            }
            "5" { Get-SuspiciousUsers;   Pause-Menu }
            "6" { Export-SecurityReport; Pause-Menu }
            "0" { return }
            default { Write-Host "  [!] Opcao invalida." -ForegroundColor Red; Start-Sleep 1 }
        }
    }
}
