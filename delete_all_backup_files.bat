@echo off

rem Delete all previous backup files
dir "*.bak" /B /A:-D /ON /S > liste.txt
if exist "liste.txt" (
    for /f %%a in (liste.txt) do (
        del "%%a" /q 1>nul 2>nul
    )
    del "liste.txt" /q 1>nul 2>nul
)
