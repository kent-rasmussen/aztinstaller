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

; Macro and Function for ${Locate} to find folders from FileFunc
  !insertmacro Locate

; Show all the DetailsPrint to the user while installation is in progress
  ShowInstDetails show

;--------------------------------
; Constants

  !define NEWLINE "$\r$\n"
  !define TITLENAME "A-Z+T Installer"
  !define APPNAME "A-Z+T"
  !define INSTALLERNAME "AZT_Installer"  ; original name

;--------------------------------
; Global variables

  Var /GLOBAL pythonversion
  Var /GLOBAL pythonfilename
  Var /GLOBAL pythonsize
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
  var /GLOBAL aztfilename
  var /GLOBAL transcriberfilename

  ; Use 0 for current user and 1 for admin user
  Var /GLOBAL withadmin
  var /GLOBAL logfile
  Var /GLOBAL log0
  var /GLOBAL logstring
  Var /GLOBAL found
  Var /GLOBAL downloadName
  Var /GLOBAL ReturnError
  Var /GLOBAL tempLogFile
  Var /GLOBAL windowsAZTFile
  



;------------------------------------------------------------------------------
;General
;------------------------------------------------------------------------------

  ;Name and file
  Name ${APPNAME}
  OutFile "${INSTALLERNAME}.exe"
  Unicode True

  ;Request application privileges for Windows 
  RequestExecutionLevel admin
  
  ;Default installation folder  (sets INSTDIR)
  InstallDir "$DESKTOP\azt"

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
  !insertmacro MUI_PAGE_COMPONENTS
  
  ; Enable MUI_PAGE_DIRECTORY to permit user to change the installationi target directory
  ;!insertmacro MUI_PAGE_DIRECTORY
  
  !insertmacro MUI_PAGE_INSTFILES
  
  ; FINISHPAGE macros are used to display a successful completion page with a "Launch Application" option
  ; Disabling for now since we are launching the page conditionally in .onInstSuccess
  ; !define MUI_FINISHPAGE_RUN "cmd /c python $INSTDIR\main.py"
  ; !define MUI_FINISHPAGE_RUN_TEXT "Launch A-Z+T now ($INSTDIR\main.py)"
  ;!define MUI_FINISHPAGE_TEXT "${APPNAME} finished installing at${NEWLINE}${NEWLINE}$aztfilename.${NEWLINE}${NEWLINE}Click Finish to close setup."
  ;!insertmacro MUI_PAGE_FINISH

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

  ; Check if Python Installer file was already downloaded previously
  FindFirst $0 $1 "$pythonfilename"
  StrCpy $logstring "Python file search: $0 $1"
  Call logMessage
  FindClose $0

  ${If} $1 == $pythonfilename
    
    StrCpy $logstring "$pythonfilename already exists, using this version."
    Call logMessage

  ${Else}

    # Download Python Installer file
    StrCpy $logstring "Downloading Python from $pythonurl"
    Call logMessage

    inetc::get "$pythonurl" "$pythonfilename" /end
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
      StrCpy $logstring "Python is already installed, skipping installation."
      Call logMessage
    ${Else}
      StrCpy $logstring "ERROR: Python $pythonversion Installation failed with return code: $0" 
      Call logMessage
      Abort
    ${EndIf}    
  ${Else}

    StrCpy $logstring "Python installed successfully."
    Call logMessage
  ${EndIf}
  

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
  ifErrors errorExitLongPaths pythonEnd
  
errorExitLongPaths:
  ClearErrors
  StrCpy $logstring "ERROR: Error setting Registry LongPathsEnabled"
  Call logMessage
  ; Does this need to abort or can it continue?
  ;MessageBox MB_OK $logstring
  ;Abort
${EndIf}  

;--------------------------------
pythonEnd:
  call getPythonPath
  StrCpy $logstring "Using Python path: $pythonExe"
SectionEnd

;***************************************************************************************
Section "Git" gitId

  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing Git..."
  StrCpy $logstring "${NEWLINE}-----  Git Installer ----- "
  Call logMessage

  StrCpy $downloadName "Git"  

  ; Check if desired or later Git is already installed
  Call checkGitVersion  
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

    inetc::get "$giturl" "$gitfilename" /end
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "ERROR: $0.  Unable to download $downloadName. Installation aborted."
      MessageBox MB_OK|MB_ICONEXCLAMATION $logstring /SD IDOK
      Call logMessage
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
      Abort
    ${EndIf}    
  ${Else}
    StrCpy $logstring "$downloadName installed successfully."
    Call logMessage 
  ${EndIf}
  
