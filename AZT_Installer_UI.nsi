;--------------------------------

  !include MUI2.nsh  ;Include Modern UI
  !include LogicLib.nsh
  !include WordFunc.nsh
  !include FileFunc.nsh
  !include StrFunc.nsh    
  !include WinMessages.nsh  ; For SendMessage

; Used to reposition the installer window
  !ifndef SPI_GETWORKAREA
  !define SPI_GETWORKAREA 0x0030
  !endif

; Define the installer icon
  !define MUI_ICON "azt.ico"

; Initialize plugins from StrFunc
  ${StrStr} 
  ${StrRep}
  ${StrLoc}
  ${StrTrimNewLines}

; ${Download} "url" "file": download with Windows' own curl.exe (Windows 10 1803+),
; so no download plugin is needed.  Pushes "OK", or an error message.
  !macro _Download url file
    StrCpy $dlUrl "${url}"
    StrCpy $dlFile "${file}"
    Call downloadFile
  !macroend
  !define Download "!insertmacro _Download"


; Show all the DetailsPrint to the user while installation is in progress
  ShowInstDetails show

;--------------------------------
; Constants

  !define NEWLINE "$\r$\n"
  !define TITLENAME "A-Z+T Installer"
  !define APPNAME "A-Z+T"
  !define INSTALLERNAME "AZT_Installer"  ; original name

  !define WAITTIME 5000  ; Milliseconds to wait for system calls and retries
  ; Python minors to try, from $pythonminor up, before walking back down its releases.
  ; 1 = never move to a newer minor (A-Z+T's requirements don't install on 3.14 yet)
  !define PYTHONMINORS 1

;--------------------------------
; Global variables    (Ref: See "Function .onInit" for initialization of values)

  Var /GLOBAL pythonminor
  Var /GLOBAL pythonversion
  Var /GLOBAL pythonfilename
  Var /GLOBAL pythonurl
  Var /GLOBAL pythonPath
  Var /GLOBAL pythonExe

  Var /GLOBAL gitversion
  Var /GLOBAL gitfilename
  Var /GLOBAL gitsize
  Var /GLOBAL giturl
  Var /GLOBAL gitExe
  Var /GLOBAL gitPath

  Var /GLOBAL praatversion
  Var /GLOBAL praatfilename
  Var /GLOBAL praaturl

  Var /GLOBAL xlpversion
  Var /GLOBAL xlpfilename
  Var /GLOBAL xlpurl

  Var /GLOBAL hgversion
  Var /GLOBAL hgfilename
  Var /GLOBAL hgurl

  Var /GLOBAL charisversion
  Var /GLOBAL charisfilename
  Var /GLOBAL chariszipfile
  Var /GLOBAL charisurl

  Var /GLOBAL filepath
  Var /GLOBAL filename

  var /GLOBAL azt
  var /GLOBAL aztRepoName
  var /GLOBAL aztRepoURL
  var /GLOBAL aztfilename

  ; Use 0 for current user and 1 for admin user
  Var /GLOBAL withadmin
  ; "1" in the elevated copy started by runAdminSteps (/ADMINSTEPS)
  Var /GLOBAL adminsteps
  Var /GLOBAL adminArgs
  var /GLOBAL logfile
  Var /GLOBAL log0
  var /GLOBAL logstring
  ; Problems that don't stop the installation, for the message at the end (see logWarning)
  Var /GLOBAL warnings
  Var /GLOBAL finishText
  Var /GLOBAL found
  Var /GLOBAL downloadName
  Var /GLOBAL ReturnError
  Var /GLOBAL tempLogFile
  Var /Global cmdFile
  Var /Global pathFile
  Var /GLOBAL desiredVersion
  Var /GLOBAL dlUrl
  Var /GLOBAL dlFile
  Var /GLOBAL tagUrl
  Var /GLOBAL latestTag
  

;------------------------------------------------------------------------------
;General
;------------------------------------------------------------------------------

  ;Name and file
  Name ${APPNAME}
  OutFile "${INSTALLERNAME}.exe"
  Unicode True

  ;Request application privileges for Windows
  ;Run as the user; machine-wide steps run in an elevated copy (see runAdminSteps)
  RequestExecutionLevel user

  ;Default installation folder  (sets INSTDIR; an existing $DESKTOP\azt is kept, see .onInit)
  ;The parent folder is the suite folder, where A-Z+T puts its sister repositories
  InstallDir "$LOCALAPPDATA\Programs\AZT\azt"

;--------------------------------
;Descriptions - if setting up multiple languages

  ;Language strings
  ;LangString DESC_pythonId ${LANG_ENGLISH} "Python"

  ;Assign language strings to sections
  ; !insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  ;   !insertmacro MUI_DESCRIPTION_TEXT ${pythonId} $(DESC_pythonId)
  ; !insertmacro MUI_FUNCTION_DESCRIPTION_END

;--------------------------------I
;Interface Settings

  !define MUI_ABORTWARNING
  #!define MUI_INSTFILESPAGE_COLORS "FFFFFF 000000" ;Two colors

;--------------------------------
;Pages   

  ; Invoke the custom positioning function on GUI start
  !define MUI_CUSTOMFUNCTION_GUIINIT positionInstWindow
  
  ; Enable MUI_PAGE_LICENSE to display the license page for user to accept
  ;!insertmacro MUI_PAGE_LICENSE ".\License.txt"
  
  ; Disable MUI_PAGE_COMPONENTS if you do not want the user to select which sections to install
  ; Every "Section" will appear on the list.   
  ; Required Sections are checked and set to Read/Only in .onInit using SectionSetFlags
  !define MUI_PAGE_CUSTOMFUNCTION_PRE skipComponentsIfAdmin
  !define MUI_PAGE_CUSTOMFUNCTION_LEAVE componentsLeave
  !insertmacro MUI_PAGE_COMPONENTS
  
  ; Enable MUI_PAGE_DIRECTORY to permit user to change the installationi target directory
  ;!insertmacro MUI_PAGE_DIRECTORY
  
  !insertmacro MUI_PAGE_INSTFILES
  
  ; FINISHPAGE macros are used to display a successful completion page with a "Launch Application" option
  ; (checked by default; the user can uncheck it).  Text is set in finishPre.
  !define MUI_PAGE_CUSTOMFUNCTION_PRE finishPre
  !define MUI_FINISHPAGE_TEXT "$finishText"
  !define MUI_FINISHPAGE_RUN ""
  !define MUI_FINISHPAGE_RUN_TEXT "Launch A-Z+T now"
  !define MUI_FINISHPAGE_RUN_FUNCTION launchAZT
  !insertmacro MUI_PAGE_FINISH

  ; Uninstaller macros
  ;!insertmacro MUI_UNPAGE_CONFIRM
  ;!insertmacro MUI_UNPAGE_INSTFILES
  
;--------------------------------
;Languages
 
  !insertmacro MUI_LANGUAGE "English"


;======================================================================================
;======================================================================================

;Installer Sections


;***************************************************************************************
Section "Python" pythonId
  
  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}"  "Installing Python..."
  StrCpy $logstring "${NEWLINE}-----  Python Installer ----- "
  Call logMessage

  StrCpy $downloadName "python"

  ; Check if python $pythonminor (any patch) is already installed.  Python minors install
  ; side by side, and the venv is made with this one by full path, so any other python
  ; on the path (older or newer) is left alone.
  Call findPythonMinor
  ${If} $pythonExe != ""
    StrCpy $logstring "$downloadName $pythonminor is already installed, skipping installation."
    Call logMessage
    goto pythonEnd
  ${EndIf}

  ; Which release to install (may move to a newer minor, see resolvePythonVersion)
  Call resolvePythonVersion
  ${If} $pythonversion == ""
    StrCpy $logstring "Unable to find a python $pythonminor installer, online or beside this installer.  Make sure your internet is connected.  Installation aborted."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
    Abort
  ${EndIf}
  Call findPythonMinor
  ${If} $pythonExe != ""
    StrCpy $logstring "$downloadName $pythonminor is already installed, skipping installation."
    Call logMessage
    goto pythonEnd
  ${EndIf}

  ;---------------------------------------------------------------
  ; Install Python
  ;---------------------------------------------------------------  
  ; Check if Python Installer file was already downloaded previously
  StrCpy $logstring "----- Must install python -----"
  Call logMessage
  FindFirst $0 $1 "$pythonfilename"
  StrCpy $logstring "$downloadName file search results: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $pythonfilename
    
    StrCpy $logstring "$pythonfilename already exists, using this version."
    Call logMessage

  ${Else}

    # Download Python Installer file
    StrCpy $logstring "Downloading Python from $pythonurl"
    Call logMessage

    ${Download} "$pythonurl" "$pythonfilename"
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "ERROR: $0.  Unable to download Python. Installation aborted."
      MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
      Call logMessage
      Abort
    ${Else}
      StrCpy $logstring "Python downloaded successfully."
      Call logMessage      
    ${EndIf}
  ${EndIf}
  
  ; Install Python
  StrCpy $logstring "Python installing...."
  Call logMessage
  ExecWait "$pythonfilename /silent PrependPath=1 Include_pip=1 InstallAllUsers=$withadmin Include_launcher=1 InstallLauncherAllUsers=$withadmin Include_test=0" $0
    
  StrCpy $logstring "Installation return code: $0"
  Call logMessage

  ${If} $0 != 0
    ${If} $0 == 1603
      StrCpy $logstring "Python is already installed."
      Call logMessage

      ; consider using these to uninstall old versions of python??
      ;wmic product where "name like 'Python%'" get version
      ;wmic product where "version='X.X.X'" call uninstall


      ; Uninstall existing Python
      ; MessageBox MB_YESNO "Python is already installed. Do you want to uninstall it?" IDYES uninstall_python

      ; uninstall_python:
      ;   StrCpy $logstring "Finding filepath where python is installed..."
      ;   Call logMessage
      ;   FindFirst $0 $1 "$pythonfilename"
      ;   StrCpy $logstring "Python file search: $0 $1"
      ;   Call logMessage
      ;   FindClose $0

      ;   ${If} $1 == $pythonfilename
        
      ;   StrCpy $logstring "Uninstalling python...."
      ;   Call logMessage
      ;   ; Locate the uninstaller and run it
      ;   ExecWait '$0\Uninstall.exe /silent'
    ${Else}
      StrCpy $logstring "ERROR: Python $pythonversion Installation failed with return code: $0" 
      Call logMessage
      MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
      Abort
    ${EndIf}    
  ${Else}

    StrCpy $logstring "Python installed successfully."
    Call logMessage
  ${EndIf}

;--------------------------------
pythonEnd:
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}"  "Locating Python..."
  StrCpy $logstring "${NEWLINE}-----  Get Final Python Path ----- "
  Call logMessage

  Call findPythonMinor
  ${If} $pythonExe == ""
    call getPythonPath
  ${EndIf}
  ${If} $pythonExe == ""
    StrCpy $logstring "Unable to find python.  You may need to run this installer again to complete the full installation."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
    Abort
  ${Else}
    StrCpy $logstring "Using Python path: $pythonExe"
  ${EndIf}
  
SectionEnd

;***************************************************************************************
Section "Git" gitId

  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing Git..."
  StrCpy $logstring "${NEWLINE}-----  Git Installer ----- "
  Call logMessage

  StrCpy $downloadName "git"

  ; As the user: run all the machine-wide steps (this one included) in one elevated copy
  ${If} $adminsteps != "1"
    Call runAdminSteps
    goto gitEnd
  ${EndIf}
  SetAutoClose true  ; the elevated copy closes itself when done
  Call resolveGitVersion

  ; Check if desired or later Git is already installed
  StrCpy $desiredVersion $gitVersion
  Call checkVersion  
  Pop $0
  ${If} $0 == "0"
    Pop $1
    StrCpy $logstring "$downloadName is already installed, version is <$1>, skipping installation."
    Call logMessage
    goto gitEnd
  ${EndIf}
 
  ; Check if Installer file was already downloaded previously
  FindFirst $0 $1 "$gitfilename"
  StrCpy $logstring "$downloadName file search: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $gitfilename
    
    StrCpy $logstring "$gitfilename already exists, using this version."
    Call logMessage

  ${Else}

    # Download Installer file
    StrCpy $logstring "Downloading giturl $gitversion $gitsize..."
    Call logMessage

    ${Download} "$giturl" "$gitfilename"
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "ERROR: $0.  Unable to download $downloadName. Installation aborted."
      Call logMessage
      MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK      
      Abort
    ${Else}
      StrCpy $logstring "$downloadName downloaded successfully."
      Call logMessage      
    ${EndIf}
  ${EndIf}
  
  ; Install 
  StrCpy $logstring "$downloadName installing...."
  Call logMessage
  ExecWait "$gitfilename /SILENT /NORESTART /NOCANCEL /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS=$\"icons,ext\shellhere,assoc,assoc_sh$\"" $0
    
  StrCpy $logstring "Installation return code: $0"
  Call logMessage

  ${If} $0 != 0
    ${If} $0 == 1603
      StrCpy $logstring "$downloadName is already installed, skipping installation."
      Call logMessage
    ${Else}
      StrCpy $logstring "ERROR: $downloadName $gitversion Installation failed with return code: $0" 
      Call logMessage
      MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
      Abort
    ${EndIf}    
  ${Else}
    StrCpy $logstring "$downloadName installed successfully."
    Call logMessage 
  ${EndIf}
  
