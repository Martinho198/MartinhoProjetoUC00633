# Sistema de Administração e Monitorização de Infraestrutura

**Repositório:** `MartinhoProjetoUC00633`
**Autor:** Martinho Marques
**UC:** UC00633
**Professor:** Dário Quental

---

## Como Executar

### 1. Abrir o PowerShell como Administrador

### 2. Permitir execução de scripts (apenas 1 vez)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 3. Navegar até à pasta do projeto
```powershell
cd C:\caminho\para\MartinhoProjetoUC00633
```

### 4. Executar o sistema
```powershell
.\INICIAR.bat
```

---

## Funcionalidades

| Módulo | Ficheiro | Descrição |
|--------|----------|-----------|
| 1. Processos | `modules/Processos.ps1` | Listar, encerrar, detetar processos suspeitos |
| 2. Ficheiros | `modules/Ficheiros.ps1` | Disco, permissões, hash, auditoria |
| 3. Recursos | `modules/Recursos.ps1` | CPU, RAM, Disco, Rede em tempo real |
| 4. Segurança | `modules/Seguranca.ps1` | Logins falhados, portas, conexões |
| 5. Utilizadores | `modules/Utilizadores.ps1` | Criar/remover users e grupos |
| 6. Serviços | `modules/Servicos.ps1` | Gerir e monitorizar serviços Windows |
| 7. Rede | `modules/Rede.ps1` | Ping, traceroute, DNS, netstat |
| 8. Backup | `modules/Backup.ps1` | Backup completo e incremental |

---

## Estrutura do Projeto

```
MartinhoProjetoUC00633/
├── Main.ps1                    ← Ponto de entrada
├── README.md
├── config/
│   └── settings.json           ← Configurações e limites de alerta
├── modules/
│   ├── Utils.ps1               ← Logger e utilitários
│   ├── Processos.ps1
│   ├── Ficheiros.ps1
│   ├── Recursos.ps1
│   ├── Seguranca.ps1
│   ├── Utilizadores.ps1
│   ├── Servicos.ps1
│   ├── Rede.ps1
│   ├── Backup.ps1
│   └── Relatorio.ps1
├── logs/                       ← Logs gerados automaticamente
├── reports/                    ← Relatórios gerados
└── backups/                    ← Backups criados
```

---

## Tecnologias

- **PowerShell 5.1+**
- **Windows Management Instrumentation (WMI)**
- **Windows Event Log**
- **NetTCPIP / NetAdapter**
- **Comandos nativos:** `netstat`, `tracert`, `ping`