;--------------------------------
gitEnd: 

  call getGitPath
  StrCpy $logstring "Using Git path: $gitExe"

SectionEnd


;***************************************************************************************
Section "AZT" aztId

  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing AZT from Git repository..."
  StrCpy $logstring "${NEWLINE}-----  AZT Installer ----- "
  Call logMessage    
  
  ; Initialize variables and constants
  !define REPO_NAME "azt.git"
  !define REPO_URL "https://github.com/kent-rasmussen/azt.git"
  StrCpy $azt ""

  ; Show a message that we're starting to look for the repo
  StrCpy $logstring "Looking for a USB with the ${REPO_NAME} on it"
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

        StrCpy $R3 "$3\*${REPO_NAME}"
        FindFirst $R4 $R5 "$R3"
        StrCpy $logstring "$R3 file search: $R4 $R5"
        Call logMessage
        FindClose $R4
        ${If} $1 == ${REPO_NAME}
          StrCpy $logstring "found repo in $R3"          
          Call logMessage
          StrCpy $azt "$R3"
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
  StrCpy $azt ${REPO_URL}
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
; Set the safe.directory in both --system and --global, using both "\" and "/" paths to be safe
; Developer Notes:  To validate in a windows command prompt, use:
;                     git config --system --get-all safe.directory
;                   To clear them: 
;                     git config --system --unset-all safe.directory
StrCpy $logstring "Executing $\"$gitExe$\" config --system --add safe.directory $INSTDIR ..."
Call logMessage

; Define the path to the log file
StrCpy $tempLogFile "git_error.log"
${If} $gitExe == ""  ; Should have been set during git install, else assume path is in env.
  StrCpy $logstring "gitExe variable is not set - using 'git'"
  StrCpy $gitExe "git"
${EndIf}

ExecWait 'cmd /C $\"$gitExe$\" config --system --add safe.directory $INSTDIR 2>$tempLogFile' $0
StrCpy $logstring "   Return value: $0"
Call logMessage
ifErrors errorExitAzt

StrCpy $logstring "Executing git config --system --add safe.directory $newPathString ..."
Call logMessage
ExecWait 'cmd /C $\"$gitExe$\" config --system --add safe.directory $newPathString >$tempLogFile' $0
StrCpy $logstring "   Return value: $0"
Call logMessage
ifErrors errorExitAzt

StrCpy $logstring "Executing git config --global --add safe.directory $INSTDIR ..."
ExecWait 'cmd /C $\"$gitExe$\" config --global --add safe.directory $INSTDIR >$tempLogFile' $0
StrCpy $logstring "   Return value: $0"
Call logMessage
ifErrors errorExitAzt

StrCpy $logstring "Executing git config --global --add safe.directory $newPathString ..."
ExecWait 'cmd /C $\"$gitExe$\" config --global --add safe.directory $newPathString >$tempLogFile' $0
StrCpy $logstring "   Return value: $0"
Call logMessage
ifErrors errorExitAzt

StrCpy $logstring "Executing $\"$gitExe$\" clone $azt $INSTDIR"
Call logMessage
ClearErrors

; Use ExecToStack instead of ExecWait to prevent the windows command prompt from showing
; The problem is on first install, this won't find git, 
; so we have to search for the full path to feed to the command line
nsExec::ExecToStack 'cmd /C "$\"$gitExe$\"" clone $azt $INSTDIR 2>$tempLogFile'
Pop $0
StrCpy $logstring "   Return value: $0"
Call logMessage
${If} $0 != 0

  ; Read the error log file content into a variable
  FileOpen $0 $tempLogFile r
  FileRead $0 $ReturnError
  FileClose $0

  ; If the error says repo already exists, just update it.  
  StrCpy $logstring "ERROR: Git clone error:  $ReturnError"
  Call logMessage

  ${StrStr} $2 $ReturnError "exists and is not an empty directory"
  ${If} $2 != "" 
    StrCpy $logstring "AZT Repo already exists, updating..."
    Call logMessage  
    Call gitPullAZT
  ${Else}
    ; Display the error message
    StrCpy $logstring "There was an error getting the repository:${NEWLINE}${NEWLINE}$ReturnError${NEWLINE}${NEWLINE}Make sure your internet (or USB repository) is connected."
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring
    Abort
  ${EndIf}