;--------------------------------
gitEnd: 

  call getGitPath
  ${If} $gitExe == ""
    StrCpy $logstring "Unable to find git.  You may need to run this installer again to complete the full installation."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
    Abort
  ${Else}
    StrCpy $logstring "Using Git path: $gitExe"
  ${EndIf}


SectionEnd

;***************************************************************************************
; Hidden section, run only in the elevated copy (HKLM needs admin)
Section "-LongPaths" longPathsId

;----------------------------------------------------------------
; Enable readLongPathsEnabled in Registry for use with Python

!insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}"  "Updating Registry LongPathsEnabled"
StrCpy $logstring "${NEWLINE}-----  Registry LongPathsEnabled Test/Set ----- "
Call logMessage
; Ensure LongPathsEnabled is already set in the Windows Registry else set it now
; Cases 1 - 5 map to HKLM,HKCU,HKCR,HKU,HKCC (no easy way to do a for with strings)
StrCpy $found "false"
StrCpy $R2 HKLM
${For} $R1 1 5
  ${If} $found == "false"
    Call readLongPathsEnabled
    ifErrors loopRegistryNext
    StrCpy $logstring "Registry LongPathsEnabled found: $R0"
    Call logMessage
    ${If} $R0 == 1
      StrCpy $logstring "LongPathsEnabled registry already set for $R2."
      Call logMessage
      StrCpy $found "true"
    ${Else}
      ; Entry found but needs to be changed to 1
      StrCpy $logstring "LongPathsEnabled registry found for $R2, updating to 1."
      Call logMessage
      Call writeLongPathsEnabled
      ifErrors errorExitLongPaths
      StrCpy $found "true"
    ${EndIf}
  ${endIf}
loopRegistryNext:
  ClearErrors
${Next}

${If} $found == "false"
  ; Not found so try to set in HKLM
  StrCpy $R2 HKLM
  StrCpy $R1 "1"
  Call addLongPathsEnabled
  ifErrors errorExitLongPaths longPathsEnd

errorExitLongPaths:
  ClearErrors
  StrCpy $logstring "ERROR: Error setting Registry LongPathsEnabled"
  Call logWarning
  ; Does this need to abort or can it continue?
  ;MessageBox MB_OK $logstring
  ;Abort
${EndIf}

longPathsEnd:
SectionEnd


;***************************************************************************************
Section "AZT" aztId

  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing AZT from Git repository..."
  StrCpy $logstring "${NEWLINE}-----  AZT Installer ----- "
  Call logMessage    
      
  StrCpy $azt ""

  ; Show a message that we're starting to look for the repo
  StrCpy $logstring "Looking for a USB with the $aztRepoName on it"
  Call logMessage
  
  Push "EndStack"  ; Mark end of stack to check on Pop
  ClearErrors
  StrCpy $logstring "Executing wmic logicaldisk get deviceid..."
  Call logMessage
  nsExec::ExecToStack 'wmic logicaldisk get deviceid'
  ifErrors errorExitAzt
  Pop $0 ; Pop the return code
  StrCpy $logstring "   RC = $0"
  call logMessage
  Pop $0 ; Pop the results
  StrCpy $logstring "   Results = $0"
  call logMessage
  ${If} $0 == "EndStack"
    StrCpy $logstring "No logical drives found for searching"
    Call logMessage
  ${Else}    
    ; parse string with drive letters, newlines, and blanks    
    StrLen $R1 $0 ; Get the length of the string

    ; Initialize a loop to go through each character
    StrCpy $2 0
    ${Do}
        ; Get the current character
        StrCpy $3 $0 1 $2

        ; Check if the character is a newline or a blank
        ${If} $3 == $\n
            ; Skip newline
            Goto SkipChar
        ${EndIf}

        ${If} $3 == ' '
            ; Skip blank space
            Goto SkipChar
        ${EndIf}

        ; Check if this is a drive letter with a colon
        StrCpy $3 $0 2 $2
        StrCpy $4 $3 1 1 ; Get the second character to see if it's a colon

        ${If} $4 != ":"
            Goto SkipChar
        ${EndIf}

        ; Search this drive
        StrCpy $logstring "Drive: $3"
        call logMessage

        StrCpy $R3 "$3\*$aztRepoName"
        FindFirst $R4 $R5 "$R3"
        StrCpy $logstring "$R3 file search: $R4 $R5"
        Call logMessage
        FindClose $R4
        ${If} $R5 == $aztRepoName
          StrCpy $logstring "found repo in $R3"
          Call logMessage
          StrCpy $azt "$3\$R5"
          Goto exitFileLoop
        ${EndIf}

        ; Increment the index by 2 to skip to the next drive letter
        IntOp $2 $2 + 2
        Goto EndOfLoop

        SkipChar:
            ; Increment index by 1 to move to the next character
            IntOp $2 $2 + 1

        EndOfLoop:
    ${LoopUntil} $2 >= $R1
${EndIf}

exitFileLoop:

${If} $azt != ""
  StrCpy $logstring "azt is defined (local repo found): $azt"
  Call logMessage
${Else}
  StrCpy $azt $aztRepoURL
  StrCpy $logstring  "Local file not found; using github: $azt"
  Call logMessage
${EndIf}

StrCpy $logstring "Cloning A-Z+T source to $INSTDIR"
Call logMessage

; Convert the path to the installer to a path that git can use
Var /GLOBAL newPathString
StrCpy $0 $INSTDIR ; Original path
StrCpy $newPathString ""   ; Result string
StrLen $2 $0   ; Length of the original string
StrCpy $3 0    ; Index

; Loop through each character in the string
${Do}
    StrCpy $4 $0 1 $3 ; Extract one character at position $3
    ${If} $4 == "\"
        StrCpy $4 "/"
    ${EndIf}
    StrCpy $newPathString "$newPathString$4"   ; Append to result string
    IntOp $3 $3 + 1    ; Move to the next character
${LoopUntil} $3 == $2
StrCpy $logstring "git config path: $newPathString"

ClearErrors
Var /GLOBAL cmd
; Set the safe.directory in --global (--system needs admin), using both "\" and "/" paths to be safe
; Developer Notes:  To validate in a windows command prompt, use:
;                     git config --global --get-all safe.directory
;                   To clear them:
;                     git config --global --unset-all safe.directory

; Define the path to the log file
StrCpy $tempLogFile "git_error.log"
${If} $gitExe == ""  ; Should have been set during git install, else assume path is in env.
  StrCpy $logstring "gitExe variable is not set - using 'git'"
  StrCpy $gitExe "git"
${EndIf}

StrCpy $cmd `$\"$gitExe$\" config --global --add safe.directory $\"$INSTDIR$\"`
StrCpy $logstring "Executing $cmd ..."
Call logMessage
ExecWait `cmd /C $\"$cmd$\" 2>$tempLogFile` $0
StrCpy $logstring "   Return value: $0"
Call logMessage
${If} $0 != 0
  FileOpen $0 $tempLogFile r
  FileRead $0 $ReturnError
  FileClose $0
  StrCpy $logstring "ERROR: Git config error:  $ReturnError"
  Call logMessage
  abort
${EndIf}

StrCpy $cmd `$\"$gitExe$\" config --global --add safe.directory $\"$newPathString$\"`
StrCpy $logstring "Executing $cmd ..."
Call logMessage
ExecWait `cmd /C $\"$cmd$\" 2>$tempLogFile` $0
StrCpy $logstring "   Return value: $0"
Call logMessage
${If} $0 != 0
  FileOpen $0 $tempLogFile r
  FileRead $0 $ReturnError
  FileClose $0
  StrCpy $logstring "ERROR: Git config error:  $ReturnError"
  Call logMessage
  abort
${EndIf}

StrCpy $cmd `$\"$gitExe$\" clone --depth 1 $azt $\"$INSTDIR$\"`
StrCpy $logstring "Executing $cmd ..."
Call logMessage
ClearErrors
; Use ExecToStack instead of ExecWait to prevent the windows command prompt from showing
nsExec::ExecToStack 'cmd /C $\"$cmd$\" 2>$tempLogFile'
Pop $0
StrCpy $logstring "   Return value: $0"
Call logMessage
${If} $0 != 0
  FileOpen $0 $tempLogFile r
  FileRead $0 $ReturnError
  FileClose $0
  StrCpy $logstring "ERROR: Git clone error:  $ReturnError"
  Call logMessage
; If the error says repo already exists, just update it.  
  ${StrStr} $2 $ReturnError "exists and is not an empty directory"
  ${If} $2 != "" 
    StrCpy $logstring "AZT Repo already exists, updating..."
    Call logMessage  
    Call gitPullAZT
  ${Else}
    ; Display the error message
    StrCpy $logstring "There was an error getting the repository:${NEWLINE}${NEWLINE}$ReturnError${NEWLINE}${NEWLINE}Make sure your internet (or USB repository) is connected."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
    Abort
  ${EndIf}
${EndIf}


  ;----------------------------------------------------------------
  ; Install A-Z+T's python modules now (as the user), so the first run doesn't have to.
  ; Importing utilities.py_modules from the venv python, in the clone, runs A-Z+T's own
  ; bootstrap (requirements.txt, sister repositories).  Its exit code is not a success
  ; signal: env\azt_requirements.stamp holds the sha256 of requirements.txt, written only
  ; when it installed cleanly (a failure leaves any older stamp in place, so compare the
  ; content, not just that it exists).  Otherwise A-Z+T retries at first run.
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing A-Z+T modules.  This may take several minutes..."
  Var /GLOBAL venvPython
  Var /GLOBAL envDir
  ; Where A-Z+T's ensure_venv() looks: a sister ..\env first, else <azt>\env
  ${GetParent} "$INSTDIR" $envDir
  StrCpy $envDir "$envDir\env"
  ${IfNot} ${FileExists} "$envDir\Scripts\python.exe"
    StrCpy $envDir "$INSTDIR\env"
  ${EndIf}
  StrCpy $venvPython "$envDir\Scripts\python.exe"
  SetOutPath "$INSTDIR"
  ${IfNot} ${FileExists} "$venvPython"
    StrCpy $logstring "Creating virtual environment $envDir ..."
    Call logMessage
    nsExec::ExecToLog `"$pythonExe" -m venv "$envDir"`
    Pop $0
    StrCpy $logstring "   Return value: $0"
    Call logMessage
  ${EndIf}
  ${If} ${FileExists} "$venvPython"
    StrCpy $logstring "Installing A-Z+T modules from $INSTDIR\requirements.txt ..."
    Call logMessage
    nsExec::ExecToLog `"$venvPython" -c "import utilities.py_modules"`
    Pop $0
    ; The stamp must match the sha256 of requirements.txt (lowercase hex)
    StrCpy $2 ""
    ClearErrors
    FileOpen $1 "$envDir\azt_requirements.stamp" r
    ${IfNot} ${Errors}
      FileRead $1 $2
      FileClose $1
      ${StrTrimNewLines} $2 $2
    ${EndIf}
    ClearErrors
    nsExec::ExecToStack `"$venvPython" -c "import hashlib; print(hashlib.sha256(open('requirements.txt','rb').read()).hexdigest())"`
    Pop $0
    Pop $3
    ${StrTrimNewLines} $3 $3
    StrCpy $logstring "Requirements stamp: <$2>; requirements.txt sha256: <$3>"
    Call logMessage
    ${If} $0 == 0
    ${AndIf} $2 != ""
    ${AndIf} $2 S== $3
      StrCpy $logstring "A-Z+T modules installed."
      Call logMessage
    ${Else}
      StrCpy $logstring "A-Z+T modules not fully installed; A-Z+T will retry when it starts."
      Call logWarning
    ${EndIf}
  ${Else}
    StrCpy $logstring "Unable to create $envDir; A-Z+T will create it when it starts."
    Call logWarning
  ${EndIf}
  SetOutPath "$EXEDIR"

  ;----------------------------------------------------------------
  ; Successful install of AZT, set up shortcuts
  ;
  ; Shortcut icons go where they survive the installer being deleted (e.g. from Downloads)
  Var /GLOBAL iconDir
  StrCpy $iconDir "$LOCALAPPDATA\Programs\AZT\icons"
  SetOutPath "$iconDir"
  File "azt.ico"
  File "Transcribe-Tone.ico"
  SetOutPath "$EXEDIR"

  StrCpy $logstring  "Creating shortcut to AZT..."
  Call logMessage
  ; Create Shortcut
  StrCpy $0 "$DESKTOP\A-Z+T.lnk"   ; The shortcut name
  StrCpy $1 "$aztfilename" ; The target file (opened by the .py file association)
  ; Possible later form, with no console and no restart into the venv:
  ;   CreateShortcut "$0" "$envDir\Scripts\pythonw.exe" "$\"$aztfilename$\"" "$2" 0
  StrCpy $2 "$iconDir\azt.ico"
    
  ; Create application shortcut (switch to installation dir to have the correct "start in" target)
  SetOutPath "$INSTDIR"
  ClearErrors
  CreateShortcut "$0" "$1" "" "$2" 0
  ; Check for errors 
  IfErrors 0 +3
  StrCpy $logstring "ERROR: Failed to create shortcut for AZT."
  Call logWarning

  SetOutPath "$EXEDIR"

  StrCpy $logstring  "Creating shortcut to Transcriber tool..."
  Call logMessage
  StrCpy $0 "$DESKTOP\Transcriber.lnk"   ; The shortcut name
  StrCpy $1 "$venvPython" ; The target file (runs frontend.transcriber as a module)
  ${IfNot} ${FileExists} "$venvPython"
    StrCpy $1 "$pythonExe"
  ${EndIf}
  StrCpy $2 "$iconDir\Transcribe-Tone.ico"
  ; Create application shortcut (first in installation dir to have the correct "start in" target)
  SetOutPath "$INSTDIR"
  ClearErrors
  CreateShortcut "$0" "$1" "-m frontend.transcriber" "$2" 0
  ; Check for errors
  IfErrors 0 +3
  StrCpy $logstring "ERROR: Failed to create shortcut for Transcriber."
  Call logWarning
  SetOutPath "$EXEDIR"

  goto AZTEnd

