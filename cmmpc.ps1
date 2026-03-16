# =====================================================================
# MASTER SKRIPT PRO PŘÍPRAVU PRACOVNÍ STANICE CMM
# =====================================================================
# --- KONTROLA PRÁV SPRÁVCE ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Skript nebyl spuštěn jako správce! Pokouším se o restart s administrátorskými právy..."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Zahajuji kompletní konfiguraci Windows pro CMM stanici..." -ForegroundColor Cyan

# --- 1. NAPÁJENÍ A SPÁNEK (Úprava aktuálního schématu) ---
# pro jednotlivé nastavení viz powercfg /query a powercfg /list pro zobrazení dostupných schémat napájení - GUID schema, GUID skupina, GUID nastavení, index
Write-Host "1/4 Nastavuji režimy spánku a zakazuji uspávání portů..." -ForegroundColor Yellow

powercfg /SETACTIVE 381b4222-f694-41f0-9685-ff5bb260df2e

# Režim spánku: Nikdy (na nabíječce / AC), 30 minut (na baterii / DC)
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 30

# Vypnutí displeje: Nikdy na nabíječce (AC), 30 minut na baterii (DC)
powercfg -change -monitor-timeout-ac 0
powercfg -change -monitor-timeout-dc 30

# Vypnutí pevných disků po 2 hodinách (120 minut)
powercfg -change -disk-timeout-ac 120
powercfg -change -disk-timeout-dc 120

# Odkrytí skrytého nastavení PCIe (řeší chybu s neexistujícím schématem)
# powercfg -attributes 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a573dd0 -ATTRIB_HIDE

# Následné vypnutí "PCI Express Link State Power Management"
powercfg /SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
# powercfg /SETDCVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0 # baterka

# Vypnutí "USB Selective Suspend"
powercfg /SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0

# Aplikování změn do aktuálního schématu
powercfg /SETACTIVE 381b4222-f694-41f0-9685-ff5bb260df2e

# --- 2. ODŠKRTNUTÍ ÚSPORY ENERGIE VE SPRÁVCI ZAŘÍZENÍ ---
Write-Host "2/4 Vypínám úsporu energie přímo u hardwaru (WMI)..." -ForegroundColor Yellow
try {
    # Tento příkaz plošně zakáže vypínání zařízení z důvodu úspory (USB, Síťovky atd.)
    Set-CimInstance -Query 'SELECT * FROM MSPower_DeviceEnable' -Namespace root/WMI -Property @{Enable = $false} -ErrorAction Stop
    Write-Host "  -> Úspora energie u hardwaru úspěšně vypnuta." -ForegroundColor Green
} catch {
    Set-CimInstance -Query 'SELECT * FROM MSPower_DeviceEnable' -Namespace root/WMI -Property @{Enable = $false} -ErrorAction SilentlyContinue
    Write-Host "  -> Úspora aplikována (některá chráněná zařízení byla přeskočena)." -ForegroundColor DarkGray
}


# --- 3. ÚKLID HLAVNÍHO PANELU (Windows 11) ---
Write-Host "3/4 Uklízím hlavní panel (Hledání, Zobrazení úkolů, Widgety)..." -ForegroundColor Yellow

# Skrytí vyhledávacího pole (0 = skryto)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0
# Skrytí tlačítka Zobrazení úkolů (Task View)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0
# Skrytí Widgetů
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarDa" -Value 0


# --- 4. PRŮZKUMNÍK, BING A COPILOT ---
Write-Host "4/4 Nastavuji Průzkumníka, vypínám Bing a Copilot..." -ForegroundColor Yellow

# Zobrazení přípon souborů
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0

# Vypnutí Bing vyhledávání ve Start menu (Dvojitá pojistka: Uživatelská + GPO)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Value 0
$SearchPolicyPath = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
if (!(Test-Path $SearchPolicyPath)) { New-Item -Path $SearchPolicyPath -Force | Out-Null }
Set-ItemProperty -Path $SearchPolicyPath -Name "DisableSearchBoxSuggestions" -Value 1

# Zákaz Windows Copilot (GPO)
$CopilotPolicyPath = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
if (!(Test-Path $CopilotPolicyPath)) { New-Item -Path $CopilotPolicyPath -Force | Out-Null }
Set-ItemProperty -Path $CopilotPolicyPath -Name "TurnOffWindowsCopilot" -Value 1


# --- 5. DOKONČENÍ A RESTART UI ---
Write-Host "Restartuji Průzkumníka pro aplikování změn grafického rozhraní..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force

Write-Host "=================================================" -ForegroundColor Green
Write-Host "HOTOVO! Počítač je připraven jako CMM stanice." -ForegroundColor Green
Write-Host "Tip: Nezapomeň vyzkoušet oobe\bypassnro při další instalaci!" -ForegroundColor White
Start-Sleep -Seconds 5