${EndIf}

 
  ;----------------------------------------------------------------  
  ; Successful install of AZT, set up shortcuts
  ;
  StrCpy $logstring  "Creating shortcut to AZT..."
  Call logMessage
  ; Create Shortcut
  StrCpy $0 "$DESKTOP\A-Z+T.lnk"   ; The shortcut name
  StrCpy $1 "$DESKTOP\azt\main.py" ; The target file
  StrCpy $logstring "Executable : $EXEDIR\$EXEFILE"
  Call logMessage
  StrCpy $2 "$EXEDIR\$EXEFILE"     ; icon file is embedded in installer executable
    
  ; Create application shortcut (switch to installation dir to have the correct "start in" target)
  SetOutPath "$INSTDIR"
  CreateShortcut "$0" "$1" "" "$2" 0
  ; Check for errors 
  IfErrors 0 +3
  StrCpy $logstring "ERROR: Failed to create shortcut for AZT."
  Call logMessage

  SetOutPath "$EXEDIR"

  StrCpy $logstring  "Creating shortcut to Transcriber tool..."
  Call logMessage
  StrCpy $0 "$DESKTOP\Transcriber.lnk"   ; The shortcut name
  StrCpy $1 "$transcriberfilename" ; The target file  
  StrCpy $2 "$EXEDIR\Transcribe-Tone.ico"  ; icon file is embedded in installer executable
  ; Create application shortcut (first in installation dir to have the correct "start in" target)
  SetOutPath "$INSTDIR"
  CreateShortcut "$0" "$1" "" "$2" 0
  ; Check for errors 
  IfErrors 0 +3
  StrCpy $logstring "ERROR: Failed to create shortcut for Transcriber."
  Call logMessage
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
  MessageBox MB_OK|MB_ICONEXCLAMATION $logstring
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

    inetc::get "$charisurl" "$chariszipfile" /end
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "$0.  Error downloading $downloadName. Skipping Charis installation."
      Call logMessage
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
    Call logMessage
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
    
    # Remove 'CharisSIL-' from NOEXT to get FACE
    ${If} $NOEXT != ""
        ${StrRep} $FACE $NOEXT "CharisSIL-" ""
    ${EndIf}
    
    # Replace 'BoldItalic' with 'Bold Italic' in FACE to get FACEMOD
    StrCpy $FACEMOD $FACE
    ${StrRep} $FACEMOD $FACEMOD "BoldItalic" "Bold Italic"
    
    StrCpy $logstring "Installing $TTFFileName as $FACEMOD"
    Call logMessage
    
    # Write to the registry
    WriteRegStr HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "Charis SIL $FACEMOD (TrueType)" "$TTFFileName"
    ifErrors 0 continueCharis2
    StrCpy $logstring "Error writing updating registry for font: $FACEMOD"
    Call logMessage
    goto errorExitCharis

continueCharis2:
    ; Validate and write to log
    ; To validate directly, copy and paste this into windows prompt:
    ; reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" /v "Charis SIL*"
    ReadRegStr $R9 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" "Charis SIL $FACEMOD (TrueType)"
    StrCpy $logstring "Registry read for $FACEMOD: $R9"
    Call logMessage
  
  # Loop to the next file
  FindNext $0 $1
  ${Loop}

  ; Notify windows about the font updates
  SendMessage ${HWND_BROADCAST} ${WM_FONTCHANGE} 0 0 /TIMEOUT=5000
  FindClose $0  
  goto charisEnd