errorExitAzt:
  ClearErrors
  ${If} $tempLogFile == "git_error.log"
    ; Read the error log file content into a variable
    FileOpen $0 $tempLogFile r
    FileRead $0 $1
    FileClose $0
    StrCpy $logstring "ERROR: $1"
    Call logMessage
  ${EndIf}
  StrCpy $logstring "Error cloning AZT"
  Call logMessage
  MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
  Abort

;--------------------------------
AZTEnd:
  StrCpy $logstring "A-Z+T installed successfully."
  Call logMessage
SectionEnd

;***************************************************************************************
Section "Charis" charisId

  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing Charis SIL Fonts..."
  StrCpy $logstring "${NEWLINE}-----  Charis Installer ----- "
  Call logMessage

  StrCpy $downloadName "Charis"
  Call resolveCharisVersion

  ; Check if Installer file was already downloaded previously
  StrCpy $logstring "$downloadName FindFirst: $chariszipfile"
  FindFirst $0 $1 "$chariszipfile"
  StrCpy $logstring "$downloadName file search: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $chariszipfile
    
    StrCpy $logstring "$chariszipfile already exists, using this version."
    Call logMessage

  ${Else}

    # Download Installer file
    StrCpy $logstring "Downloading $downloadName $chariszipfile from $charisurl"
    Call logMessage

    ${Download} "$charisurl" "$chariszipfile"
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "$0.  Error downloading $downloadName. Skipping Charis installation."
      Call logWarning
      goto charisEnd   ; skip installation
    ${Else}
      StrCpy $logstring "$downloadName downloaded successfully."
      Call logMessage      
    ${EndIf}
  ${EndIf}
  
  ; Unzip
  StrCpy $logstring "$downloadName unzipping $chariszipfile...."
  Call logMessage
  
  ; Run the tar command to extract the ZIP file
  StrCpy $tempLogFile "charis_error.log"
  ClearErrors  
  ExecWait 'cmd /C tar -xf "$chariszipfile" -C "$OUTDIR" 2>$tempLogFile' $0
  StrCpy $logstring "   Return value: $0"
  Call logMessage
  ${If} $0 != 0
    ; Read the error log file content into a variable
    FileOpen $0 $tempLogFile r
    FileRead $0 $ReturnError
    FileClose $0

    StrCpy $logstring "ERROR: Unable to extract $chariszipfile: ${NEWLINE}$ReturnError ${NEWLINE} Skipping Charis installation."
    Call logWarning
    goto charisEnd   ; skip installation
  ${EndIf}

  ;----------------------------------
  ; Install fonts
  ; If file was downloaded and unzipped successfuly, we will continue here to install the fonts
  ; Scroll through each .ttf file in the extracted folder and copy them to the system/fonts folder
  StrCpy $logstring "Installing Fonts $charisfilename...."
  Call logMessage
  
  # Define some variables only used here
  Var /GLOBAL TTFFileName
  Var /GLOBAL NOEXT
  Var /GLOBAL FACE
  Var /GLOBAL FACEMOD
  Var /GLOBAL TTF

  StrCpy $TTF "$EXEDIR\$charisfilename\*.ttf"
  StrCpy $logstring "TTF: $TTF"
  Call logMessage

  ClearErrors

  # Start the loop
  FindFirst $0 $1 "$TTF"
  StrCpy $logstring "  File search: $0 $1"
  Call logMessage
  ${If} $1 == ""
    StrCpy $logstring "ERROR: No .ttf files found in $EXEDIR\$charisfilename"
    Call logWarning
  ${EndIf}

  ${DoWhile} $1 != ""
  
    # Copy the font file to the Fonts directory
    StrCpy $TTF $EXEDIR\$charisfilename\$1
    ;StrCpy $logstring "Copying $TTF to $WINDIR\Fonts..."
    StrCpy $logstring "Copying $TTF to $FONTS..."
    Call logMessage
    CopyFiles "$TTF" "$FONTS"
    ifErrors 0 continueCharis
    StrCpy $logstring "Error copying $TTF to $FONTS"
    Call logMessage
    goto errorExitCharis

continueCharis:
    # Set the TTFFileName variable
    StrCpy $TTFFileName $1
    
    # Remove the .ttf extension to get NOEXT
    StrCpy $NOEXT $TTFFileName -4
    
    # Remove 'Charis-' from NOEXT to get FACE (v7 renamed the family from 'Charis SIL')
    ${If} $NOEXT != ""
        ${StrRep} $FACE $NOEXT "Charis-" ""
    ${EndIf}

    # Put a space before 'Italic' in FACE to get FACEMOD (e.g. 'SemiBold Italic'),
    # but not at the start ('Italic')
    ${StrRep} $FACEMOD $FACE "Italic" " Italic"
    StrCpy $R0 $FACEMOD 1
    ${If} $R0 == " "
      StrCpy $FACEMOD $FACEMOD "" 1
    ${EndIf}
    
    StrCpy $logstring "Installing $TTFFileName as $FACEMOD"
    Call logMessage
    
    # Write to the registry
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "Charis $FACEMOD (TrueType)" "$TTFFileName"
    ifErrors 0 continueCharis2
    StrCpy $logstring "Error writing updating registry for font: $FACEMOD"
    Call logMessage
    goto errorExitCharis

continueCharis2:
    ; Validate and write to log
    ; To validate directly, copy and paste this into windows prompt:
    ; reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v "Charis*"
    ReadRegStr $R9 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "Charis $FACEMOD (TrueType)"
    StrCpy $logstring "Registry read for $FACEMOD: $R9"
    Call logMessage
  
  # Loop to the next file
  FindNext $0 $1
  ${Loop}

  ; Notify windows about the font updates
  SendMessage ${HWND_BROADCAST} ${WM_FONTCHANGE} 0 0 /TIMEOUT=${WAITTIME}
  FindClose $0  
  goto charisEnd

errorExitCharis:
  ClearErrors
  StrCpy $logstring "Error installing Charis SIL Fonts - they may already be installed."
  Call logWarning
  
;--------------------------------
charisEnd:
SectionEnd

;***************************************************************************************
Section "XLingPaper" xlpId
  
  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing XLingPaper.  Answer prompts in that installer to complete."
  StrCpy $logstring "${NEWLINE}-----  XLP Installer ----- "
  Call logMessage

  StrCpy $logstring "Checking if XLingPaper is already installed..."
  Call logMessage
  ; Check if XLingPaper is already installed to skip the installation  
  StrCpy $R0 "XLingPaper"  
  StrCpy $R2 $PROGRAMFILES32  ; Program Files (x86)
  Push $R2
  Push $R0
  Call LocatePrograms
  Pop $R1
  ${If} $R1 != ""
    StrCpy $logstring "$R0 found: $R1.  Skipping installation."
    Call logMessage
    Goto xlpEnd
  ${Else}    
    StrCpy $R0 "XLingPaper"
    StrCpy $R2 $PROGRAMFILES64   ; Program Files (64-bit)    
    Push $R2
    Push $R0
    Call LocatePrograms
    Pop $R1
    ${If} $R1 != ""
      StrCpy $logstring "$R0 found: $R1.  Skipping installation."
      Call logMessage
      Goto xlpEnd
    ${EndIf}
  ${EndIf}
  
  Call resolveXLingPaperVersion

  ;----------------------------------------------------------------
  ; Check if Installer file was already downloaded previously
  FindFirst $0 $1 "$xlpfilename"
  StrCpy $logstring "XLingPaper file search results: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $xlpfilename
    
    StrCpy $logstring "$xlpfilename already exists, using this version."
    Call logMessage

  ${Else}
    # Download Installer file
    StrCpy $logstring "Downloading XLingPaper from $xlpurl"
    Call logMessage

    ${Download} "$xlpurl" "$xlpfilename"
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "ERROR: $0.  Unable to download XLingPaper."
      Call logMessage      
    ${Else}
      StrCpy $logstring "XLingPaper downloaded successfully."
      Call logMessage  
    ${EndIf}    
  ${EndIf}

  ;-------------------------------------
  ; Install XLP if the file is there now    
  FindFirst $0 $1 "$xlpfilename"
  StrCpy $logstring "XLingPaper file search results: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $xlpfilename
    ; Install XLingPaper
    StrCpy $logstring "XLingPaper installing...."
    Call logMessage
    ExecWait "$xlpfilename /silent" $0
      
    StrCpy $logstring "Installation return code: $0"
    Call logMessage

    ${If} $0 != 0      
        StrCpy $logstring "ERROR: XLingPaper $xlpversion Installation failed with return code: $0"
        Call logWarning
    ${Else}
      StrCpy $logstring "XLingPaper installed successfully."
      Call logMessage
    ${EndIf}
  ${Else}
    StrCpy $logstring "ERROR: Could not download XLingPaper. Skipping installation."
    Call logWarning
  ${EndIf}
;--------------------------------
xlpEnd:  
SectionEnd
  

;***************************************************************************************
Section "Praat" praatId
  
  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing Praat..."
  StrCpy $logstring "${NEWLINE}-----  Praat Installer ----- "
  Call logMessage

  StrCpy $logstring "Checking if Praat is already installed..."
  Call logMessage
  ; Check if Praat is already installed to skip the installation
  StrCpy $R0 "Praat.exe"
  StrCpy $R2 $PROGRAMFILES32  ; Program Files (x86)
  Push $R2
  Push $R0
  Call LocatePrograms
  Pop $R1
  ${If} $R1 != ""
    StrCpy $logstring "$R0 found: $R1.  Skipping installation."
    Call logMessage
    Goto praatEnd
  ${Else}    
    StrCpy $R0 "Praat.exe"
    StrCpy $R2 $PROGRAMFILES64   ; Program Files (64-bit)    
    Push $R2
    Push $R0
    Call LocatePrograms
    Pop $R1
    ${If} $R1 != ""
      StrCpy $logstring "$R0 found: $R1.  Skipping installation."
      Call logMessage
      Goto praatEnd
    ${EndIf}
  ${EndIf}
  
  Call resolvePraatVersion

  ;----------------------------------------------------------------
  ; Check if Installer file was already downloaded previously
  FindFirst $0 $1 "$praatfilename"
  StrCpy $logstring "Praat file search results: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $praatfilename
    
    StrCpy $logstring "$praatfilename already exists, using this version."
    Call logMessage

  ${Else}
    # Download Installer file
    StrCpy $logstring "Downloading Praat from $praaturl"
    Call logMessage

    ${Download} "$praaturl" "$praatfilename"
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "ERROR: $0.  Unable to download Praat."
      Call logWarning      
    ${Else}
      StrCpy $logstring "Praat downloaded successfully."
      Call logMessage  
    ${EndIf}    
  ${EndIf}

  ;-------------------------------------
  ; Install if the file is there now    
  FindFirst $0 $1 "$praatfilename"
  StrCpy $logstring "Praat file search results: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $praatfilename
    ; Unzip
    StrCpy $logstring "Extracting $praatfilename to $PROGRAMFILES..."
    Call logMessage
    
    ; Run the tar command to extract the ZIP file
    StrCpy $tempLogFile "praat_error.log"
    ClearErrors
    ExecWait 'cmd /C tar -xf "$praatfilename" -C "$PROGRAMFILES" 2>$tempLogFile' $0
    StrCpy $logstring "   Return value: $0"
    Call logMessage
    ${If} $0 != 0
      ; Read the error log file content into a variable
      FileOpen $0 $tempLogFile r
      FileRead $0 $ReturnError
      FileClose $0

      StrCpy $logstring "ERROR: Unable to extract $praatfilename: ${NEWLINE}$ReturnError"
      Call logWarning

    ${Else}

      StrCpy $logstring "Praat extracted successfully."
      Call logMessage
      StrCpy $logstring "Adding $PROGRAMFILES to path so Praat.exe will be found."
      Call logMessage
      
      ; Add to the HKLM Path (if not there) with PowerShell, since Path can be longer than
      ; an NSIS string.  Read unexpanded and written back as REG_EXPAND_SZ, to keep %...% entries.
      nsExec::ExecToStack `powershell -NoProfile -Command "$$k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $$true); $$p = $$k.GetValue('Path', '', 'DoNotExpandEnvironmentNames'); if (($$p -split ';') -notcontains '$PROGRAMFILES') { $$k.SetValue('Path', $$p.TrimEnd(';') + ';$PROGRAMFILES', 'ExpandString') }"`
      Pop $0
      Pop $1
      ${If} $0 == 0
        StrCpy $logstring "Registry adding $PROGRAMFILES to Path Environment variable.  RC = $0"
        Call logMessage
        SendMessage ${HWND_BROADCAST} ${WM_SETTINGCHANGE} 0 "STR:Environment" /TIMEOUT=${WAITTIME}
      ${Else}
        StrCpy $logstring "Unable to update registry to add $PROGRAMFILES to Path; Praat may not be recognized.  RC = $0 $1"
        Call logWarning
      ${EndIf}

    ${EndIf}
  ${EndIf}
