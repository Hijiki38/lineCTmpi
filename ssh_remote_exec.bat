@echo off
set currentDir=%cd%
powershell.exe -ExecutionPolicy Bypass -File "./ssh_remote_exec_para.ps1" -currentDir "%currentDir%"
pause