errorExitCharis:
  ClearErrors
  StrCpy $logstring "Error installing Charis SIL Fonts - they may already be installed."
  Call logMessage
  
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
  ; Variables to hold search results
  StrCpy $R0 "XLingPaper"

  StrCpy $R1 ""  ; This will hold the result
  ; Program Files (x86)
  StrCpy $R2 $PROGRAMFILES32
  ${Locate} "$R2" "/G=0 /M=$R0" "FindHandlerCallBack"  
  ${If} $R1 != ""
    StrCpy $logstring "$R0 found: $R1.  Skipping installation."
    Call logMessage
    Goto xlpEnd
  ${Else}    
    StrCpy $R1 ""  ; reset for results
    StrCpy $R2 $PROGRAMFILES64
    ; Program Files (64-bit)
    ${Locate} "$R2" "/G=0 /M=$R0" "FindHandlerCallBack"
    ${If} $R1 != ""
      StrCpy $logstring "$R0 found: $R1.  Skipping installation."
      Call logMessage
      Goto xlpEnd
    ${EndIf}
  ${EndIf}
  
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

    inetc::get "$xlpurl" "$xlpfilename" /end
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
        Call logMessage
    ${Else}
      StrCpy $logstring "XLingPaper installed successfully."
      Call logMessage
    ${EndIf}
  ${Else}
    StrCpy $logstring "ERROR: Could not download XLingPaper. Skipping installation."
    Call logMessage
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
  ; Variables to hold search results
  StrCpy $R0 "Praat.exe"

  StrCpy $R1 ""  ; This will hold the result
  ; Program Files (x86)
  StrCpy $R2 $PROGRAMFILES32
  ${Locate} "$R2" "/G=0 /M=$R0" "FindHandlerCallBack"
  ${If} $R1 != ""
    StrCpy $logstring "$R0 found: $R1.  Skipping installation."
    Call logMessage
    Goto praatEnd
  ${Else}    
    StrCpy $R1 ""  ; reset for results
    StrCpy $R2 $PROGRAMFILES64
    ; Program Files (64-bit)
    ${Locate} "$R2" "/G=0 /M=$R0" "FindHandlerCallBack"
    ${If} $R1 != ""
      StrCpy $logstring "$R0 found: $R1.  Skipping installation."
      Call logMessage
      Goto praatEnd
    ${EndIf}
  ${EndIf}
  
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

    inetc::get "$praaturl" "$praatfilename" /end
    Pop $0 ;Get the return value
    ${If} $0 != 'OK'
      StrCpy $logstring "ERROR: $0.  Unable to download Praat."
      Call logMessage      
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
      Call logMessage

    ${Else}

      StrCpy $logstring "Praat extracted successfully."
      Call logMessage
      StrCpy $logstring "Adding $PROGRAMFILES to path so Praat.exe will be found."
      Call logMessage
      
      ; Set to HKLM
      ; For info on Envar plugin, see https://nsis.sourceforge.io/EnVar_plug-in
      EnVar::SetHKLM
      ; Check for path set in HKLM
      EnVar::Check "Path" "NULL"
      Pop $0
      StrCpy $logstring "EnVar::Read Registry 'Path' RC = $0"
      Call logMessage
      ${If} $0 == 0
        ; Add to path
        EnVar::AddValue "Path" "$PROGRAMFILES"
        Pop $0
        StrCpy $logstring "Registry adding $PROGRAMFILES to Path Environment variable.  RC = $0"
        Call logMessage        
      ${Else}
        StrCpy $logstring "Unable to update registry to add $PROGRAMFILES to Path; Praat may not be recognized."
        Call logMessage
      ${EndIf}

    ${EndIf}
  ${EndIf}
;--------------------------------
praatEnd:
SectionEnd