;--------------------------------
praatEnd:
SectionEnd


;***************************************************************************************
Section /o "Mercurial"  mercurialId
  
  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing Mercurial...."
  StrCpy $logstring "${NEWLINE}-----  Mercurial Installer ----- "
  Call logMessage

  StrCpy $logstring "Checking if Mercurial is already installed..."
  Call logMessage

  ; Check if Mercurial is already installed to skip the installation
  ; Variables to hold search results
  StrCpy $R0 "Mercurial"
  StrCpy $R2 $PROGRAMFILES32  ; Program Files (x86)
  Push $R2
  Push $R0
  Call LocatePrograms
  Pop $R1
  ${If} $R1 != ""
    StrCpy $logstring "$R0 found: $R1.  Skipping installation."
    Call logMessage
    Goto mercurialEnd
  ${Else}    
    StrCpy $R0 "Mercurial"
    StrCpy $R2 $PROGRAMFILES64   ; Program Files (64-bit)    
    Push $R2
    Push $R0
    Call LocatePrograms
    Pop $R1
    ${If} $R1 != ""
      StrCpy $logstring "$R0 found: $R1.  Skipping installation."
      Call logMessage
      Goto mercurialEnd
    ${EndIf}
  ${EndIf}
  
  Call resolveMercurialVersion

  ;----------------------------------------------------------------
  ; Check if Installer file was already downloaded previously
  FindFirst $0 $1 "$hgfilename"
  StrCpy $logstring "Mercurial file search results: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $hgfilename
    
    StrCpy $logstring "$hgfilename already exists, using this version."
    Call logMessage

  ${Else}
    # Download Installer file
    StrCpy $logstring "Downloading Mercurial from $hgurl"
    Call logMessage

    ${Download} "$hgurl" "$hgfilename"
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "ERROR: $0.  Unable to download Mercurial."
      Call logMessage      
    ${Else}
      StrCpy $logstring "Mercurial downloaded successfully."
      Call logMessage  
    ${EndIf}    
  ${EndIf}

  ;-------------------------------------
  ; Install XLP if the file is there now    
  FindFirst $0 $1 "$hgfilename"
  StrCpy $logstring "Mercurial file search results: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $hgfilename
    ; Install Mercurial
    StrCpy $logstring "Mercurial installing...."
    Call logMessage
    ExecWait "$hgfilename /silent" $0
      
    StrCpy $logstring "Installation return code: $0"
    Call logMessage

    ${If} $0 != 0      
        StrCpy $logstring "ERROR: Mercurial $hgversion Installation failed with return code: $0"
        Call logWarning
    ${Else}
      StrCpy $logstring "Mercurial installed successfully."
      Call logMessage
    ${EndIf}
  ${Else}
    StrCpy $logstring "ERROR: Could not download Mercurial. Skipping installation."
    Call logWarning
  ${EndIf}
;--------------------------------  
mercurialEnd:
SectionEnd

;Section "Uninstaller"
  ;----------------------------------------------------------------
  ;Create uninstaller  (If needed)
  ; StrCpy $logstring "${NEWLINE}-----  Create Uninstaller ----- "
  ; Call logMessage  
  ;WriteUninstaller "$INSTDIR\Uninstall.exe"

;--------------------------------
;SectionEnd

;***************************************************************************************
;--------------------------------------------------------------------------------------
;Uninstaller Section
;--------------------------------------------------------------------------------------
;Section "Uninstall"

  ;TBD Add uninstall code

  ;Delete "$INSTDIR\Uninstall.exe"
  ;RMDir "$INSTDIR"
  #DeleteRegKey /ifempty HKCU "Software\azt"

;SectionEnd


;======================================================================================
;======================================================================================
;
; Functions

;-----------------------------------------------------------------
; positionInstWindow - called during .onGUIInit to reposition the window
;                      Moving slightly off center to prevent it being hidden
;                      behind other installer windows.
Function positionInstWindow  
  System::Store S
  System::Call '*(i,i,i,i,i,i,i,i,i,i)i.r9' ; Allocate a RECT/MONITORINFO struct
  System::Call 'USER32::GetWindowRect(i$hwndParent, ir9)'
  System::Call '*$9(i.r1,i.r2,i.r3,i.r4)' ; Extract data from RECT
  IntOp $3 $3 - $1 ; Window width
  IntOp $4 $4 - $2 ; Window height
  System::Call "User32::SystemParametersInfo(i${SPI_GETWORKAREA}, i0, ir9, i0)"
  System::Call '*$9(i.r5,i.r6,i.r7,i.r8)' ; Extract data from RECT
  System::Call 'USER32::MonitorFromWindow(i$hwndParent, i1)i.r0'
  ${If} $0 <> 0
      System::Call '*$9(i40)' ; Set MONITORINFO.cbSize
      System::Call 'USER32::GetMonitorInfo(ir0, ir9)i.r0'
      ${IfThen} $0 <> 0 ${|} System::Call "*$9(i,i,i,i,i,i.r5,i.r6,i.r7,i.r8)" ${|} ; Extract data from MONITORINFO
  ${EndIf}
  System::Free $9
  IntOp $7 $7 - $5 ; Workarea width
  IntOp $8 $8 - $6 ; Workarea height
  IntOp $7 $7 / 2
  IntOp $8 $8 / 2
  IntOp $1 $5 + $7 ; Left = Workarea left + (Workarea width / 2)
  IntOp $2 $6 + $8 ; Top = Workarea top + (Workarea height / 2)
  IntOp $3 $3 / 2
  IntOp $4 $4 / 2
  IntOp $1 $1 - $3 ; Left -= Window width / 2
  IntOp $2 $2 - $4 ; Top -= Window height / 2
  IntOp $1 $1 - 100 ; Move left slightly
  IntOp $2 $2 - 100 ; Move up slightly
  StrCpy $logstring "Windows coordinates: $1 W $2 H"
  Call logMessage  
  System::Call 'USER32::SetWindowPos(i$hwndParent, i, ir1, ir2, i, i, i 0x211)' ; NoSize+NoZOrder+NoActivate
  System::Store L $0
  ;StrCpy $logstring "SetWindowPos result:  $0"
  ;Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; logMessage: Function opens the file to be open for write at handle $log0
; Parms:       $logstring contains the string to write to the file
; Function logMessage
;   FileOpen $log0 $logfile a
;   SetDetailsPrint both  ; some macros seem to be changing this, reset it to make sure DetailPrint write to console
;   DetailPrint $logstring
;   FileWrite $log0 "$logstring${NEWLINE}"
;   FileClose $log0
;   ClearErrors
; FunctionEnd

;-----------------------------------------------------------------
; logMessage: Function expects the file to be open for write at handle $log0
; Parms:       $logstring contains the string to write to the file
;              $log0 contains the output log handle, opened in .onInit 
Function logMessage
  SetDetailsPrint both  ; some macros seem to be changing this, reset it to make sure DetailPrint write to console
  DetailPrint $logstring
  FileWrite $log0 "$logstring${NEWLINE}"
FunctionEnd

;-----------------------------------------------------------------
; logWarning: Function logs $logstring like logMessage, and also keeps it for the
;             message at the end, for problems that don't stop the installation
Function logWarning
  Call logMessage
  StrCpy $warnings "$warnings- $logstring${NEWLINE}"
FunctionEnd

;-----------------------------------------------------------------
; LocatePrograms: Function to locate a searchstring in a given path
; Used primarily to search for existence of programs in the progrm files directories
; Inputs are expected on the stack:
;   Search string should be the first thing in the stack - Pop $searchString
;   Search path is the second item on the stack - Pop $searchPath
; Output:   Result of search will be pushed to the stack, will be "" if not found
Function LocatePrograms
	
  Var /GLOBAL searchString
  Var /GLOBAL searchPath
  Var /GLOBAL searchResult

  StrCpy $searchResult ""

  Pop $searchString
  Pop $searchPath
  StrCpy $logstring "LocatePrograms - searching for file $searchString in $searchPath"
  Call logMessage

  ; A file or directory directly in $searchPath (not in subdirectories)
  ${If} ${FileExists} "$searchPath\$searchString"
    StrCpy $searchResult "$searchPath\$searchString"
    StrCpy $logstring "$searchString found: $searchResult"
    Call logMessage
  ${EndIf}

  Push $searchResult

FunctionEnd

;-----------------------------------------------------------------
; readLongPathsEnabled: Function attempts to read the registry 
;     Expects $R1 to have a value from 1 to 5 that maps to a registry key
;       Cases 1 - 5 map to HKLM,HKCU,HKCR,HKU,HKCC (no easy way to do a for with strings)
;     Sets $R2 to the corresponding registry key value
;     If found, $R0 contains the DWORD value
;     If NOT found, will set error flag -- caller should check with ifErrors
Function readLongPathsEnabled
  StrCpy $logstring "Reading Registry Variable LongPathsEnabled - pass $R1"
  Call logMessage  
  ; Note:  Repeating the ReadRegDWORD in each case because the command does not accept a 
  ;        variable for the key (HKLM, etc.) -- it must be hardcoded.
  ${Switch} $R1
    ${Case} 1
      StrCpy $R2 HKLM
      ReadRegDWORD $R0 HKLM "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled"
      ${Break}
    ${Case} 2
      StrCpy $R2 HKCU
      ReadRegDWORD $R0 HKCU "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled"
      ${Break}
    ${Case} 3
      StrCpy $R2 HKCR
      ReadRegDWORD $R0 HKCR "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled"
      ${Break}
    ${Case} 4
      StrCpy $R2 HKU
      ReadRegDWORD $R0 HKU "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled"
      ${Break}
    ${Case} 5
      StrCpy $R2 HKCC
      ReadRegDWORD $R0 HKCC "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled"
      ${Break}
  ${EndSwitch}  
FunctionEnd

;-----------------------------------------------------------------
; writeLongPathsEnabled: Function sets the DWORD value in LongPathsEnabled in the registry 
;     Expects $R1 to have a value from 1 to 5 that maps to a registry key
;       Cases 1 - 5 map to HKLM,HKCU,HKCR,HKU,HKCC (no easy way to do a for with strings)
;     Sets $R2 to the corresponding registry key value
;     If fails, will set error flag -- caller should check with ifErrors
Function writeLongPathsEnabled
  StrCpy $logstring "Reading Registry Variable LongPathsEnabled"
  Call logMessage
  ; Cases 1 - 5 map to HKLM,HKCU,HKCR,HKU,HKCC (no easy way to do a for with strings)
  ${Switch} $R1
    ${Case} 1
      StrCpy $R2 HKLM
      WriteRegDWORD HKLM "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1
      ${Break}
    ${Case} 2
      StrCpy $R2 HKCU
      WriteRegDWORD HKCU "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1
      ${Break}
    ${Case} 3
      StrCpy $R2 HKCR
      WriteRegDWORD HKCR "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1
      ${Break}
    ${Case} 4
      StrCpy $R2 HKU
      WriteRegDWORD HKU "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1
      ${Break}
    ${Case} 5
      StrCpy $R2 HKCC
      WriteRegDWORD HKCC "SYSTEM\CurrentControlSet\Control\FileSystem" "LongPathsEnabled" 1
      ${Break}
  ${EndSwitch}
FunctionEnd

