# A-Z+T Installer

This installer will install the following:

- [Python](https://www.python.org/)
- [Git for Windows](https://github.com/git-for-windows/git)
- [A-Z+T Repository](https://github.com/kent-rasmussen/azt.git)
- [Desktop Shortcuts for A-Z+T and Transcriber](https://nsis.sourceforge.io/Docs/Chapter4.html#generalpurpose)
- [Charis SIL Fonts](https://software.sil.org/charis/)
- [XLingPaper](https://software.sil.org/xlingpaper/)
- [Praat](https://www.fon.hum.uva.nl/praat/)
- [Mercurial](https://www.mercurial-scm.org/)


## Installation Instructions

### Prerequisites

- Windows 10 or 11 
- User executing the installer must have the abiltity to run as administrator
- Write access to the folder where the installer executable is located

### To install

Download and run AZT_Installer.exe

Reply "Yes" to Windows User Account Control prompt to "allow this app from an unknown publisher to make changes to your device."   Replying "No" will terminate the installer.

Select components to install.   Grayed out components are required.

### Notes

During installation, if a component has already been installed and is at the required version, the installer will skip installation of that component.  If the component is at an older version, the installer will install the newer verison.

If successful, the installer will launch A-Z+T (main.py).  The first time A-Z+T is launched, it will perform some scaling configuration, which may take a few minutes.  

The installation log AZT_Installer.log will be in the same directory as AZT_Installer.exe.  This log documents the installation steps in detail and may be useful for troubleshooting any installation issues.

## Developer Notes

The AZT installer was created using [NSIS version 3.10](https://nsis.sourceforge.io/Main_Page)



The script file is AZT_Installer_UI.nsi.

### Dependencies

```
  !include MUI2.nsh  ;Modern UI
  !include LogicLib.nsh
  !include WordFunc.nsh
  !include FileFunc.nsh
  !include StrFunc.nsh    
  !include WinMessages.nsh
  
```

### Plugins

- [NsExec](https://nsis.sourceforge.io/NsExec_plug-in) - included as part of NSIS.

The following are not part of the NSIS base installation.  Zip files provided should be unzipped directly to the NSIS installaton dir \( C:\Program Files (x86)\NSIS \)

- [EnVar](https://nsis.sourceforge.io/EnVar_plug-in)
- [Inetc](https://nsis.sourceforge.io/Inetc_plug-in)


### Important

- Python is required to run A-Z+T.

- Git is required to clone the A-Z+T repository during installation.

- If the AZT directory exists, `git pull origin` will refresh the code to the latest version .

- Charis SIL fonts will be installed if possible, but if installation of the fonts fails, the installer will not fail.   

- If installation of any of the optional components fails, the installer will continue attempting to install remaining components.

- If Python and/or Git are installed for the first time, the installer will not find them in the subsequent commands.  So we run a windows batch file from a second shell to get the updated path into an output file and then read the path in for use in the remainder of the script.   

## References

[NSIS version 3.10 Main Page](https://nsis.sourceforge.io/Main_Page)

[NSIS Developer Center](https://nsis.sourceforge.io/Developer_Center)

[NSIS Plugins](https://nsis.sourceforge.io/Category:Plugins)