;***************************************************************************************
Section "Mercurial"  mercurialId
  
  ;----------------------------------------------------------------
  !insertmacro MUI_HEADER_TEXT_PAGE "${TITLENAME}" "Installing Mercurial...."
  StrCpy $logstring "${NEWLINE}-----  Mercurial Installer ----- "
  Call logMessage

  StrCpy $logstring "Checking if Mercurial is already installed..."
  Call logMessage

  ; Check if Mercurial is already installed to skip the installation
  ; Variables to hold search results
  StrCpy $R0 "Mercurial"
  
  StrCpy $R1 ""  ; This will hold the result
  ; Program Files (x86)
  StrCpy $R2 $PROGRAMFILES32
  ${Locate} "$R2" "/G=0 /M=$R0" "FindHandlerCallBack"
  ${If} $R1 != ""
    StrCpy $logstring "$R0 found: $R1.  Skipping installation."
    Call logMessage
    Goto mercurialEnd
  ${Else}    
    StrCpy $R1 ""  ; reset for results
    StrCpy $R2 $PROGRAMFILES64
    ; Program Files (64-bit)
    ${Locate} "$R2" "/G=0 /M=$R0" "FindHandlerCallBack"
    ${If} $R1 != ""
      StrCpy $logstring "$R0 found: $R1.  Skipping installation."
      Call logMessage
      Goto mercurialEnd
    ${EndIf}
  ${EndIf}
  
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

    inetc::get "$hgurl" "$hgfilename" /end
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
        Call logMessage
    ${Else}
      StrCpy $logstring "Mercurial installed successfully."
      Call logMessage
    ${EndIf}
  ${Else}
    StrCpy $logstring "ERROR: Could not download Mercurial. Skipping installation."
    Call logMessage
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
; .onInit is executed automatically when the installer is started
;     Use it to initialize features and variables
Function .onInit

  # Define paths  

  StrCpy $pythonversion "3.12.4"
  StrCpy $pythonfilename "python-$pythonversion-amd64.exe"
  StrCpy $pythonsize "^(25.5322 Megabyte^(s^); 26772456 bytes^)"
  StrCpy $pythonurl "https://www.python.org/ftp/python/3.12.4/$pythonfilename"

  StrCpy $gitversion "2.45.2"
  StrCpy $gitfilename "Git-$gitversion-64-bit.exe"
  StrCpy $gitsize "^(68.1 MB; 68,131,584 bytes^)"
  StrCpy $giturl "https://github.com/git-for-windows/git/releases/download/v2.45.2.windows.1/$gitfilename"

  StrCpy $aztfilename "$INSTDIR\main.py"
  StrCpy $transcriberfilename "$INSTDIR\transcriber.py"   

  StrCpy $praatversion "6413"
  StrCpy $praatfilename "praat$praatversion_win-intel64.zip"
  StrCpy $praaturl "https://www.fon.hum.uva.nl/praat/$praatfilename"

  StrCpy $xlpversion "3-10"
  StrCpy $xlpfilename "XLingPaper$xlpversion-1XXEPersonalEditionFullSetup.exe"
  StrCpy $xlpurl "https://software.sil.org/downloads/r/xlingpaper/$xlpfilename"

  StrCpy $hgversion "6.0"
  StrCpy $hgfilename "Mercurial-$hgversion-x64.exe"
  StrCpy $hgurl "https://www.mercurial-scm.org/release/windows/$hgfilename"

  StrCpy $charisversion "6.200"
  StrCpy $charisfilename "CharisSIL-$charisversion"
  StrCpy $chariszipfile "CharisSIL-$charisversion.zip"
  StrCpy $charisurl "https://software.sil.org/downloads/r/charis/$chariszipfile"

  StrCpy $filepath $EXEDIR  
  ; Destination directory for temporary installation files (OUTDIR)
  SetOutPath $filepath

  ; Include icons for setting in shortcuts - must come after SetOutPath is defined
  File "azt.ico"
  File "Transcribe-Tone.ico"
    
  ClearErrors
  StrCpy $logfile "${INSTALLERNAME}.log"
  FileOpen $log0 $logfile w

  SetDetailsPrint both

  StrCpy $filename $EXEFILE
  StrCpy $logstring  "Installer is $filepath\$filename"  
  Call logMessage 

  StrCpy $0 $DESKTOP
  StrCpy $logstring "DESKTOP is $DESKTOP"
  Call logMessage 

  # set sections as selected and read-only
  IntOp $0 ${SF_SELECTED} | ${SF_RO}  
  SectionSetFlags ${pythonId} $0
  SectionSetFlags ${gitId} $0
  SectionSetFlags ${aztId} $0
  SectionSetFlags ${charisId} $0

  ; Check if the installer is running with admin rights
  StrCpy $logstring "-----  Starting Installation ----- ${NEWLINE}Installing from $filepath"
  Call logMessage
  
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
    MessageBox MB_OK $logstring
    Call logMessage
    StrCpy $withadmin "0"
    Abort
  ${EndIf}  

FunctionEnd