;-----------------------------------------------------------------
; addLongPathsEnabled: Function adds a new entry for LongPathsEnabled in the registry 
;     Expects $R1 to have a value from 1 to 5 that maps to a registry key
;     Expects $R2 to have the the corresponding registry key (HKLM,HKCU,HKCR,HKU,HKCC )
;     Sets $R0 with the value from the registry if no error
;     If fails, will set error flag -- caller should check with ifErrors
Function addLongPathsEnabled  
  StrCpy $logstring "Adding registry entry LongPathsEnabled in $R2"
  Call logMessage
  Call writeLongPathsEnabled
  ifErrors errorExit
  
  ; Verify that it's set now
  StrCpy $logstring "Verify registry entry was set correctly for LongPathsEnabled in $R2"
  Call logMessage
  
  Call readLongPathsEnabled
  ifErrors errorExit  
  StrCpy $logstring "Registry LongPathsEnabled found: $R0"
  Call logMessage
  ${If} $R0 == 1
    StrCpy $logstring "Registry LongPathsEnabled in $R2"
    Call logMessage
    StrCpy $found "true" 
  ${Else} 
    setErrors
  ${EndIf}

errorExit:
FunctionEnd


;----------------------------------------------------------------
; macro breaks down a version in the form major.minor.patch
; into its individual components so they can be compared.
!macro VersionToComponents version major minor patch
  Push "$R0"
  Push "$R1"
  Push "$R2"

  StrCpy $R0 "${version}"
  ${FindFirstChar} $R0 "." $R1
  StrCpy ${major} $R0 $R1
  StrCpy $R0 $R0 "" $R1 + 1

  ${FindFirstChar} $R0 "." $R1
  StrCpy ${minor} $R0 $R1
  StrCpy ${patch} $R0 "" $R1 + 1

  Pop $R2
  Pop $R1
  Pop $R0
!macroend
;-----------------------------------------------------------------
; checkVersion: Function checks for app already installed
;                  and its version number.
; Inputs:  global variables should be set to:
;          $downloadName = app name (python or git)
;          $desiredVersion = the desired version we need to download
; Compares the installed version (if any) to the desired version
; Results pushed to the stack:
; Push $thisVersion : version string found
; Push $exitCode : "0" = version is installed and is >= desired version.
;                  "1" = no other version was found (new install needed)
;                  "2" = older version found (may want to uninstall older version then install new version)
Function checkVersion
  Var /GLOBAL thisVersion
  Var /GLOBAL versionOffset
  Var /GLOBAL exitCode
  Var /GLOBAL firstline
  
  StrCpy $thisVersion "Desired version not found"  

  ; Run '<app> --version' and capture the output
  StrCpy $logstring "Checking app version"
  Call logMessage

  StrCpy $tempLogFile "$downloadName_version.txt"
  ExecWait 'cmd /C $downloadName --version >$tempLogFile' $exitCode
  StrCpy $logstring "   Return code: $exitCode"
  Call logMessage
  ${If} $exitCode == 0    
  
    ; Read the error log file content into a variable
    FileOpen $0 $tempLogFile r
    FileRead $0 $firstline
    FileClose $0

    ${StrTrimNewLines} $thisVersion $firstline
    StrCpy $logstring "$downloadName version results: $thisVersion"
    Call logMessage
  
    ; Extract the version number from the output
        
    ${If} $downloadName == "git"
      ; git:
      ; The output will be in a form such as "git version x.y.z.windows.n", where we only want x.y.z (major.minor.patch)
      ${StrLoc} $R0 $thisVersion "git version" ">" ; Find "<app> version" in the output - > is start of line
      IntOp $R0 $R0 + 11 ; Move the pointer to version number, 11 spaces beyond the "git version"
    ${Else}
      ; Python:
      ; The output will be in a form such as "Python x.y.z", where we only want x.y.z (major.minor.patch)
      ${StrLoc} $R0 $thisVersion "Python" ">" ; Find string in the output - > is start of line
      ;StrCpy $logstring "Python Version: $R0"
      ;Call logMessage
      IntOp $R0 $R0 + 7 ; Move the pointer to version number, starting 7 spaces beyond the "Python "
    ${EndIf}
    
    StrCpy $thisVersion $thisVersion "" $R0 ; Extract the version number and beyond
    StrCpy $logstring "thisVersion: $thisVersion"
    Call logMessage

    IntOp $versionOffset 0 - 0  ; start at 0
    ; Keep only the portion of the version thru the third period
    ${StrLoc} $R0 $thisVersion "." 0 ; Find first period (major)
    IntOp $R0 $R0 + 1
    IntOp $versionOffset $versionOffset + $R0
    StrCpy $R1 $thisVersion "" $R0  ; R1 stripped of major version
    ;StrCpy $logstring "R1: $R1"
    ;Call logMessage

    ${StrLoc} $R0 $R1 "."  $R0 ; find second period
    IntOp $R0 $R0 + 1
    IntOp $versionOffset $versionOffset + $R0
    StrCpy $R1 $R1 "" $R0  ; R1 stripped of minor version
    ;StrCpy $logstring "R1: $R1"
    ;Call logMessage

    ${StrLoc} $R0 $R1 "." $R0 ; location of third period
    ${If} $R0 == "" ; no third period, so take whole string      
      StrLen $R0 $R1
    ${EndIf}
    IntOp $versionOffset $versionOffset + $R0  ; total offset
    StrCpy $thisVersion $thisVersion $versionOffset 0 ; Extract just the version number
    StrCpy $logstring "extracted version number: $thisVersion"
    Call logMessage

    ; Prepare the version number for comparison by replacing any bad characters
    ${VersionConvert} $thisVersion "" $thisVersion
    ; Result expected in $R0: 0-Versions are equal; 1-thisVersion is newer; 2-desiredVersion is newer
    ${VersionCompare} $thisVersion $desiredVersion $R0
    StrCpy $logstring "VersionCompare result code: $R0"
    Call logMessage

    ${If} $R0 == "2"
      StrCpy $logstring "$downloadName version found: $thisVersion is less than desired $desiredVersion"
      Call logMessage
      StrCpy $exitCode "2" ; will require reinstall    
    ${Else}
      StrCpy $logstring "$downloadName version found: $thisVersion is newer or equal to desired $desiredVersion"
      Call logMessage
      StrCpy $exitCode "0" ; will not require reinstall  
    ${EndIf}

  ${Else}
      StrCpy $logstring "$downloadName is not installed."
      Call logMessage
      StrCpy $exitCode "1" ; will require install
  ${EndIf}

  ; Return values by pushing to stack
  StrCpy $logstring "checkVersion exitcode = $exitCode"
  Call logMessage  
  Push $thisVersion
  Push $exitCode
FunctionEnd

;-----------------------------------------------------------------
; gitPullAZT: Function gets drive and path where AZT repo lives
;             Switches to that directory and does a git pull
;             The switches back to the installation drive and directory
;
Function gitPullAZT
  StrCpy $logstring "---- gitPullAZT ---- "
  Call logMessage

  ; Save the current installation path
  Var /GLOBAL SaveCurrentDirectory
  StrCpy $SaveCurrentDirectory $EXEDIR
  StrCpy $logstring "Saving current directory: $SaveCurrentDirectory"
  Call logMessage    

  ; Get the current script's drive letter
  Var /GLOBAL ExeDrive
  ${GetRoot} $EXEDIR $ExeDrive
  StrCpy $logstring "GetRoot: Current drive: $ExeDrive"
  Call logMessage
  
  ; Store the target directory (modify as needed)
  StrCpy $1 $INSTDIR

  ; Get the drive letter of the target directory
  Var /GLOBAL InstDrive
  ${GetRoot} "$1" $InstDrive
  StrCpy $logstring "GetRoot: Target drive: $InstDrive"
  Call logMessage

  ; Compare current drive ($ExeDrive) with the target drive ($InstDrive)
  StrCmp $ExeDrive $InstDrive noDriveChange 0

  ; If the drives are different, switch to the target drive
  StrCpy $logstring "Switching to Drive: $InstDrive"
  Call logMessage

noDriveChange:
  ; Now change to the target directory
  SetOutPath "$1"
  StrCpy $logstring "Switched to $OUTDIR"
  Call logMessage  
  
  ; Do a git pull in the target directory
  StrCpy $logstring "Executing git pull origin...."
  Call logMessage
    
  StrCpy $tempLogFile "git_error.log"
  ClearErrors
  ExecWait 'cmd /C $\"$\"$gitExe$\" pull --depth 1 origin$\" 2>$tempLogFile' $0
  StrCpy $logstring "   Return value: $0"
  Call logMessage
  ${If} $0 != 0

    ; Read the error log file content into a variable
    FileOpen $0 $tempLogFile r
    FileRead $0 $ReturnError
    FileClose $0

    StrCpy $logstring "git pull origin returned error: ${NEWLINE}$ReturnError"
    Call logWarning
  ${EndIf}

  ; Switch back to the installation drive and directory
  ; Compare current drive ($ExeDrive) with the target drive ($InstDrive)
  StrCmp $ExeDrive $InstDrive noDriveChange2 0

  ; If the drives are different, switch to the target drive
  StrCpy $logstring "Switching to Drive: $ExeDrive"
  Call logMessage

noDriveChange2:
  
  ; Return to the exectutable path
  SetOutPath $SaveCurrentDirectory

  StrCpy $logstring "Switched to $OUTDIR"
  Call logMessage
  Return
FunctionEnd

