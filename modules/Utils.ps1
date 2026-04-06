# ================================================================
#  Modulo: Logger e Utilitarios Partilhados
# ================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARNING","ERROR","SUCCESS")][string]$Level = "INFO"
    )
    $ts      = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logFile = "$Global:LOG_DIR\$(Get-Date -Format 'yyyy-MM-dd')_sistema.log"
    $line    = "[$ts] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding UTF8

    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
    }
    Write-Host "  $line" -ForegroundColor $color
}

function Pause-Menu {
    Write-Host ""
    Write-Host "  Prima ENTER para continuar..." -ForegroundColor DarkGray
    Read-Host | Out-Null
}

function Write-Title {
    param([string]$Title)
    Clear-Host
    Write-Host ""
    Write-Host "  ??????????????????????????????????????????" -ForegroundColor Cyan
    Write-Host "   $Title" -ForegroundColor Yellow
    Write-Host "  ??????????????????????????????????????????" -ForegroundColor Cyan
    Write-Host ""
}

function Format-Bytes {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

function Draw-ProgressBar {
    param([double]$Percent, [int]$Width = 25)
    $filled = [math]::Round($Percent / 100 * $Width)
    $empty  = $Width - $filled
    $bar    = ("?" * $filled) + ("?" * $empty)
    $color  = if ($Percent -ge 85) { "Red" } elseif ($Percent -ge 60) { "Yellow" } else { "Green" }
    Write-Host "  [$bar] " -NoNewline -ForegroundColor $color
    Write-Host ("{0,6:N1}%" -f $Percent)
}
