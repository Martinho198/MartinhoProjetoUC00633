# ================================================================
#  Sistema de Administracao e Monitorizacao de Infraestrutura
#  Autor  : Martinho Marques
#  UC     : UC00633
#  Repo   : MartinhoProjetoUC00633
# ================================================================

# Caminho base do projeto
$Global:BASE_DIR   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Global:LOG_DIR    = "$BASE_DIR\logs"
$Global:REPORT_DIR = "$BASE_DIR\reports"
$Global:BACKUP_DIR = "$BASE_DIR\backups"
$Global:CONFIG     = Get-Content "$BASE_DIR\config\settings.json" | ConvertFrom-Json

# Criar pastas se nao existirem
@($LOG_DIR, $REPORT_DIR, $BACKUP_DIR) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ | Out-Null }
}

# Carregar todos os modulos
Get-ChildItem "$BASE_DIR\modules\*.ps1" | ForEach-Object { . $_.FullName }

# ----------------------------------------------------------------
# MENU PRINCIPAL
# ----------------------------------------------------------------
function Show-MainMenu {
    while ($true) {
        Clear-Host
        Write-Host ""
        Write-Host "  ????????????????????????????????????????????????????????????" -ForegroundColor Cyan
        Write-Host "  ?   SISTEMA DE ADMINISTRACAO DE INFRAESTRUTURA  v1.0      ?" -ForegroundColor Cyan
        Write-Host "  ?   Autor: Martinho Marques  |  UC00633                   ?" -ForegroundColor Cyan
        Write-Host "  ????????????????????????????????????????????????????????????" -ForegroundColor Cyan
        Write-Host "  ?  1.  Gestao de Processos e Memoria                      ?" -ForegroundColor White
        Write-Host "  ?  2.  Sistema de Ficheiros                               ?" -ForegroundColor White
        Write-Host "  ?  3.  Monitorizacao de Recursos (CPU/RAM/Disco/Rede)     ?" -ForegroundColor White
        Write-Host "  ?  4.  Monitorizacao de Seguranca                         ?" -ForegroundColor White
        Write-Host "  ?  5.  Gestao de Utilizadores e Grupos                    ?" -ForegroundColor White
        Write-Host "  ?  6.  Gestao de Servicos                                 ?" -ForegroundColor White
        Write-Host "  ?  7.  Monitorizacao de Rede                              ?" -ForegroundColor White
        Write-Host "  ?  8.  Backup e Recuperacao                               ?" -ForegroundColor White
        Write-Host "  ?  9.  Gerar Relatorio Completo do Sistema                ?" -ForegroundColor White
        Write-Host "  ?  0.  Sair                                               ?" -ForegroundColor White
        Write-Host "  ????????????????????????????????????????????????????????????" -ForegroundColor Cyan
        Write-Host ""
        $choice = Read-Host "  Escolha uma opcao"

        switch ($choice) {
            "1" { Show-ProcessMenu }
            "2" { Show-FilesystemMenu }
            "3" { Show-ResourceMenu }
            "4" { Show-SecurityMenu }
            "5" { Show-UserMenu }
            "6" { Show-ServiceMenu }
            "7" { Show-NetworkMenu }
            "8" { Show-BackupMenu }
            "9" {
                Write-Log "Geracao de relatorio completo iniciada" "INFO"
                Export-FullReport
                Pause-Menu
            }
            "0" {
                Write-Host "`n  Ate logo!" -ForegroundColor Green
                Write-Log "Sistema encerrado pelo utilizador" "INFO"
                exit
            }
            default {
                Write-Host "  [!] Opcao invalida." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}

# Iniciar
Show-MainMenu