;-----------------------------------------------------------------
; getPythonPath: Function searches for python executable.
;                If not found, runs a separate windows shell 
;                to pull the path from the environment variable
Function getPythonPath

  StrCpy $logstring "Running 'where python' to see if it is reachable."
  Call logMessage
  ; Check if desired or later version is already installed
  StrCpy $desiredVersion $pythonVersion
  Call checkVersion
  Pop $0 ; get exit code
  ${If} $0 == "0"
    Pop $1 ; get version
    StrCpy $logstring "Reachable Python version is good: $1"
    Call logMessage
    ; if it can be found directly, no need to use whole path
    StrCpy $pythonExe "python"
  ${Else}
    ; Older version or not found at all
    ${If} $0 == "2"
      Pop $1 ; get version
      StrCpy $logstring "Reachable Python version is the wrong one: $1"
      Call logMessage
    ${Else}
      StrCpy $logstring "Python is not reachable."
      Call logMessage    
    ${EndIf}

    ; If Python was just installed, it will not be in the current environment yet, so 
    ; we have to find it in a roundabout way, by executing a second shell 
    ; with runas running at user level.  This seems to cause the shell to pick up the new path.
    ; Use the "where" command to find the path.

    StrCpy $logstring "Trying to find the new path using windows shell..."  
    Call logMessage
    
    StrCpy $cmdFile "getpythonpath.cmd"
    StrCpy $pathFile "pythonpath.txt"
    Delete $pathFile
    ClearErrors
    FileOpen $R9 $cmdFile w
    FileWrite $R9 "@echo off${NEWLINE}"
    FileWrite $R9 "setlocal enabledelayedexpansion${NEWLINE}"

    FileWrite $R9 "REM Use PowerShell to retrieve the full PATH from the registry and set it in the current session${NEWLINE}"
    FileWrite $R9 "for /f $\"delims=$\" %%A in ('powershell -command $\"Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name Path | Select-Object -ExpandProperty Path$\"') do (${NEWLINE}"
    FileWrite $R9 "    set $\"SystemPath=%%A$\"${NEWLINE}"
    FileWrite $R9 ")${NEWLINE}"

    FileWrite $R9 "for /f $\"delims=$\" %%B in ('powershell -command $\"Get-ItemProperty -Path 'HKCU:\Environment' -Name Path | Select-Object -ExpandProperty Path$\"') do (${NEWLINE}"
    FileWrite $R9 "    set $\"UserPath=%%B$\"${NEWLINE}"
    FileWrite $R9 ")${NEWLINE}"
    FileWrite $R9 "REM Output the full PATH value for verification${NEWLINE}"
    FileWrite $R9 "echo Full System PATH: %SystemPath%\%UserPath%${NEWLINE}"
    FileWrite $R9 "REM Update the current session's PATH with both system and user paths to find python${NEWLINE}"
    FileWrite $R9 "Call set PATH=%SystemPath%;%UserPath%${NEWLINE}"
    FileWrite $R9 "where python 1>$\"$OUTDIR\$pathFile$\"${NEWLINE}"
    FileWrite $R9 "echo >NUL${NEWLINE}"   ; Force closed filehandle so we can read it quickly
    FileWrite $R9 "endlocal${NEWLINE}"
    FileWrite $R9 "exit /B${NEWLINE}"

    FileClose $R9 

    ClearErrors

    ; Get path to windows command line executable to use with powershell
    ReadEnvStr $R0 COMSPEC
    StrCpy $logstring 'powershell Start-Process -FilePath "$R0"-ArgumentList /C,"$OUTDIR\$cmdFile"'
    Call logMessage    

    ; Set timeout to give the powershell command time to complete before attempting to read the path file (in milliseconds)
    ;nsExec::ExecToStack /TIMEOUT=${WAITTIME} 'powershell Start-Process -FilePath "$R0" -ArgumentList /C,"$OUTDIR\$cmdFile"'
    nsExec::ExecToStack 'powershell Start-Process -FilePath "$R0" -ArgumentList /C,"$OUTDIR\$cmdFile"'
    Pop $0 ;return value is first on stack    
    ${If} $0 != 0
      Pop $1 ;get error message
      StrCpy $logstring "Powershell results: $0 $1"
      Call logMessage
    ${Else}
      ${For} $R1 1 5
        ; Open the path file.  If it fails, wait a few seconds and retry a few times before aborting.
        ClearErrors
        FileOpen $R9 $pathFile r
        ifErrors sleepLoop3

        StrCpy $logstring "Reading $pathFile..."
        Call logMessage
        ${Break}

        sleepLoop3:
        StrCpy $logstring "Error opening $pathFile.  Waiting ${WAITTIME} milliseconds and retrying, to make sure windows closed it..."
        Call logMessage      
        Sleep ${WAITTIME}  ; Wait for some seconds to ensure the file is written    
      ${Next}

      ifErrors 0 pythonFileOK
        ;StrCpy $logstring "Unable to read $pathFile. Terminating installer."
        StrCpy $logstring "Unable to read $pathFile. Try py instead..."
        Call logMessage
        goto tryPy
        ; MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
        ; Abort

      pythonFileOK:
        ; Read the first line of the path file created by the script
        FileRead $R9 $R7
        FileClose $R9
        
        ${StrTrimNewLines} $pythonPath $R7
        ${If} $pythonPath == ""
          StrCpy $logstring "pythonPath is empty, waiting ${WAITTIME} milliseconds and trying again..."
          Call logMessage
          ${For} $R1 1 5
            ; Open and read the path file.  If it fails, wait a few seconds and retry a few times
            Sleep ${WAITTIME}
            
            ClearErrors
            FileOpen $R9 "$OUTDIR\$pathFile" r
            ifErrors sleepLoop4

            StrCpy $logstring "Reading $pathFile..."
            Call logMessage
            FileRead $R9 $R7
            FileClose $R9
            
            ${StrTrimNewLines} $pythonPath $R7
            ${If} $pythonPath == "" 
              StrCpy $logstring "pythonPath is empty, waiting ${WAITTIME} milliseconds and retrying..."
              Call logMessage
              goto nextLoopPython
            ${EndIf}

            sleepLoop4:
            StrCpy $logstring "Error opening $pathFile.  Waiting ${WAITTIME} milliseconds and retrying..."
            Call logMessage     

            nextLoopPython:
          ${Next}

          ifErrors 0 pythonFileOK2
            ClearErrors
            ;StrCpy $logstring "Unable to read $pathFile. Terminating installer."
            StrCpy $logstring "Unable to read $pathFile. Try py instead..."
            Call logMessage
            goto tryPy
            ; MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
            ; Abort
          pythonFileOK2:
          ${If} $pythonPath == "" 
              ;StrCpy $logstring "pythonPath is empty.  Unable to continue with installation."
              StrCpy $logstring "pythonPath is empty.  Try py instead..."
              Call logMessage
              goto tryPy
              ;MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
              ;Abort
          ${EndIf}

        ${EndIf}

        StrCpy $logstring "Python path: $pythonPath"
        Call logMessage

        StrCpy $pythonExe "$pythonPath"
      
    ${EndIf}  
  ${EndIf}

goto skipPy
tryPy:
ExecWait 'cmd /C py --version >python_version.txt' $0
StrCpy $logstring "Py launcher --version return code: $0"
Call logMessage
;To force the logic below for testing: IntOp $0 1 - 0
${If} $0 != 0
  StrCpy $logstring "Unable to locate py launcher either. Installation will end.  Try re-running installer."
  Call logMessage
  MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
  Abort
${Else}
  ; use py instead of python
  StrCpy $pythonExe "py"
  StrCpy $logstring "Using py launcher instead of python for starting azt."
  Call logMessage
${EndIf}

skipPy:

  ClearErrors
  StrCpy $logstring "Final Python Path: $pythonExe"
  Call logMessage 
FunctionEnd

;-----------------------------------------------------------------
; downloadFile: Function downloads $dlUrl to $dlFile with Windows' own curl.exe
;               (use the ${Download} macro).  Leaves registers unchanged, and
;               pushes "OK", or an error message (and deletes any partial file).
Function downloadFile
  Push $0
  Push $1
  nsExec::ExecToStack `curl.exe -f -s -S -L -o "$dlFile" "$dlUrl"`
  Pop $0  ; return code
  Pop $1  ; output
  ${If} $0 == 0
    StrCpy $0 "OK"
  ${Else}
    Delete "$dlFile"
    StrCpy $0 "Download error $0: $1"
  ${EndIf}
  Pop $1
  Exch $0
FunctionEnd

;-----------------------------------------------------------------
; setProxy: Function sets HTTPS_PROXY and HTTP_PROXY for this installer, and so for
;           everything it starts (curl, git, pip, A-Z+T), from the Windows proxy
;           settings (including automatic configuration scripts): none of those read
;           the Windows settings themselves.  Proxy variables already set are kept.
;           The elevated copy is given the user's proxy (/PROXY=, see componentsLeave),
;           since it may run as another account, with other settings.
Function setProxy
  Var /GLOBAL proxy
  StrCpy $proxy ""
  ReadEnvStr $0 HTTPS_PROXY
  ${If} $0 != ""
    StrCpy $logstring "Using the HTTPS_PROXY already set: $0"
    Call logMessage
    StrCpy $proxy $0
    Return
  ${EndIf}
  ${If} $adminsteps == "1"
    ${GetParameters} $R0
    ClearErrors
    ${GetOptions} $R0 "/PROXY=" $proxy
    ClearErrors
  ${Else}
    nsExec::ExecToStack `powershell -NoProfile -Command "$$u = [Uri]'https://github.com/'; $$p = [Net.WebRequest]::GetSystemWebProxy().GetProxy($$u); if ($$p.AbsoluteUri -ne $$u.AbsoluteUri) { $$p.AbsoluteUri }"`
    Pop $0
    Pop $1
    ${StrTrimNewLines} $1 $1
    ${If} $0 == 0
      StrCpy $proxy $1
    ${EndIf}
  ${EndIf}
  ${If} $proxy != ""
    System::Call 'Kernel32::SetEnvironmentVariable(t "HTTPS_PROXY", t "$proxy")'
    System::Call 'Kernel32::SetEnvironmentVariable(t "HTTP_PROXY", t "$proxy")'
    StrCpy $logstring "Using the Windows proxy setting: $proxy"
  ${Else}
    StrCpy $logstring "No proxy set in Windows; connecting directly."
  ${EndIf}
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; findPythonMinor: Function sets $pythonExe to the full path of an installed
;                  python $pythonminor (any patch), from the registry entries every
;                  python.org install writes (PEP 514), or to "" if there is none.
;                  Works right after installing, when python isn't on the path yet.
Function findPythonMinor
  StrCpy $pythonExe ""
  SetRegView 64
  ReadRegStr $pythonExe HKCU "Software\Python\PythonCore\$pythonminor\InstallPath" "ExecutablePath"
  ${If} $pythonExe == ""
    ReadRegStr $pythonExe HKLM "Software\Python\PythonCore\$pythonminor\InstallPath" "ExecutablePath"
  ${EndIf}
  SetRegView lastused
  ClearErrors
  ${If} $pythonExe != ""
  ${AndIfNot} ${FileExists} "$pythonExe"
    StrCpy $pythonExe ""
  ${EndIf}
  StrCpy $logstring "Python $pythonminor from registry: <$pythonExe>"
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; resolvePythonVersion: Function sets $pythonversion, $pythonfilename and $pythonurl
;     to the newest python $pythonminor release with a 64-bit Windows installer.
;     A minor that gets security fixes only has no installer for its latest release;
;     then, if PYTHONMINORS allows, the next minor up is tried (and $pythonminor
;     changed to it).  If none has
;     an installer, walk back down the first minor's releases to the newest that has
;     one.  Offline, use a python $pythonminor installer already beside this one.
;     $pythonversion is "" if nothing is found.
Function resolvePythonVersion
  Var /GLOBAL firstMinor
  Var /GLOBAL firstLatest
  Var /GLOBAL latestVersion
  StrCpy $firstMinor $pythonminor
  StrCpy $firstLatest ""

  ${For} $R5 1 ${PYTHONMINORS}
    Call readLatestPythonPage
    ${If} $R5 == 1
      StrCpy $firstLatest $latestVersion
    ${EndIf}
    ${If} $pythonversion != ""
    ${OrIf} $latestVersion == ""  ; no such release (or offline)
    ${OrIf} $R5 == ${PYTHONMINORS}
      ${Break}
    ${EndIf}
    ; Security fixes only: try the next minor up
    StrCpy $R0 $pythonminor 2     ; major and dot, e.g. "3."
    StrCpy $R1 $pythonminor "" 2  ; minor number, e.g. "13"
    IntOp $R1 $R1 + 1
    StrCpy $pythonminor "$R0$R1"
    StrCpy $logstring "No Windows installer for python $latestVersion; trying python $pythonminor"
    Call logMessage
  ${Next}

  ${If} $pythonversion == ""
    StrCpy $pythonminor $firstMinor
  ${EndIf}

  ; Walk back down the patches of the first minor
  ${If} $pythonversion == ""
  ${AndIf} $firstLatest != ""
    StrLen $R0 "$pythonminor."
    StrCpy $R1 $firstLatest "" $R0  ; patch number
    ${DoWhile} $R1 >= 0
      StrCpy $R2 "$pythonminor.$R1"
      ; HEAD request only; -f makes a missing file an error
      nsExec::ExecToStack `curl.exe -f -s -I -L -o NUL "https://www.python.org/ftp/python/$R2/python-$R2-amd64.exe"`
      Pop $R3
      Pop $R4
      StrCpy $logstring "python-$R2-amd64.exe on python.org: curl RC = $R3"
      Call logMessage
      ${If} $R3 == "0"
        StrCpy $pythonversion $R2
        ${Break}
      ${EndIf}
      IntOp $R1 $R1 - 1
    ${Loop}
  ${EndIf}

  ; Offline: an installer already beside this one, e.g. python-3.13.15-amd64.exe
  ${If} $pythonversion == ""
    FindFirst $R0 $R1 "python-$pythonminor.*-amd64.exe"
    FindClose $R0
    ClearErrors
    ${If} $R1 != ""
      StrCpy $pythonversion $R1 -10 7  ; strip "python-" and "-amd64.exe"
      StrCpy $logstring "Using python installer found beside this one: $R1"
      Call logMessage
    ${EndIf}
  ${EndIf}

  ${If} $pythonversion != ""
    StrCpy $pythonfilename "python-$pythonversion-amd64.exe"
    StrCpy $pythonurl "https://www.python.org/ftp/python/$pythonversion/$pythonfilename"
    StrCpy $logstring "Python release to install: $pythonversion"
    Call logMessage
  ${EndIf}
FunctionEnd