;-----------------------------------------------------------------
; .onInstSuccess - Executes at the end of a successful installation 
Function .onInstSuccess
    StrCpy $logstring "Installation completed successfully.${NEWLINE}${NEWLINE}A-Z+T will be launched now to finish configuration."
    Call logMessage
    FileClose $log0
    MessageBox MB_OK $logstring
    StrCpy $logstring  "Doing first run of A-Z+T, to make sure modules are installed..."
    Call logMessage
    ClearErrors
    ExecShell "open" "python.exe" "$aztfilename" SW_SHOW
FunctionEnd

;-----------------------------------------------------------------
;.onInstFailed - Executes at the end of an installation abort
Function .onInstFailed
  StrCpy $logstring  "${APPNAME} installation aborted."
  Call logMessage
  FileClose $log0
  MessageBox MB_YESNO "${APPNAME} installation aborted.  View log file?" IDNO NoReadme
      Exec "notepad.exe $logfile"
  NoReadme:
FunctionEnd

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
; FindHandlerCallBack: Function call required by ${Locate} 
; $R9    contains the full path of the located folder
; $R8    "path"
; $R7    "name"
; $R6    "size"  ($R6="" if directory, $R6="0" if file with /S=)
; Store the first found folder path in $R1  
; $R0 contains the original search string
; $R2 contains the target path being searched
Function FindHandlerCallBack
  StrCpy $R1 $R9
  StrCpy $logstring "FindHandlerCallBack - $R0 Found at $R1"
  Call logMessage
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
; checkGitVersion: Function checks for git already installed
;                  and its version number.
; Expects the desired version to be in "$gitversion".  
; Compares the installed git version (if any) to the desired version
; Results pushed to the stack:
; Push $thisVersion : version string found
; Push $exitCode : "0" means version is installed and is >= desired version.
Function checkGitVersion
  Var /GLOBAL thisVersion
  Var /GLOBAL versionOffset
  Var /GLOBAL exitCode  
  
  StrCpy $thisVersion "Git version not found"  

  ; Run 'git --version' and capture the output
  StrCpy $logstring "Checking git version"
  Call logMessage

  StrCpy $tempLogFile "git_error.log"
  ExecWait 'cmd /C git --version >$tempLogFile' $exitCode
  StrCpy $logstring "   Return code: $exitCode"
  Call logMessage
  ${If} $exitCode == 0    
  
    ; Read the error log file content into a variable
    FileOpen $0 $tempLogFile r
    FileRead $0 $thisVersion
    FileClose $0

    StrCpy $logstring "git version results: $thisVersion"
    Call logMessage
  
    ; Extract the version number from the output
    ; The output will be in a form such as "git version x.y.z.windows.n", where we only want x.y.z (major.minor.patch)
    ${StrLoc} $R0 $thisVersion "git version" ">" ; Find "git version" in the output - > is start of line
    IntOp $R0 $R0 + 11 ; Move the pointer to version number, 11 spaces beyond the "git version"
    StrCpy $thisVersion $thisVersion "" $R0 ; Extract the version number and beyond
    ;StrCpy $logstring "thisVersion: $thisVersion"
    ;Call logMessage

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
    ;StrCpy $logstring "extracted version number: $thisVersion"
    ;Call logMessage

    ; Prepare the version number for comparison by replacing any bad characters
    ${VersionConvert} $thisVersion "" $thisVersion
    ; Result expected in $R0: 0-Versions are equal; 1-thisVersion is newer; 2-gitversion is newer
    ${VersionCompare} $thisVersion $gitversion $R0
    StrCpy $logstring "VersionCompare result code: $R0"
    Call logMessage

    ${If} $R0 == "2"
    StrCpy $logstring "Git version found: $thisVersion is less than desired $gitversion"
      Call logMessage
      StrCpy $exitCode "1" ; will require reinstall    
    ${Else}
      StrCpy $logstring "Git version found: $thisVersion is newer or equal to desired $gitversion"
      Call logMessage
      StrCpy $exitCode "0" ; will not require reinstall  
    ${EndIf}

  ${Else}
      StrCpy $logstring "Git is not installed."
      Call logMessage
      StrCpy $exitCode "1" ; will require install
  ${EndIf}

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
  ExecWait "$InstDrive"

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
  ExecWait 'cmd /C $\"$gitExe$\" pull origin 2>$tempLogFile' $0
  StrCpy $logstring "   Return value: $0"
  Call logMessage
  ${If} $0 != 0

    ; Read the error log file content into a variable
    FileOpen $0 $tempLogFile r
    FileRead $0 $ReturnError
    FileClose $0

    StrCpy $logstring "git pull origin returned error: ${NEWLINE}$ReturnError"
    Call logMessage
  ${EndIf}

  ; Switch back to the installation drive and directory
  ; Compare current drive ($ExeDrive) with the target drive ($InstDrive)
  StrCmp $ExeDrive $InstDrive noDriveChange2 0

  ; If the drives are different, switch to the target drive
  StrCpy $logstring "Switching to Drive: $ExeDrive"
  Call logMessage
  ExecWait "$ExeDrive"

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

