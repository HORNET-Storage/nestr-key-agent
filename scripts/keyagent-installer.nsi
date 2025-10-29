; Nestr Key Agent NSIS Installer Script
; Installs the key agent as a Windows service

!define PRODUCT_NAME "NestrKeyAgent"
!define PRODUCT_VERSION "1.0.0"
!define PRODUCT_PUBLISHER "HORNET-Storage"
!define PRODUCT_WEB_SITE "https://github.com/HORNET-Storage/nestr-key-agent"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"
!define SERVICE_NAME "NestrKeyAgent"

; Modern UI
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "FileFunc.nsh"

; Variables
Var ServiceInstalled

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
!define MUI_WELCOMEPAGE_TITLE "Welcome to Nestr Key Agent Setup"
!define MUI_WELCOMEPAGE_TEXT "This wizard will install the Nestr Key Agent on your computer.$\r$\n$\r$\nThe Key Agent is a background service that securely manages cryptographic keys for GitNestr with AES-256 GCM encryption.$\r$\n$\r$\nClick Next to continue."

; Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Start Nestr Key Agent service now"
!define MUI_FINISHPAGE_RUN_FUNCTION StartService
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

; Language
!insertmacro MUI_LANGUAGE "English"

; Installer sections
Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "NestrKeyAgent-Setup.exe"
InstallDir "$PROGRAMFILES64\NestrKeyAgent"
InstallDirRegKey HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation"
ShowInstDetails show
ShowUnInstDetails show
RequestExecutionLevel admin

; Check for existing installation
Function .onInit
  ; Check if service already exists
  ClearErrors
  SimpleSC::ExistsService "${SERVICE_NAME}"
  Pop $0
  ${If} $0 == 0
    StrCpy $ServiceInstalled "1"
    MessageBox MB_YESNO|MB_ICONQUESTION "Nestr Key Agent service is already installed. Do you want to reinstall?" IDYES +2
    Quit
    ; Stop the service if running
    DetailPrint "Stopping existing service..."
    SimpleSC::StopService "${SERVICE_NAME}" 1 30
    Pop $0
    Sleep 2000
  ${Else}
    StrCpy $ServiceInstalled "0"
  ${EndIf}
FunctionEnd

