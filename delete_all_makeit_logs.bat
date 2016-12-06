@echo off

rem Delete all previous build logs
dir "20??????_????????_*" /B /A:D /ON /S > liste.txt
if exist "liste.txt" (
    for /f %%a in (liste.txt) do (
        rmdir "%%a" /s /q 1>nul 2>nul
    )
    del "liste.txt" /q 1>nul 2>nul
)
