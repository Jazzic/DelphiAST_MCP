@echo off
REM Build script for DelphiAST_MCP Test Project

set DELPHI_BIN=C:\Program Files (x86)\Embarcadero\Studio\23.0\bin
set DCC=%DELPHI_BIN%\dcc64.exe
set DUNITX_SRC=C:\Program Files (x86)\Embarcadero\Studio\23.0\source\DUnitX
set DELPHIAST_SRC=C:\Users\Public\DelphiLibs\DelphiAST\Source
set DELPHIAST2_SRC=C:\Users\Public\DelphiLibs\DelphiAST\Source\SimpleParser

echo Building DelphiAST_MCP Tests...

"%DCC%" -B ^
  -I"%DUNITX_SRC%" ^
  -U"%DELPHIAST_SRC%" ^
  -U"%DELPHIAST2_SRC%" ^
  -NS"System;System.Win;Winapi;DUnitX" ^
  -NUdcu64 -Ebin64 tests\DelphiAST_MCP_Tests.dpr

if %ERRORLEVEL% EQU 0 (
    echo Build successful!
) else (
    echo Build failed!
    exit /b %ERRORLEVEL%
)