; Main installation section
Section "NestrKeyAgent" SEC01
  SetOutPath "$INSTDIR"
  SetOverwrite ifnewer
  
  ; Stop service if it's running
  ${If} $ServiceInstalled == "1"
    DetailPrint "Stopping service for update..."
    SimpleSC::StopService "${SERVICE_NAME}" 1 30
    Pop $0
    Sleep 2000
    
    ; Remove old service
    DetailPrint "Removing old service..."
    SimpleSC::RemoveService "${SERVICE_NAME}"
    Pop $0
    Sleep 1000
  ${EndIf}
  
  ; Install binaries
  File "keyagent.exe"
  File "README.md"
  File "LICENSE"
  File "agent.protobuf"
  
  ; Create data directory for keys
  CreateDirectory "$APPDATA\NestrKeyAgent"
  CreateDirectory "$APPDATA\NestrKeyAgent\keys"
  
  ; Install as Windows service
  DetailPrint "Installing Windows service..."
  SimpleSC::InstallService "${SERVICE_NAME}" \
    "Nestr Key Agent" \
    "16" \
    "2" \
    "$INSTDIR\keyagent.exe" \
    "" \
    "" \
    ""
  Pop $0
  ${If} $0 != 0
    MessageBox MB_OK|MB_ICONEXCLAMATION "Failed to install service (Error: $0). The application can still be run manually."
  ${Else}
    DetailPrint "Service installed successfully"
    
    ; Set service description
    SimpleSC::SetServiceDescription "${SERVICE_NAME}" \
      "Manages cryptographic keys for GitNestr with secure AES-256 GCM encryption and time-limited caching"
    Pop $0
    
    ; Configure service for auto-start
    DetailPrint "Configuring service to start automatically..."
    SimpleSC::SetServiceStartType "${SERVICE_NAME}" "2"
    Pop $0
    
    ; Configure service recovery options (restart on failure)
    ExecWait 'sc failure "${SERVICE_NAME}" reset= 86400 actions= restart/60000/restart/60000/restart/60000'
  ${EndIf}
  
  ; Add to PATH for CLI tool
  EnVar::SetHKLM
  EnVar::AddValue "PATH" "$INSTDIR"
  Pop $0
  DetailPrint "Added to PATH: $0"
  
  ; Create uninstaller
  WriteUninstaller "$INSTDIR\uninstall.exe"
  
  ; Write registry keys
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\keyagent.exe"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKLM "${PRODUCT_UNINST_KEY}" "InstallLocation" "$INSTDIR"
  
  ; Create Start Menu shortcuts
  CreateDirectory "$SMPROGRAMS\Nestr Key Agent"
  CreateShortcut "$SMPROGRAMS\Nestr Key Agent\Start Service.lnk" "net" 'start "${SERVICE_NAME}"' "" "" SW_SHOWNORMAL "" "Start Nestr Key Agent Service"
  CreateShortcut "$SMPROGRAMS\Nestr Key Agent\Stop Service.lnk" "net" 'stop "${SERVICE_NAME}"' "" "" SW_SHOWNORMAL "" "Stop Nestr Key Agent Service"
  CreateShortcut "$SMPROGRAMS\Nestr Key Agent\Restart Service.lnk" "cmd.exe" '/c net stop "${SERVICE_NAME}" && net start "${SERVICE_NAME}"' "" "" SW_SHOWNORMAL "" "Restart Nestr Key Agent Service"
  CreateShortcut "$SMPROGRAMS\Nestr Key Agent\Uninstall.lnk" "$INSTDIR\uninstall.exe"
  
  ; Notify system of PATH change
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
  
  MessageBox MB_OK "Installation complete!$\r$\n$\r$\nNestr Key Agent has been installed as a Windows service.$\r$\n$\r$\nYou can manage the service from the Start Menu."
SectionEnd

; Function to start the service
Function StartService
  DetailPrint "Starting Nestr Key Agent service..."
  SimpleSC::StartService "${SERVICE_NAME}" "" 30
  Pop $0
  ${If} $0 == 0
    DetailPrint "Service started successfully"
    MessageBox MB_OK "Nestr Key Agent service has been started and will run automatically on system startup."
  ${Else}
    DetailPrint "Failed to start service (Error: $0)"
    MessageBox MB_OK|MB_ICONEXCLAMATION "Failed to start the service automatically. You can start it manually from the Start Menu or Services console."
  ${EndIf}
FunctionEnd

; Uninstaller section
Section Uninstall
  ; Stop and remove service
  DetailPrint "Stopping service..."
  SimpleSC::StopService "${SERVICE_NAME}" 1 30
  Pop $0
  Sleep 2000
  
  DetailPrint "Removing service..."
  SimpleSC::RemoveService "${SERVICE_NAME}"
  Pop $0
  Sleep 1000
  
  ; Remove from PATH
  EnVar::SetHKLM
  EnVar::DeleteValue "PATH" "$INSTDIR"
  Pop $0
  
  ; Ask about removing key data
  MessageBox MB_YESNO|MB_ICONQUESTION "Do you want to remove stored keys and configuration data?$\r$\n$\r$\nWARNING: This will permanently delete all your stored keys!" IDNO +3
  RMDir /r "$APPDATA\NestrKeyAgent"
  Goto +2
  DetailPrint "Keeping user data in $APPDATA\NestrKeyAgent"
  
  ; Delete files
  Delete "$INSTDIR\keyagent.exe"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\agent.protobuf"
  Delete "$INSTDIR\uninstall.exe"
  
  ; Remove directories
  RMDir "$INSTDIR"
  RMDir /r "$SMPROGRAMS\Nestr Key Agent"
  
  ; Remove registry keys
  DeleteRegKey HKLM "${PRODUCT_UNINST_KEY}"
  
  ; Notify system of PATH change
  SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
  
  MessageBox MB_OK "Nestr Key Agent has been uninstalled."
  SetAutoClose true
SectionEnd