;-----------------------------------------------------------------
; readLatestPythonPage: Function reads python.org's latest-release page for $pythonminor.
;     Sets $latestVersion to the release it is for ("" if none, or offline), and
;     $pythonversion to the same only if the page links its 64-bit Windows installer.
Function readLatestPythonPage
  StrCpy $latestVersion ""
  StrCpy $pythonversion ""
  Delete "python_latest.html"
  ${Download} "https://www.python.org/downloads/latest/python$pythonminor/" "python_latest.html"
  Pop $R0
  StrCpy $logstring "python.org latest python$pythonminor page: $R0"
  Call logMessage
  ${If} $R0 != "OK"
    Return
  ${EndIf}

  FileOpen $R1 "python_latest.html" r
  ${Do}
    ClearErrors
    FileRead $R1 $R2
    ${If} ${Errors}
      ${Break}
    ${EndIf}
    ; Title is "Python Release Python 3.13.15 | Python.org"
    ${If} $latestVersion == ""
      ${StrStr} $R3 $R2 "Release Python $pythonminor."
      ${If} $R3 != ""
        StrCpy $R3 $R3 "" 15  ; strip "Release Python "
        ${StrLoc} $R4 $R3 " " ">"
        StrCpy $latestVersion $R3 $R4
      ${EndIf}
    ${EndIf}
    ${If} $latestVersion != ""
      ${StrStr} $R3 $R2 "/python-$latestVersion-amd64.exe"
      ${If} $R3 != ""
        StrCpy $pythonversion $latestVersion
        ${Break}
      ${EndIf}
    ${EndIf}
  ${Loop}
  FileClose $R1
  ClearErrors
  StrCpy $logstring "Latest python $pythonminor release: <$latestVersion>; with Windows installer: <$pythonversion>"
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; resolveCharisVersion: Function asks GitHub for the latest Charis release and, if it
;     answers, sets $charisversion, $charisfilename, $chariszipfile and $charisurl for it.
;     Otherwise they keep the values set in .onInit.
Function resolveCharisVersion
  StrCpy $tagUrl "https://api.github.com/repos/silnrsi/font-charis/releases/latest"
  Call readLatestTag
  ${If} $latestTag != ""
    StrCpy $charisversion $latestTag
    StrCpy $charisfilename "Charis-$charisversion"
    StrCpy $chariszipfile "$charisfilename.zip"
    StrCpy $charisurl "https://github.com/silnrsi/font-charis/releases/download/v$charisversion/$chariszipfile"
  ${EndIf}
  StrCpy $logstring "Charis release to install: $charisversion from $charisurl"
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; resolveGitVersion: Function asks GitHub for the latest Git for Windows release and, if
;     it answers, sets $gitversion, $gitfilename and $giturl for it.  Otherwise they
;     keep the values set in .onInit.  Tag "2.55.0.windows.5" has the installer
;     Git-2.55.0.5-64-bit.exe; a ".windows.1" tag has Git-2.55.0-64-bit.exe.
Function resolveGitVersion
  StrCpy $tagUrl "https://api.github.com/repos/git-for-windows/git/releases/latest"
  Call readLatestTag
  ${StrStr} $R0 $latestTag ".windows."
  ${If} $R0 != ""
    StrLen $R1 $R0
    StrCpy $R2 $latestTag -$R1  ; "2.55.0"
    StrCpy $R3 $R0 "" 9         ; "5" (after ".windows.")
    StrCpy $gitversion $R2
    ${If} $R3 == "1"
      StrCpy $gitfilename "Git-$R2-64-bit.exe"
    ${Else}
      StrCpy $gitfilename "Git-$R2.$R3-64-bit.exe"
    ${EndIf}
    StrCpy $giturl "https://github.com/git-for-windows/git/releases/download/v$latestTag/$gitfilename"
  ${EndIf}
  StrCpy $logstring "Git release to install: $gitversion from $giturl"
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; resolvePraatVersion: Function asks GitHub for the latest Praat release and, if it
;     answers, sets $praatversion, $praatfilename and $praaturl for it.  Otherwise they
;     keep the values set in .onInit.  Tag "7.0.02" has praat7002_win-x64v1.zip
;     (x64v1 runs on any 64-bit Intel/AMD CPU; x64v3 needs AVX2).
Function resolvePraatVersion
  StrCpy $tagUrl "https://api.github.com/repos/praat/praat.github.io/releases/latest"
  Call readLatestTag
  ${If} $latestTag != ""
    ${StrRep} $praatversion $latestTag "." ""
    StrCpy $praatfilename "praat$praatversion_win-x64v1.zip"
    StrCpy $praaturl "https://github.com/praat/praat.github.io/releases/download/v$latestTag/$praatfilename"
  ${EndIf}
  StrCpy $logstring "Praat release to install: $praatversion from $praaturl"
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; resolveMercurialVersion: Function reads Mercurial's latest.dat and, if it can, sets
;     $hgversion, $hgfilename and $hgurl to its x64 .exe installer.  Otherwise they
;     keep the values set in .onInit.  Each line is tab-separated: priority, version,
;     platform pattern, URL, description.
Function resolveMercurialVersion
  Delete "hg_latest.dat"
  ${Download} "https://www.mercurial-scm.org/release/windows/latest.dat" "hg_latest.dat"
  Pop $R0
  StrCpy $logstring "Mercurial latest.dat: $R0"
  Call logMessage
  ${If} $R0 == "OK"
    FileOpen $R1 "hg_latest.dat" r
    ${Do}
      ClearErrors
      FileRead $R1 $R2
      ${If} ${Errors}
        ${Break}
      ${EndIf}
      ${StrStr} $R3 $R2 "-x64.exe"
      ${StrStr} $R4 $R2 "https://"
      ${If} $R3 != ""
      ${AndIf} $R4 != ""
        ${StrLoc} $R5 $R4 "$\t" ">"
        StrCpy $hgurl $R4 $R5              ; URL up to the next tab
        ${StrStr} $R6 $hgurl "windows/"
        StrCpy $hgfilename $R6 "" 8        ; e.g. Mercurial-7.1.2-x64.exe
        StrCpy $hgversion $hgfilename -8 10  ; strip "Mercurial-" and "-x64.exe"
        ${Break}
      ${EndIf}
    ${Loop}
    FileClose $R1
    ClearErrors
  ${EndIf}
  StrCpy $logstring "Mercurial release to install: $hgversion from $hgurl"
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; resolveXLingPaperVersion: Function asks GitHub for the latest XLingPaper release and,
;     if it answers, sets $xlpversion, $xlpfilename and $xlpurl for it.  Otherwise they
;     keep the values set in .onInit.  Tag "3.19.3" has the full Windows installer
;     XLingPaper3.19.3.0XXEPersonalEditionFullSetup.exe.
Function resolveXLingPaperVersion
  StrCpy $tagUrl "https://api.github.com/repos/sillsdev/XLingPap/releases/latest"
  Call readLatestTag
  ${If} $latestTag != ""
    StrCpy $xlpversion $latestTag
    StrCpy $xlpfilename "XLingPaper$xlpversion.0XXEPersonalEditionFullSetup.exe"
    StrCpy $xlpurl "https://github.com/sillsdev/XLingPap/releases/download/v$latestTag/$xlpfilename"
  ${EndIf}
  StrCpy $logstring "XLingPaper release to install: $xlpversion from $xlpurl"
  Call logMessage
FunctionEnd

;-----------------------------------------------------------------
; readLatestTag: Function downloads GitHub's latest-release JSON from $tagUrl and sets
;     $latestTag to its tag_name without the leading "v" ("" if none, or offline).
Function readLatestTag
  StrCpy $latestTag ""
  Delete "latest_release.json"
  ${Download} "$tagUrl" "latest_release.json"
  Pop $R0
  StrCpy $logstring "GitHub latest release $tagUrl: $R0"
  Call logMessage
  ${If} $R0 != "OK"
    Return
  ${EndIf}

  ; Find "tag_name": "v7.000".  The JSON may be one line longer than an NSIS string,
  ; so read it in pieces, each searched together with the end of the one before.
  StrCpy $R5 ""  ; tag found
  StrCpy $R6 ""  ; end of the previous piece
  FileOpen $R1 "latest_release.json" r
  ${Do}
    ClearErrors
    FileRead $R1 $R2 512
    ${If} ${Errors}
      ${Break}
    ${EndIf}
    StrCpy $R2 "$R6$R2"
    StrCpy $R6 $R2 "" -128
    ${StrStr} $R3 $R2 '"tag_name"'
    ${If} $R3 != ""
      StrCpy $R3 $R3 "" 10  ; strip '"tag_name"'
      ${StrStr} $R3 $R3 '"v'
      ${If} $R3 != ""
        StrCpy $R3 $R3 "" 2  ; strip '"v'
        ${StrLoc} $R4 $R3 '"' ">"
        ${If} $R4 != ""
          StrCpy $R5 $R3 $R4
          ${Break}
        ${EndIf}
      ${EndIf}
    ${EndIf}
  ${Loop}
  FileClose $R1
  ClearErrors

  StrCpy $latestTag $R5
FunctionEnd

;-----------------------------------------------------------------
; getGitPath: Function searches for git executable.
;             If not found, runs a separate windows shell 
;             to pull the path from the environment variable
Function getGitPath

StrCpy $logstring "Running git --version to see if it is reachable."
Call logMessage

ExecWait 'cmd /C git --version >git_version.txt' $0
StrCpy $logstring "Git --version return code: $0"
Call logMessage
;To force the logic below for testing: IntOp $0 1 - 0
${If} $0 != 0

  ; If git was just installed, it will not be in the current environment yet, so 
  ; we have to find it in a roundabout way, by executing a second shell 
  ; with runas running at user level.  This seems to cause the shell to pick up the new path.
  ; Use the "where" command to find the path.

  StrCpy $logstring "git not found. Trying to find the path using windows shell..."
  Call logMessage

  StrCpy $cmdFile "getgitpath.cmd"
  StrCpy $pathFile "gitpath.txt"
  Delete $pathFile
  ClearErrors
  FileOpen $R9 $cmdFile w
  FileWrite $R9 "@echo off${NEWLINE}"
  FileWrite $R9 "setlocal enabledelayedexpansion${NEWLINE}"

  FileWrite $R9 "REM Use PowerShell to retrieve the full PATH from the registry and set it in the current session${NEWLINE}"
  FileWrite $R9 "for /f $\"delims=$\" %%A in ('powershell -command $\"Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name Path | Select-Object -ExpandProperty Path$\"') do (${NEWLINE}"
  FileWrite $R9 "    set $\"SystemPath=%%A$\"${NEWLINE}"
  FileWrite $R9 ")${NEWLINE}"

  FileWrite $R9 "for /f $\"delims=$\" %%B in ('powershell -command $\"Get-ItemProperty -Path 'HKCU:\Environment' -Name Path | Select-Object -ExpandProperty Path$\"') do (${NEWLINE}"
  FileWrite $R9 "    set $\"UserPath=%%B$\"${NEWLINE}"
  FileWrite $R9 ")${NEWLINE}"
  FileWrite $R9 "REM Output the full PATH value for verification${NEWLINE}"
  FileWrite $R9 "echo Full System PATH: %SystemPath%\%UserPath%${NEWLINE}"
  FileWrite $R9 "REM Update the current session's PATH with both system and user paths to find Git${NEWLINE}"
  FileWrite $R9 "Call set PATH=%SystemPath%;%UserPath%${NEWLINE}"
  FileWrite $R9 "where git 1>$\"$OUTDIR\$pathFile$\"${NEWLINE}"
  FileWrite $R9 "echo >NUL${NEWLINE}"   ; Force closed filehandle so we can read it quickly
  FileWrite $R9 "endlocal${NEWLINE}"
  FileWrite $R9 "exit /B${NEWLINE}"

  FileClose $R9 

  ClearErrors

  ; Get path to windows command line exe
  ReadEnvStr $R0 COMSPEC
  StrCpy $logstring 'powershell Start-Process -FilePath "$R0"-ArgumentList /C,"$OUTDIR\$cmdFile"'
  Call logMessage 

  ; Set timeout to give the powershell command time to complete before attempting to read the path file (in milliseconds)
  nsExec::ExecToStack /TIMEOUT=${WAITTIME} 'powershell Start-Process -FilePath "$R0" -ArgumentList /C,"$OUTDIR\$cmdFile"'
  Pop $0 ;return value is first on stack
  ${If} $0 != 0
    Pop $1 ;get error message
    StrCpy $logstring "Powershell results: $0 $1"
    Call logMessage
  
  ${Else}
          
    ${For} $R1 1 5
      ; Open the path file.  If it fails, wait a few seconds and retry a few times before aborting.
      ClearErrors
      FileOpen $R9 "$OUTDIR\$pathFile" r
      ifErrors sleepLoop3

      StrCpy $logstring "Reading $pathFile..."
      Call logMessage
      ${Break}

      sleepLoop3:
      StrCpy $logstring "Error opening $pathFile.  Waiting ${WAITTIME} milliseconds and retrying, to make sure windows closed it..."
      Call logMessage      
      Sleep ${WAITTIME}  ; Wait for some seconds to ensure the file is written    
    ${Next}

    ifErrors 0 gitFileOK
      StrCpy $logstring "Unable to read $pathFile. Terminating installer."
      Call logMessage
      MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
      Abort

    gitFileOK:
      ; Read the first line of the path file created by the script
      FileRead $R9 $R7
      FileClose $R9
      
      ${StrTrimNewLines} $gitPath $R7
      ${If} $gitPath == ""
        StrCpy $logstring "gitPath is empty, waiting ${WAITTIME} milliseconds and trying again..."
        Call logMessage
        ${For} $R1 1 5
          ; Open and read the path file.  If it fails, wait a few seconds and retry a few times
          Sleep ${WAITTIME}
          
          ClearErrors
          FileOpen $R9 "$OUTDIR\$pathFile" r
          ifErrors sleepLoop4

          StrCpy $logstring "Reading $pathFile..."
          Call logMessage
          FileRead $R9 $R7
          FileClose $R9
          
          ${StrTrimNewLines} $gitPath $R7
          ${If} $gitPath == "" 
            StrCpy $logstring "gitPath is empty, waiting ${WAITTIME} milliseconds and retrying..."
            Call logMessage
            goto nextLoopGit
          ${EndIf}

          sleepLoop4:
          StrCpy $logstring "Error opening $pathFile.  Waiting ${WAITTIME} milliseconds and retrying..."
          Call logMessage     

          nextLoopGit:
        ${Next}

        ifErrors 0 gitFileOK2
          StrCpy $logstring "Unable to read $pathFile. Terminating installer."
          Call logMessage
          MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
          Abort

        gitFileOK2:
        ${If} $gitPath == "" 
            StrCpy $logstring "gitPath is empty.  Unable to continue with installation."
            Call logMessage
            Abort
        ${EndIf}

      ${EndIf}

      StrCpy $logstring "git path: $gitPath"
      Call logMessage

      StrCpy $gitExe "$gitPath"
    
  ${EndIf}

