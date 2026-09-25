# A-Z+T Installer

This installer will install the following:

- [Python](https://www.python.org/)
- [Git for Windows](https://github.com/git-for-windows/git)
- [A-Z+T Repository](https://github.com/kent-rasmussen/azt.git), in `%LOCALAPPDATA%\Programs\AZT\azt` (an existing `Desktop\azt` is updated in place), with its python modules
- [Desktop Shortcuts for A-Z+T and Transcriber](https://nsis.sourceforge.io/Docs/Chapter4.html#generalpurpose)
- [Charis SIL Fonts](https://software.sil.org/charis/)
- [XLingPaper](https://software.sil.org/xlingpaper/)
- [Praat](https://www.fon.hum.uva.nl/praat/)
- [Mercurial](https://www.mercurial-scm.org/)


## Installation Instructions

### Prerequisites

- Windows 10 or 11 
- Administrator rights for the machine-wide steps (the user's own, or an administrator's password at the prompt)
- Write access to the folder where the installer executable is located

### To install

Download and run AZT_Installer.exe

Run the installer as the user who will use A-Z+T (not "Run as administrator").  After the components are selected, a second copy of the installer asks for administrator rights, for the machine-wide steps only (Git, fonts, registry, optional programs).  Reply "Yes" to the Windows User Account Control prompt (an administrator's password may be entered here); replying "No" will terminate the installer.

Select components to install.   Grayed out components are required.

### Notes

During installation, if a component has already been installed and is at the required version, the installer will skip installation of that component.  If the component is at an older version, the installer will install the newer verison.  Python is the exception: the installer uses python 3.13 (any release) if it is installed, and otherwise installs the newest 3.13 release with a Windows installer (its last release with one, once 3.13 gets security fixes only; `PYTHONMINORS` in the script allows moving to a newer minor instead), beside any other python; other pythons on the path are left alone.

If successful, the installer will launch A-Z+T (main.py).  The first time A-Z+T is launched, it will perform some scaling configuration, which may take a few minutes.  

### Troubleshooting

The installation logs AZT_Installer.log (user steps) and AZT_Installer_admin.log (machine-wide steps) will be in the same directory as AZT_Installer.exe.  This log documents the installation steps in detail and may be useful for troubleshooting any installation issues.

If the installer fails, it is safe to restart it.  If the failure was due to not being able to locate python or git, often times the second pass will pick up the new path and continue the installation successfully.   Re-running the installer multiple times does not create any problems as the only change made will be to refresh the azt code from the git repository.


## Developer Notes

The AZT installer was created using [NSIS version 3.10](https://nsis.sourceforge.io/Main_Page)


The script file is `AZT_Installer_UI.nsi`.

### Dependencies

```
  !include MUI2.nsh  ;Modern UI
  !include LogicLib.nsh
  !include WordFunc.nsh
  !include FileFunc.nsh
  !include StrFunc.nsh    
  !include WinMessages.nsh
  !include Locate.nsh
```

### Plugins

- [NsExec](https://nsis.sourceforge.io/NsExec_plug-in) - included as part of NSIS.

  The following are not part of the NSIS base installation.  
  Install Zip files by extracting directly to the NSIS installaton directory 
  \(usually C:\Program Files (x86)\NSIS \)

- [EnVar](https://nsis.sourceforge.io/EnVar_plug-in)
- [Inetc](https://nsis.sourceforge.io/Inetc_plug-in)
- [Locate](https://nsis.sourceforge.io/Locate_plugin)  
    - To install Locate, run install.exe but must also copy locate.dll from Plugins to each of the subdirectories otherwise vscode doesn't find it
    - Locate macro documentation will be installed to <PROGRMFILES>\NSIS\Docs\Locate\Readme.txt    


### Important

- Python is required to run A-Z+T.  Failure to install and later locate the python executable will terminate the installer.

- Git is required to clone the A-Z+T repository during installation. Failure to install and later locate the git executable will terminate the installer.

- A-Z+T is cloned shallow (`--depth 1`).  If the AZT directory already exists and is not empty, `git pull --depth 1 origin` will refresh the code to the latest version.

- The installer runs as the user; it re-runs itself elevated (`/ADMINSTEPS`, one UAC prompt) for the machine-wide sections only, so that everything per-user goes to the user even when a different account gives administrator rights.

- Charis SIL fonts will be installed if possible, but if installation of the fonts fails, the installer will continue.  Failure may indicate fonts already exist.

- Optional components will not reinstall if they already exist in <PROGRAMFILES>.   If installation of any of the optional components fails, the installer will continue attempting to install remaining components.

- If Python and/or Git are installed for the first time, the installer will not be able to locate them in the subsequent commands.  To work around this, powershell will execute a windows batch file from a second shell to read the newly set Path environment variables from the registry.  A PATH command temporarily sets the new path in the windows shell, and the `where` command redirects the path to an output file.   That full path will be used for the remainder of the script.   In the case of Python, if the path can still not be found, the final attempt is to use the py launcher, which can sometimes be found in the path even when python.exe cannot.

## References

[NSIS version 3.10 Main Page](https://nsis.sourceforge.io/Main_Page)

[NSIS Developer Center](https://nsis.sourceforge.io/Developer_Center)

[NSIS Plugins](https://nsis.sourceforge.io/Category:Plugins)