; Search for the full path of python
StrCpy $0 "python.exe"
SearchPath $R1 $0 ; $R1 will hold the full path to python.exe if it is found in environment 

; If python was just installed, it will not be in the current environment yet, so 
; we have to find it in a roundabout way, by executing a second shell and using the 
; Windows "where" command
${If} $R1 == ""
  StrCpy $logstring "python.exe path not found."
  Call logMessage
  StrCpy $R8 "getpythonpath.cmd"
  FileOpen $R9 $R8 w
  FileWrite $R9 "@echo off${NEWLINE}"
  FileWrite $R9 "call :runme-2 1>pathfile.txt${NEWLINE}"
  FileWrite $R9 "exit /B${NEWLINE}"
  FileWrite $R9 ":runme-2${NEWLINE}"
  FileWrite $R9 "where python${NEWLINE}"
  FileClose $R9 

  ClearErrors
  ExecWait "cmd /C getpythonpath.cmd" $0

  StrCpy $logstring "getpythonpath return code: $0"
  Call logMessage
  ${If} $0 != 0
    StrCpy $logstring "Error getting python path"
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring
    Abort
  ${EndIf}

  StrCpy $R8 "pathfile.txt"
  ; Read the error log file content into a variable
  FileOpen $R9 $R8 r
  FileRead $R9 $R7
  FileClose $R9

  StrCpy $pythonPath $R7  
  StrCpy $logstring "python path: $pythonPath"
  Call logMessage

  StrCpy $pythonExe "$pythonPath\python.exe"
${Else}
  ; if it can be found directly, no need to use whole path
  StrCpy $pythonExe "python"
${EndIf}

StrCpy $logstring "Python Path: $pythonExe"
Call logMessage
 
FunctionEnd

;-----------------------------------------------------------------
; getGitPath: Function searches for git executable.
;             If not found, runs a separate windows shell 
;             to pull the path from the environment variable
Function getGitPath

; Search for the full path of git
StrCpy $0 "git.exe"
SearchPath $R1 $0 ; $R1 will hold the full path to git.exe if it is found in environment 

; If git was just installed, it will not be in the current environment yet, so 
; we have to find it in a roundabout way, by executing a second shell and using the 
; Windows "where" command
${If} $R1 == ""
  StrCpy $logstring "git.exe path not found."
  Call logMessage

  StrCpy $R8 "getgitpath.cmd"
  FileOpen $R9 $R8 w
  FileWrite $R9 "@echo off${NEWLINE}"
  FileWrite $R9 "call :runme-2 1>pathfile.txt${NEWLINE}"
  FileWrite $R9 "exit /B${NEWLINE}"
  FileWrite $R9 ":runme-2${NEWLINE}"
  FileWrite $R9 "where git${NEWLINE}"
  FileClose $R9 

  ExecWait "cmd /C getgitpath.cmd" $0

  StrCpy $logstring "getgitpath return code: $0"
  Call logMessage
  ${If} $0 != 0
    StrCpy $logstring "Error getting git path"
    Call logMessage
    MessageBox MB_OK|MB_ICONEXCLAMATION $logstring
    Abort
  ${EndIf}

  StrCpy $R8 "pathfile.txt"
  ; Read the error log file content into a variable
  FileOpen $R9 $R8 r
  FileRead $R9 $R7
  FileClose $R9

  StrCpy $gitPath $R7  
  StrCpy $logstring "git path: $gitPath"
  Call logMessage

  StrCpy $gitExe "$gitPath\git.exe"

${Else}
  ; if it can be found directly, no need to use whole path
  StrCpy $gitExe "git"
${EndIf}

StrCpy $logstring "Git Path: $gitExe"
Call logMessage 

FunctionEnd