${Else}
  ; if it can be found directly, no need to use whole path
  StrCpy $gitExe "git"
${EndIf}
  
  ClearErrors
  StrCpy $logstring "Git Path: $gitExe"
  Call logMessage 
FunctionEnd

;-----------------------------------------------------------------
; skipComponentsIfAdmin: the elevated copy was already told what to install
Function skipComponentsIfAdmin
  ${If} $adminsteps == "1"
    Abort
  ${EndIf}
FunctionEnd

;-----------------------------------------------------------------
; componentsLeave: machine-wide sections run in the elevated copy (runAdminSteps),
;                  so pass it the optional ones selected, and don't run them here
Function componentsLeave
  StrCpy $adminArgs ""
  ${If} ${SectionIsSelected} ${xlpId}
    StrCpy $adminArgs "$adminArgs /XLP"
  ${EndIf}
  ${If} ${SectionIsSelected} ${praatId}
    StrCpy $adminArgs "$adminArgs /PRAAT"
  ${EndIf}
  ${If} ${SectionIsSelected} ${mercurialId}
    StrCpy $adminArgs "$adminArgs /HG"
  ${EndIf}
  ${If} $proxy != ""
    StrCpy $adminArgs "$adminArgs /PROXY=$proxy"
  ${EndIf}
  SectionSetFlags ${charisId} 0
  SectionSetFlags ${xlpId} 0
  SectionSetFlags ${praatId} 0
  SectionSetFlags ${mercurialId} 0
FunctionEnd

;-----------------------------------------------------------------
; runAdminSteps: Function runs this installer again, elevated, with /ADMINSTEPS,
;                to do only the machine-wide steps (Git, Charis, LongPathsEnabled,
;                and the optional programs selected).  Everything per-user (python,
;                A-Z+T, its modules, shortcuts) stays in this, the user's, process,
;                so it goes to the right user even if another account gives admin rights.
Function runAdminSteps
  StrCpy $logstring "Running machine-wide steps as administrator: $EXEPATH /ADMINSTEPS$adminArgs"
  Call logMessage
  Delete "$EXEDIR\${INSTALLERNAME}_admin_warnings.txt"
  ClearErrors
  ExecShellWait "runas" "$EXEPATH" "/ADMINSTEPS$adminArgs"
  ${If} ${Errors}
    StrCpy $logstring "Administrator steps did not run (permission not given?).  Installation aborted."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
    Abort
  ${EndIf}
  StrCpy $logstring "Machine-wide steps finished; details are in ${INSTALLERNAME}_admin.log"
  Call logMessage

  ; Problems the elevated copy reported (it closes itself, so it can't show them)
  ClearErrors
  FileOpen $0 "$EXEDIR\${INSTALLERNAME}_admin_warnings.txt" r
  ${IfNot} ${Errors}
    ${Do}
      FileRead $0 $1
      ${If} ${Errors}
        ${Break}
      ${EndIf}
      StrCpy $warnings "$warnings$1"
    ${Loop}
    FileClose $0
    StrCpy $logstring "Problems in the machine-wide steps:${NEWLINE}$warnings"
    Call logMessage
  ${EndIf}
  ClearErrors
FunctionEnd

;-----------------------------------------------------------------
; writeAdminWarnings: Function, in the elevated copy, hands $warnings to the user's
;                     installer (read back in runAdminSteps)
Function writeAdminWarnings
  ${If} $warnings != ""
    FileOpen $0 "$EXEDIR\${INSTALLERNAME}_admin_warnings.txt" w
    FileWrite $0 $warnings
    FileClose $0
  ${EndIf}
FunctionEnd

;-----------------------------------------------------------------
; .onInstSuccess - Executes at the end of a successful installation
Function .onInstSuccess
    ${If} $adminsteps == "1"
      ; Elevated copy: the user's installer continues from here
      StrCpy $logstring "Machine-wide steps completed."
      Call logMessage
      Call writeAdminWarnings
      FileClose $log0
      Return
    ${EndIf}
    ; (The summary and the launch are on the finish page: see finishPre and launchAZT)

    ; File cleanup
    Delete "git_error.log"
    Delete "charis_error.log"
    Delete "praat_error.log"
    Delete "getgitpath.cmd"
    Delete "gitpath.txt"
    Delete "getpythonpath.cmd"
    Delete "pythonpath.txt"
    Delete "python_latest.html"
    Delete "python_head.txt"
    Delete "latest_release.json"
    Delete "hg_latest.dat"
    Delete "git_version.txt"
    Delete "python_version.txt"
    Delete "$EXEDIR\${INSTALLERNAME}_admin_warnings.txt"
    
    ClearErrors
    FileClose $log0   ; close the installation log file
FunctionEnd

;-----------------------------------------------------------------
; finishPre: Function sets the finish page text, and first lists any problems.
;            The elevated copy has no finish page (it closes itself).
Function finishPre
  ${If} $adminsteps == "1"
    Abort
  ${EndIf}
  ${If} $warnings != ""
    StrCpy $logstring "A-Z+T is installed, but with these problems:${NEWLINE}${NEWLINE}$warnings${NEWLINE}Details are in $EXEDIR\$logfile."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring
    StrCpy $finishText "${APPNAME} is installed in $INSTDIR, but with problems; they are listed in $EXEDIR\$logfile.${NEWLINE}${NEWLINE}Click Finish to close this installer."
  ${Else}
    StrCpy $logstring "Installation completed successfully."
    Call logMessage
    StrCpy $finishText "${APPNAME} is installed in $INSTDIR.${NEWLINE}${NEWLINE}Click Finish to close this installer."
  ${EndIf}
FunctionEnd

;-----------------------------------------------------------------
; launchAZT: Function runs A-Z+T, if its box on the finish page is left checked.
;            Its first run finishes its own setup (and retries anything that failed).
Function launchAZT
  StrCpy $logstring  "ExecShell open $pythonExe $aztfilename SW_SHOW"
  Call logMessage
  ExecShell "open" "$pythonExe" "$\"$aztfilename$\"" SW_SHOW
FunctionEnd

;-----------------------------------------------------------------
;.onInstFailed - Executes at the end of an installation abort
;                Do not delete temporary files in case they are needed for troubleshooting
Function .onInstFailed
  StrCpy $logstring  "${APPNAME} installation aborted."
  Call logMessage
  ${If} $adminsteps == "1"
    StrCpy $warnings "- Machine-wide steps were aborted (see ${INSTALLERNAME}_admin.log).${NEWLINE}$warnings"
    Call writeAdminWarnings
  ${EndIf}
  FileClose $log0   ; close the installation log file
  MessageBox MB_YESNO "${APPNAME} installation aborted.  View log file?" IDNO NoReadme
      Exec "notepad.exe $logfile"
  NoReadme:
FunctionEnd

;-----------------------------------------------------------------
; .onInit is executed automatically when the installer is started
;     Use it to initialize features and variables
Function .onInit

  ; /ADMINSTEPS marks the elevated copy started by runAdminSteps
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/ADMINSTEPS" $R1
  ${IfNot} ${Errors}
    StrCpy $adminsteps "1"
  ${EndIf}

  # Define paths

  ; Only the python minor is named here; the release is found at install time
  ; (see resolvePythonVersion)
  StrCpy $pythonminor "3.13"

  ; Used only if GitHub can't be asked for the latest release (see resolveGitVersion)
  StrCpy $gitversion "2.51.2"
  StrCpy $gitfilename "Git-$gitversion-64-bit.exe"
  StrCpy $gitsize "^(68.1 MB; 68,131,584 bytes^)"
  StrCpy $giturl "https://github.com/git-for-windows/git/releases/download/v$gitversion.windows.1/$gitfilename"

  StrCpy $aztRepoName "azt.git"
  StrCpy $aztRepoURL "https://github.com/kent-rasmussen/azt.git"
  ; Existing desktop installs are updated in place; new installs go to InstallDir
  ${If} ${FileExists} "$DESKTOP\azt\main.py"
    StrCpy $INSTDIR "$DESKTOP\azt"
  ${EndIf}
  StrCpy $aztfilename "$INSTDIR\main.py"

  ; Used only if GitHub can't be asked for the latest release (see resolvePraatVersion)
  StrCpy $praatversion "7002"
  StrCpy $praatfilename "praat$praatversion_win-x64v1.zip"
  StrCpy $praaturl "https://github.com/praat/praat.github.io/releases/download/v7.0.02/$praatfilename"

  ; Used only if GitHub can't be asked for the latest release (see resolveXLingPaperVersion)
  StrCpy $xlpversion "3.19.3"
  StrCpy $xlpfilename "XLingPaper$xlpversion.0XXEPersonalEditionFullSetup.exe"
  StrCpy $xlpurl "https://github.com/sillsdev/XLingPap/releases/download/v$xlpversion/$xlpfilename"

  ; Used only if latest.dat can't be read (see resolveMercurialVersion)
  StrCpy $hgversion "7.1.2"
  StrCpy $hgfilename "Mercurial-$hgversion-x64.exe"
  StrCpy $hgurl "https://www.mercurial-scm.org/release/windows/$hgfilename"

  ; Used only if GitHub can't be asked for the latest release (see resolveCharisVersion)
  StrCpy $charisversion "7.000"
  StrCpy $charisfilename "Charis-$charisversion"
  StrCpy $chariszipfile "$charisfilename.zip"
  StrCpy $charisurl "https://software.sil.org/downloads/r/charis/$chariszipfile"
  
  StrCpy $filepath $EXEDIR  
  ; Destination directory for temporary installation files (OUTDIR)
  SetOutPath $filepath

  ; Set output installation log file name. (Ref: logMessage function)
  StrCpy $logfile "${INSTALLERNAME}.log"
  ${If} $adminsteps == "1"
    StrCpy $logfile "${INSTALLERNAME}_admin.log"
  ${EndIf}
  FileOpen $log0 $logfile w
  ifErrors 0 continue_init
    StrCpy $logstring "Unable to open the installation log file.  Make sure you have write access to the installation directory: $EXEDIR"
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
    Abort

  continue_init:
  StrCpy $filename $EXEFILE
  StrCpy $logstring  "Installer is $filepath\$filename"  
  Call logMessage 

  StrCpy $0 $DESKTOP
  StrCpy $logstring "DESKTOP is $DESKTOP"
  Call logMessage

  Call setProxy

  # set sections as selected and read-only
  IntOp $0 ${SF_SELECTED} | ${SF_RO}  
  SectionSetFlags ${pythonId} $0
  SectionSetFlags ${gitId} $0
  SectionSetFlags ${aztId} $0
  SectionSetFlags ${charisId} $0

  ${If} $adminsteps == "1"
    ; Elevated copy: machine-wide sections only, optional ones as passed by runAdminSteps
    SectionSetFlags ${pythonId} 0
    SectionSetFlags ${aztId} 0
    ${GetParameters} $R0
    ClearErrors
    ${GetOptions} $R0 "/XLP" $R1
    ${If} ${Errors}
      SectionSetFlags ${xlpId} 0
    ${EndIf}
    ClearErrors
    ${GetOptions} $R0 "/PRAAT" $R1
    ${If} ${Errors}
      SectionSetFlags ${praatId} 0
    ${EndIf}
    ClearErrors
    ${GetOptions} $R0 "/HG" $R1
    ${If} ${Errors}
      SectionSetFlags ${mercurialId} 0
    ${EndIf}
  ${Else}
    SectionSetFlags ${longPathsId} 0
  ${EndIf}

  ; Check if the installer is running with admin rights
  StrCpy $logstring "-----  Starting Installation ----- ${NEWLINE}Installing from $filepath"
  Call logMessage

  ; Only the elevated copy needs admin rights
  ${If} $adminsteps != "1"
    StrCpy $withadmin "0"
    Return
  ${EndIf}

  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}"  "Test / Set Admin Mode..."
  StrCpy $logstring "${NEWLINE}-----  Test / Set Admin Mode ----- "
  Call logMessage
  UserInfo::GetAccountType
  Pop $0
  ${If} $0 == 'Admin'
    StrCpy $logstring 'Installer running in admin mode'
    ;MessageBox MB_OK $logstring
    Call logMessage
    StrCpy $withadmin "1"
  ${Else}
    ; StrCpy $logstring "Installer is not able to run with admin rights, installing for current user only: $0"
    StrCpy $logstring "Installer must be run as Administrator."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
    StrCpy $withadmin "0"
    Abort
  ${EndIf}  

FunctionEnd
