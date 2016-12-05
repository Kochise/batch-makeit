@echo off

rem Extended Batch Makefile by David KOCH 20131125-20131224
rem Command : makeit cmd "make_file" ["exclude_file"] ["log_file"/"nolog"]
rem Argument  %0     %1   %2           %3               %4
rem                   |    |            |                |
rem                   |    |            |               specify a logfile, or if
rem                   |    |            |               empty, will create one by
rem                   |    |            |               default, unless "nolog"
rem                   |    |            |               is used instead (useful
rem                   |    |            |               when running under the
rem                   |    |            |               Jenkins framework)
rem                   |    |            |
rem                   |    |           optional text file with one line per
rem                   |    |           exclusion, 'findstr' format: just a part
rem                   |    |           of the path and/or file name to be found
rem                   |    |           is enough to exclude the whole line
rem                   |    |
rem                   |   make_file[.txt] is the configuration file
rem                   |
rem                  all      - do "clean" to "run"
rem                  partial  - do "clean" to "flash" (no "run")
rem                  rebuild  - do "clean" to "link" (no "flash" and "run")
rem                  quick    - do "compile" to "run" (no "clean)
rem                  build    - do "compile" and "link" (with pre/post build)
rem                  clean    - clean destination folder from old files
rem                  assemble - assemble ASM_EXT minus ASM_EXC files
rem                  compile  - compile CPP_EXT minus CPP_EXC files (pre build)
rem                  link     - link LNK_EXT files into LNK_OBJ (post build)
rem                  flash    - flash LNK_BIN file using default parameters
rem                  run      - launch the selected debugger executable
rem                  map      - perform mapping analysis

rem Todo list (Oh No! More Lemmings)
rem Implement GNU ARM support in configuration files
rem Count the number of source file and compare with generated object files
rem Implement errorlevel support to return application error code and exit
rem Add a parametrizable section to select between debug probes (ext file?)
rem Add a parametrizable section to select between compilers (ext file?)
rem Add a LOG_CNF entry to give a default configuration file name (no ext file?)
rem Praise the Lords

rem For correct string substitution, need delayed variable expansion
setlocal enabledelayedexpansion

rem Set this variable to get some fancy debug output
set "vdeb="
rem Set this variable to run each command as well than logging them
set "vrun=1"

rem Convert current time and date in a more usable format
for /f "tokens=1,2,3,4 delims=/ " %%a in ("%date%") do set "fdate=%%d%%c%%b%%a"
for /f "tokens=1,2,3,4 delims=:," %%a in ("%time%") do set "ftime=%%a%%b%%c%%d"
set "fdate=%fdate: =0%"
set "ftime=%ftime: =0%"

rem Call info
if "%1"=="" goto info
if "%1"=="-h" goto info
if "%1"=="--help" goto info
if "%1"=="/?" goto info
if "%1"=="-man" goto info

rem Set command variables
if "%1"=="all" set "vtxt=doing all"
if "%1"=="quick" set "vtxt=quick build"
if "%1"=="partial" set "vtxt=partial (no run)"
if "%1"=="rebuild" set "vtxt=rebuilding"
if "%1"=="build" set "vtxt=building"
if "%1"=="clean" set "vtxt=cleaning"
if "%1"=="assemble" set "vtxt=assembling"
if "%1"=="compile" set "vtxt=compiling"
if "%1"=="link" set "vtxt=linking"
if "%1"=="flash" set "vtxt=flashing"
if "%1"=="run" set "vtxt=running"
if "%1"=="map" set "vtxt=mapping"

rem Set command prefix
if "%1"=="all" set "vpre=CLN_ ASM_ PRE_ CPP_ LNK_ PST_ FLH_ RUN_"
if "%1"=="partial" set "vpre=CLN_ ASM_ PRE_ CPP_ LNK_ PST_ FLH_"
if "%1"=="rebuild" set "vpre=CLN_ ASM_ PRE_ CPP_ LNK_ PST_"
if "%1"=="quick" set "vpre=PRE_ CPP_ LNK_ PST_ FLH_ RUN_"
if "%1"=="build" set "vpre=PRE_ CPP_ LNK_ PST_"
if "%1"=="clean" set "vpre=CLN_"
if "%1"=="assemble" set "vpre=ASM_"
if "%1"=="compile" set "vpre=PRE_ CPP_"
if "%1"=="link" set "vpre=LNK_ PST_"
if "%1"=="flash" set "vpre=FLH_"
if "%1"=="run" set "vpre=RUN_"
if "%1"=="map" set "vpre=MAP_"

rem Process location tag first
set "vpre=LOC_ %vpre%"

rem Set argument list
set "varg=EXE SRC DST CPU CLI VIA LOG DBG DEP OBJ LNK BIN DUP EXT EXC DEL XPY CPY ARG DEF INC LIB TMP"

rem Set default var
set "vrel=%~dp2"
set "vsrc=%~f2.txt"
set "vloc=%~dp2"
set "vdst=%vloc%%fdate%_%ftime%_%2_%1"
set "vslv=%vdst%\%2.solv"
set "vsrt=%vdst%\%2.sort"
set "vdir=/B /A:-D /ON /S"

rem Create the folder (because Windows cannot do it automatically when writing a file)
mkdir "%vdst%" 2>nul

rem Get excluded paths file
if not "%3"=="nolog" set "vexc=%~f3"

rem Set default or specified log file
if not "%4"=="nolog" set "vlog=%~f4"
if "%4"=="" set "vlog=%vdst%\%1.log"

rem Set logging command
if not "%3"=="nolog" if not "%4"=="nolog" (
    set "clog=| tee -a %vlog%"
) else (
    set "vlog=nolog"
)

rem Set the CPU scheduler parameters
set /a "cmin=1"
set /a "cmax=%NUMBER_OF_PROCESSORS%-(1-%cmin%)"
set "lcpu=%vdst%\%2.lock.cpu"
set "lerr=%vdst%\%2.lock.err"
set "lvia=%vdst%\%2.lock.via"

echo --- Extended Batch Makefile - %fdate% @ %ftime% ---------------------------- %clog%
echo Makeit cmd : %1 %clog%
echo Makeit cnf : !vsrc:%vrel%=.\! %clog%
echo Makeit exc : %vexc% %clog%
echo Makeit log : !vlog:%vrel%=.\! %clog%
echo --- %vtxt% --------------------------------------------------------------- %clog%
echo. %clog%

rem Resolve ${...} variables with their corresponding parameter
echo Parsing make file... %clog%

rem Solve destination path with current configuration
findstr "LOC_DST=" "%vsrc%" > "%vslv%.1"
rem If LOC_DST tag found
if exist "%vslv%.1" for /f %%i in (%vslv%.1) do (
    rem Add configuration to the LOC_DST path
    echo %%i\%2>> "%vslv%.0"
)
rem Add all the rest
findstr /v "LOC_DST=" "%vsrc%" >> "%vslv%.0"

rem Add custom tokens
rem echo TOTO=titi>> "%vslv%.0"

rem Sort unresolved file for access optimisation
sort "%vslv%.0" > "%vslv%.1"

rem Multipass (c) Leeloo Dallas
for /l %%h in (1,1,3) do (
    if exist "%vslv%.0" (
        rem Keep unsolved argument to process
        findstr "${.*}" "%vslv%.0" > "%vslv%.2"
        rem Keep resolved arguments in a separate file
        findstr /v "${.*}" "%vslv%.0" >> "%vslv%.3"
        rem Ensure no more pass if no more resolve to do
        del "%vslv%.0" /q 2>nul
        rem Each line with token to resolve
        for /f %%i in (%vslv%.2) do (
            rem Each token found
            for /f "tokens=2 delims={}" %%j in ("%%i") do (
                rem Look for the resolved parameter
                for /f "tokens=2 delims==" %%k in ('findstr "%%j=" "%vslv%.1"') do (
                    set "vtmp=%%i"
                    rem Replace conf token with current conf parameter
                    set "vtmp=!vtmp:${CONF}=%2!"
                    rem Replace token with resolved and expanded (~f) parameter
                    set "vtmp=!vtmp:${%%j}=%%~fk!"
                    rem Ensure backslash in path
                    set "vtmp=!vtmp:/=\!"
                    rem Store the resolved argument for the next pass
                    echo !vtmp!>> %vslv%.0
                )
            )
        )
    )
)
rem You can compare "%vslv%.1" with "%vsrt%.0" to check the variable expansion
sort "%vslv%.3" > "%vsrt%.0"

rem Parse and execute commands
echo Executing make file... %clog%
set "mrun=1"
rem Each command prefix
for %%i in (%vpre%) do (
    set "vexe="
    set "vvia="

    set "mexe="
    set "msrc="
    set "mdst="

    set /a "mcpu=0"

    set "mcli="
    set "mvia="
    set "mlog="
    set "mdbg="
    set "mdep="
    set "mobj="
    set "mlnk="
    set "mbin="
    set "mdup="

    set "mext="
    set "mexc="
    set "mdel="
    set "mxpy="
    set "mcpy="
    
    set "marg="
    set "mdef="
    set "minc="
    set "mlib="
    set "mtmp="

    rem Each argument suffix
    for %%j in (%varg%) do (
        rem Each parameter line
        if exist %vsrt%.0 for /f "delims=!" %%k in ('findstr "^%%i%%j=" "%vsrt%.0"') do (
            set "vtmp=%%k"
            rem Remove the leading header
            set "vtmp=!vtmp:%%i%%j=!"
            rem Remove trailing space
            for /l %%l in (1,1,1) do if "!vtmp:~0,1!"==" " set "vtmp=!vtmp:~1!"
            rem Remove the equal sign (batch cannot handle them properly)
            set "vtmp=!vtmp:~1!"
rem            Dirty hack, should be solved elegantly
rem            set "vtmp=!vtmp:~8!"

            if not "!vtmp!"=="!vtmp:\..=!" (
                call :expandpath "!vtmp!" && set "vtmp=!pexp!"
            )

            rem Try to expand folder
if "%vdeb%"=="TOTO" if "%if "%%j"=="SRC" or "%%j"=="DST" or "%%j"=="INC" (
                for /f "delims=!" %%l in (!vtmp!) do (
                    set "vexp=%%~fl"
                    if not "!vexp!"=="" set "vtmp=!vexp!"
                )
            )

            rem Remove trailing and leading spaces
            for /l %%l in (1,1,2) do if "!vtmp:~-1!"==" " set "vtmp=!vtmp:~0,-1!"
            for /l %%l in (1,1,2) do if "!vtmp:~0,1!"==" " set "vtmp=!vtmp:~1!"

            if "%%j"=="EXE" set "mexe=!vtmp!"
            if "%%j"=="SRC" set "msrc=!vtmp!"
            if "%%j"=="DST" set "mdst=!vtmp!"

            if "%%j"=="CPU" set "mcpu=!vtmp!"

            if "%%j"=="CLI" set "mcli=!vtmp!"
            if "%%j"=="VIA" set "mvia=!vtmp!"
            if "%%j"=="LOG" set "mlog=!vtmp!"
            if "%%j"=="DBG" set "mdbg=!vtmp!"
            if "%%j"=="DEP" set "mdep=!vtmp!"
            if "%%j"=="OBJ" set "mobj=!vtmp!"
            if "%%j"=="LNK" set "mlnk=!vtmp!"
            if "%%j"=="BIN" set "mbin=!vtmp!"
            if "%%j"=="DUP" set "mdup=!vtmp!"

            rem File operation specific arguments
            if "%%j"=="EXT" set "mext=!mext! !vtmp!"
            if "%%j"=="EXC" set "mexc=!mexc! !vtmp!"
            if "%%j"=="DEL" set "mdel=!mdel! !vtmp!"
            if "%%j"=="XPY" set "mxpy=!mxpy! !vtmp!"
            if "%%j"=="CPY" set "mcpy=!mcpy! !vtmp!"
            
            rem Via-method compatible arguments
            if "!mvia!"=="" (
                if "%%j"=="ARG" set "marg=!marg! !vtmp!"
                if "%%j"=="DEF" set "mdef=!mdef! -D!vtmp!"
                if "%%j"=="INC" set "minc=!minc! -I!vtmp!"
                if "%%j"=="LIB" set "mlib=!mlib! !vtmp!"
                if "%%j"=="TMP" set "mtmp=!mtmp! !vtmp!"
            ) else (
                if "%%j"=="ARG" echo !vtmp!>> "%vsrt%.%%i.arg"
                if "%%j"=="DEF" echo -D!vtmp!>> "%vsrt%.%%i.def"
                if "%%j"=="INC" echo -I!vtmp!>> "%vsrt%.%%i.inc"
                if "%%j"=="LIB" echo !vtmp!>> "%vsrt%.%%i.lib"
                if "%%j"=="TMP" echo !vtmp!>> "%vsrt%.%%i.tmp"
            )
        )
    )
    
    rem Remove the ending backslash of path
    call :cleanpath "!mexe!" && set "mexe=!pcln!"
    call :cleanpath "!msrc!" && set "msrc=!pcln!"
    call :cleanpath "!mdst!" && set "mdst=!pcln!"
    call :cleanpath "!mdup!" && set "mdup=!pcln!"

    rem Correct the CPU max
    if "!mcpu!"=="" set /a "mcpu=0"
    if !mcpu! equ 0 (
        set "mcpu=%cmax%"
    ) else (
        set /a "mcpu=!mcpu!-(1-%cmin%)"
        if !mcpu! gtr %cmax% set "mcpu=%cmax%"
    )

    rem Correct the destination path (deprecated)
rem    if not "!mdst!"=="" set "mdst=!mdst!\%2"

    rem If no source path, switch to destination path
    if "!msrc!"=="" if not "!mdst!"=="" set "msrc=!mdst!"

    rem Command prefix to execute
    if not "!mexe!"=="" (
        if "%%i"=="CLN_" echo Now cleaning... %clog%
        if "%%i"=="ASM_" echo Now assembling... %clog%
        if "%%i"=="PRE_" echo Now pre building... %clog%
        if "%%i"=="CPP_" echo Now compiling... %clog%
        if "%%i"=="LNK_" echo Now linking... %clog%
        if "%%i"=="PST_" echo Now post building... %clog%
        if "%%i"=="FLH_" echo Now flashing... %clog%
        if "%%i"=="RUN_" echo Now running... %clog%
        if "%%i"=="MAP_" echo Now mapping... %clog%
    )
    
    if not "!mexe!"=="" if "!msrc!"=="" (
        echo  ERROR : No source path for "%%i" ! %clog%
    ) else (
        rem Beware buddies, "LOC_" *have* to be always the first tag in %vpre%
        if "%%i"=="LOC_" (
            rem Fetch the path of binaries
            set "mloc=!mexe!"
        ) else (
            rem Yeah, because if the path doesn't exist, file creation fails
            if not "!mdst!"=="" (
                echo  Creating destination folder tree... %clog%
if not "%vdeb%"=="" echo msrc=!msrc! %clog%
if not "%vdeb%"=="" echo mdst=!mdst! %clog%
                mkdir "!mdst!" 2>nul
                if not "!msrc!"=="!mdst!" (
                    xcopy "!msrc!" "!mdst!" /q /t /e /y 2>nul
                    rmdir "!mdst!\makefiles" /s /q 1>nul 2>nul
                )

                rem Delete the files from destination folder
                for /l %%l in (1,1,1) do if "!mdel:~0,1!"==" " set "mdel=!mdel:~1!"
                if not "!mdel!"=="" (
rem echo mdel=!mdel!
                    echo  Deleting destination files... %clog%
                    for %%j in (!mdel!) do (
rem echo del=!mdst!\*.%%j
                        del /s !mdst!\*.%%j 1>nul 2>nul
                    )
                )

                rem Xcopy the files into destination folder
                for /l %%l in (1,1,1) do if "!mxpy:~0,1!"==" " set "mxpy=!mxpy:~1!"
                if not "!mxpy!"=="" (
rem echo mxpy=!mxpy!
                    echo  Xcopying source files... %clog%
                    for %%j in (!mxpy!) do (
rem echo xcopy=!msrc!\*.%%j
                        xcopy "!msrc!\*.%%j" "!mdst!" /s /y /i /q 1>nul 2>nul
                    )
                )

                rem Copy the files into destination folder
                for /l %%l in (1,1,1) do if "!mcpy:~0,1!"==" " set "mcpy=!mcpy:~1!"
                if not "!mcpy!"=="" (
                    echo  Copying specific files... %clog%
                    set "vcmd=!mcpy!"
                    call :adaptvcmd "%2" "%2" "!msrc!" "!mdst!" "" && set "mcpy=!pcmd!"
if not "%vdeb%"=="" echo mcpy=!mcpy!
                    for %%j in (!mcpy!) do (
                        if exist %%j copy /y "%%j" "!mdst!" 1>nul 2>nul
                    )
                )
            )

            rem Construct the argument chain
            set "vtmp="
            if not "!mcli!"=="" for %%j in (!mcli!) do (
                if "%%j"=="LOC" set "vexe=!vexe!"!mloc!\"
                if "%%j"=="EXE" (
                    set "vexe=!vexe!!mexe!"
                    rem If command line started with a quote (note the hideous syntax)
                    if "!vexe:~0,1!"==^"^"^" set "vexe=!vexe!"" 
rem                    set "vexe=!vexe! "
                )
                
                if "!mvia!"=="" (
                    if "%%j"=="SRC" set "vtmp=!vtmp!!msrc! "
                    if "%%j"=="DST" set "vtmp=!vtmp!!mdst! "

                    if "%%j"=="DBG" set "vtmp=!vtmp!!mdbg! "
                    if "%%j"=="DEP" set "vtmp=!vtmp!!mdep! "
                    if "%%j"=="OBJ" set "vtmp=!vtmp!!mobj! "
                    if "%%j"=="BIN" set "vtmp=!vtmp!!mbin! "

                    rem File operation specific arguments
                    if "%%j"=="EXT" set "vtmp=!vtmp!"$[THIS]" "
                    if "%%j"=="EXC" set "vtmp=!vtmp!!mexc! "
                    if "%%j"=="LST" set "vtmp=!vtmp!$[LIST] "
                    
                    rem Via-method compatible arguments
                    if "%%j"=="ARG" set "vtmp=!vtmp!!marg! "
                    if "%%j"=="DEF" set "vtmp=!vtmp!!mdef! "
                    if "%%j"=="INC" set "vtmp=!vtmp!!minc! "
                    if "%%j"=="LIB" set "vtmp=!vtmp!!mlib! "
                    if "%%j"=="TMP" set "vtmp=!vtmp!!mtmp! "
                ) else (
                    if "%%j"=="SRC" echo !msrc!>> "%vsrt%.%%i.via"
                    if "%%j"=="DST" echo !mdst!>> "%vsrt%.%%i.via"

                    if "%%j"=="DBG" echo !mdbg!>> "%vsrt%.%%i.via"
                    if "%%j"=="DEP" echo !mdep!>> "%vsrt%.%%i.via"
                    if "%%j"=="OBJ" echo !mobj!>> "%vsrt%.%%i.via"
                    if "%%j"=="BIN" echo !mbin!>> "%vsrt%.%%i.via"

                    rem File operation specific arguments
                    if "%%j"=="EXT" echo "$[THIS]">> "%vsrt%.%%i.via"
                    if "%%j"=="EXC" echo !mexc!>> "%vsrt%.%%i.via"
                    if "%%j"=="LST" echo $[LIST]>> "%vsrt%.%%i.via"
                    
                    rem Via-method compatible arguments
                    if "%%j"=="ARG" type "%vsrt%.%%i.arg" >> "%vsrt%.%%i.via"
                    if "%%j"=="DEF" type "%vsrt%.%%i.def" >> "%vsrt%.%%i.via"
                    if "%%j"=="INC" type "%vsrt%.%%i.inc" >> "%vsrt%.%%i.via"
                    if "%%j"=="LIB" type "%vsrt%.%%i.lib" >> "%vsrt%.%%i.via"
                    if "%%j"=="TMP" type "%vsrt%.%%i.tmp" >> "%vsrt%.%%i.via"
                )
            )

            rem Clean up the command line
            set "vcmd=!vexe!" && call :cleanvcmd && set "vexe=!pcmd!"
            set "vcmd=!vtmp!" && call :cleanvcmd && set "vtmp=!pcmd!"

            rem Each extension, list files
            if not "!mext!"=="" for %%a in (!mext!) do (
if not "%vdeb%"=="" echo msrc=%%i--!msrc!\*.%%a %clog%
                dir "!msrc!\*.%%a" %vdir% >> "%vsrt%.%%i.0" 2>nul
            )

            rem Load external excludes
            if not "%vexc%"=="" for /f %%a in (%vexc%) do set "mexc=!mexc! %%a"

            rem List real files to process
            set "vlst="
if not "%vdeb%"=="" if not "!mexc!"=="" echo mexc=!mexc!
            if exist %vsrt%.%%i.0 (
                if "!mexc!"=="" (
                    rem Keep all files
                    copy "%vsrt%.%%i.0" "%vsrt%.%%i.4" /y 1>nul 2>nul
                ) else (
                    rem Remove excluded files
                    findstr /i /v "!mexc!" "%vsrt%.%%i.0" > "%vsrt%.%%i.4"
                )

                rem List the remaining files
                if exist %vsrt%.%%i.4 for /f %%a in (%vsrt%.%%i.4) do (
                    echo %%a>> "%vsrt%.%%i.1"
                    set "vlst=!vlst! %%a"
                    rem Resolve file list as being relative to source
                    call set "vlst=%%vlst:!msrc!=.%%"
                )

                rem Remove the remaining files list
                del "%vsrt%.%%i.4" /q 2>nul
if not "%vdeb%"=="" if not "!vlst!"=="" echo !vlst! > "%vsrt%.%%i.4"
            )

            rem Linking just requires one pass with many inputs (LST)
            if "%%i"=="LNK_" (
                 echo !msrc!\%2.!mbin! > "%vsrt%.%%i.1"
            )

            rem Cpu locking variables
            set /a "csrt=0"
            set /a "cend=0"
            for /l %%c in (%cmin%,1,%cmax%) do set "cexe%%c="

            rem Display here a false message because the real work is done in the loop below
            if not "!mdep!"=="" echo  Checking dependencies... %clog%

            rem Now execute the commands for each source files found
            if exist %vsrt%.%%i.1 for /f %%a in (%vsrt%.%%i.1) do (
                rem Create the relative destination path from source path
                set "vrel=%%~dpa"
                set "vrel=!vrel:/=\!"
                if "!vrel:~-1!"=="\" set "vrel=!vrel:~0,-1!"
                call set "vrel=%%vrel:!msrc!=!mdst!%%"

                rem File to process flag
                set "vchk="
                
                rem Check if the source file is newer than destination file
                set "vobj="
                if not "!mobj!"=="" (
                    set "vrem=%%~na.!mobj!"
                    rem Try in destination folder first
                    set "vobj=!mdst!\!vrem!"
                    rem Try in relative folder next
                    if not exist !vobj! set "vobj=!vrel!\!vrem!"
                    if exist !vobj! (
                        attrib +r !vobj!
                        Rem Copy on destination file only if more recent
                        xcopy /y /d %%a !vobj! 1>nul 2>nul
                        rem If more recent, fails due to write protection
                        if not errorlevel 0 set "vchk=1"
                        attrib -r !vobj!
                    ) else (
                        rem No object file found? Objection! Generate it...
                        set "vchk=1"
                    )
                ) else (
                    rem Execute even if no object file defined
                    set "vchk=1"
                )

                rem Check file dependencies (can be quite long, sadly)
                set "vdep="
                rem Has been currently disabled due to poor xcopy performance
                if "!mdep!"=="toto" if exist !vobj! if not "!mdep!"=="" (
                    rem Try in destination folder first
                    set "vdep=!mdst!\%%~na.!mdep!"
                    rem Try in relative folder next
                    if not exist !vdep! set "vdep=!vrel!\%%~na.!mdep!"
                    if exist !vdep! (
                        attrib +r !vobj!
                        for /f "delims=!" %%b in (!vdep!) do (
                            rem Get the dependency line
                            set "vtst=%%b"
                            rem Parse dependency line to keep only the dependency file path
                            call set "vtst=%%vtst:!vrem!: =%%"
                            Rem Copy on destination file only if more recent
                            xcopy /y /d !vtst! !vobj! 1>nul 2>nul
                            rem If more recent, fails due to write protection
                            if not errorlevel 0 set "vchk=1"
                        )
                        attrib -r !vobj!
                    ) else (
                        rem No dependency file? Well, misconfiguration maybe...
                        set "vchk=1"
                    )
                )

                rem If destination file absent or source file more recent
                if not "!vchk!"=="" (
                    rem Block the execution of the target process
                    if not "%vrun%"=="" (
                        rem Start the process on the first unlocked CPU
                        if !csrt! lss !mcpu! (
                            set /a "csrt+=1"
                            set /a "cnxt=csrt"
                        ) else (
                            call :waitcpu
                        )
                        del %lcpu%.!cnxt! 1>nul 2>nul
                    )
                        
                    if "!mvia!"=="" (
                        rem Get the clean command line
                        set "vcmd=!vtmp!"

                        rem Adapt the command-line in !vcmd!
                        call :adaptvcmd "%2" "%%a" "!msrc!" "!vrel!" "!vlst!" && set "vcmd=!pcmd!"
                    ) else (
                        rem Del the via file
                        del %lvia%.!cnxt! 1>nul 2>nul

                        rem Adapt the via file
                        if exist %vsrt%.%%i.via for /f "delims=!" %%b in (%vsrt%.%%i.via) do (
                            set "vcmd=%%b"
                            call :cleanvcmd && set "vcmd=!pcmd!"
                            if "!vcmd!"=="$[LIST]" (
                                rem Copy the list of source files if requested
                                if "%%i"=="LNK_" (
                                    rem Linking requires the original source files list
                                    type "%vsrt%.%%i.0" >> "%lvia%.!cnxt!"
                                ) else (
                                    type "%vsrt%.%%i.1" >> "%lvia%.!cnxt!"
                                )
                            ) else (
                                rem Adapt the command-line in !vcmd!
                                call :adaptvcmd "%2" "%%a" "!msrc!" "!vrel!" "" && set "vcmd=!pcmd!"
                                echo !vcmd!>> "%lvia%.!cnxt!"
                            )
                        )

                        rem Set the via file
                        set "vcmd=!mvia!"%lvia%.!cnxt!""
                    )
                    
                    rem Keep the expanded command line for debugging purpose
                    echo !vexe! !vcmd!>> "%vsrt%.%%i.2"
                    if not "!mvia!"=="" type "%lvia%.!cnxt!" >> "%vsrt%.%%i.2"

                    rem Block the execution of the target process
                    if not "%vrun%"=="" (
                        rem Display the file being processed
                        set "mrel=%%a"
                        call set "mrel=%%mrel:!msrc!=.%%"
                        echo   !mrel! %clog%

                        rem Log the executed command line (in case of lock conflict)
                        echo !vexe! !vcmd!>> "%vsrt%.%%i.3"
                        if not "!mvia!"=="" type "%lvia%.!cnxt!" >> "%vsrt%.%%i.3"
                        
                        rem The 'affinity' parameter BITFIELD select the CPU
                        set /a "crun=!cnxt!-1"
                        call :tohex !crun!
                        start "" /d "!mdst!" /low /affinity !hex! /b cmd /c 1^>"%lcpu%.!cnxt!" 2^>^&1 !vexe! !vcmd!
                    )
                )
            )
        )
        
        call :waitall

        rem Duplicate object files if necessary
        if not "!mdup!"=="" (
            set "mdup=!mdup:$[CONF]=%2!"
            if not "!mdup!"=="!mdst!" (
                mkdir "!mdup!" 2>nul
                del "%vsrt%.%%i.6" 1>nul 2>nul
                if not "!mobj!"=="" dir "!mdst!\*.!mobj!" %vdir% >> "%vsrt%.%%i.6"
                if not "!mbin!"=="" dir "!mdst!\*.!mbin!" %vdir% >> "%vsrt%.%%i.6"
                if exist "%vsrt%.%%i.6" (
                    sort "%vsrt%.%%i.6" > "%vsrt%.%%i.5"
                    rem Remove already duplicated files
                    findstr /i /v "!mdup!" "%vsrt%.%%i.5" > "%vsrt%.%%i.6"
rem echo mdup=!mdup!
                    echo  Duplicating destination files... %clog%
                    if exist "%vsrt%.%%i.6" for /f %%a in (%vsrt%.%%i.6) do (
rem echo dup=%%a
                        copy %%a "!mdup!" /y 1>nul 2>nul
                    )
                )
            )
        )
        
        rem Output the log file
        if not "!mlog!"=="" (
            set "vcmd=!mlog!"
            call :adaptvcmd "%2" "%2" "!msrc!" "!mdst!" "" && set "mlog=!pcmd!"
            type "!mlog!" %clog%
        )
    )
    echo. %clog%
)
set "mrun="

    call :waitall

:cleanup
    rem Deleting lock files
    del %lcpu%* 1>nul 2>nul
    del %lerr%* 1>nul 2>nul
    del %lvia%* 1>nul 2>nul
    
    rem Deleting source files list, log files, command files, etc...
rem    del %vdst% /s /f /q 2>nul

    rem Expand the relative path of the configuration file
    set "vrel=%~dp2"
    rem Tell user where is the log file
    echo. %clog%
    if not "%vlog%"=="nolog" if not "%vlog%"=="nul" echo Get the %vtxt% log into !vlog:%vrel%=.\! !

    rem Gogo gadget au poing
    goto end

:info
    echo Perform a source code action
    echo Usage : makeit "cmd" "make_file" ["exclude_file"] ["log_file"/"nolog"]
    echo Store the result in a log file (default is ".\'cmd'.log")
    echo.
    echo Param = cmd : all      - do "clean" to "run"
    echo Param = cmd : partial  - do "clean" to "flash" (no "run")
    echo Param = cmd : rebuild  - do "clean" to "link" (no "flash" and "run")
    echo Param = cmd : quick    - do "compile" to "run" (no "clean)
    echo Param = cmd : build    - do "compile" and "link" (with pre/post build)
    echo Param = cmd : clean    - clean destination folder from old files
    echo Param = cmd : assemble - assemble ASM_EXT minus ASM_EXC files
    echo Param = cmd : compile  - compile CPP_EXT minus CPP_EXC files (pre build)
    echo Param = cmd : link     - link LNK_EXT files into LNK_OBJ (post build)
    echo Param = cmd : flash    - flash LNK_BIN file using default parameters
    echo Param = cmd : run      - launch the selected debugger executable
    echo Param = cmd : map      - perform mapping analysis
    echo Param = make_file : the file that contain the rules
    echo Param = [exclude_path] : a text file which contains paths to exclude
    echo Param = [log_file] : name of a log file to produce, "nolog" for nul

:end
    echo ------------------------------------------------------------------------------- %clog%

    rem Open log file in default application if "quick" build
    if "%1"=="quick" if not "%vlog%"=="nolog" start "" "%vlog%"
goto :eof

:waitall
    rem Wait remaining cpu to unlock
    ping /n 2 ::1 1>nul 2>nul
    for %%l in ("%lcpu%*") do (
        rem Include remaining logs into the stream
        type "%%l" %clog%
        (call ) 9>"%%l" || goto :waitall
    ) 2>nul
goto :eof

:waitcpu
    rem Don't try to understand this, I was on coke... cake, I was on cake. It's not a lie!
    for /l %%c in (%cmin%,1,!mcpu!) do (
        if not defined cexe%%c if exist "%lcpu%.%%c" (
            rem Include current log into the stream
            type "%lcpu%.%%c" %clog%
            if defined mrun (
                set /a cnxt=%%c
                exit /b
            )
            set /a "cend+=1"
            set /a "cexe%%c=1"
        ) 9>>"%lcpu%.%%c"
    ) 2>nul

    if %cend% lss %csrt% (
        ping /n 1 ::1 1>nul 2>nul
        goto :waitcpu
    )
goto :eof
  
:tohex
    rem Return the hexadecimal representation of a shifted bit
    set /a "dec=1<<%1"
    set "hex="
    set "map=0123456789ABCDEF"
    rem Set the length of the string
    set "len=4"
    for /L %%n in (1,1,%len%) do (
        set /a "d=dec&15,dec>>=4"
        rem Look in the hex table for the right character
        for %%m in (!d!) do set "hex=!map:~%%m,1!!hex!"
    )
goto :eof

:expandpath
    rem Poor-man's full-path variable expansion
    set "pexp=%~f1"
goto :eof

:cleanpath
    set "pcln="
    if not "%1"=="" if not "%1"=="""" (
        set "pcln=%~1"
        rem Change slashes
        set "pcln=!pcln:/=\!"
        rem Remove last backslash
        if "!pcln:~-1!"=="\" set "pcln=!pcln:~0,-1!"
    )
goto :eof

:cleanvcmd
    set "pcmd=!vcmd!"
    set "pcmd=!pcmd: " =" !"
    for /l %%l in (1,1,2) do set "pcmd=!pcmd:  = !"
    for /l %%l in (1,1,2) do if "!pcmd:~-1!"==" " set "pcmd=!pcmd:~0,-1!"
    for /l %%l in (1,1,2) do if "!pcmd:~0,1!"==" " set "pcmd=!pcmd:~1!"
goto :eof

:adaptvcmd
    rem Replace defined tags with parameters
    rem %1 : configuration
    rem %2 : file
    rem %3 : source
    rem %4 : relative
    rem %5 : list
    rem When a command includes spaces and/or double quotes, it gets exploded
    rem That's why I process the !vcmd! variable directly
    set "pcmd=!vcmd!"
    set "pcmd=!pcmd:$[CONF]=%~1!"
    set "pcmd=!pcmd:$[THIS]=%~2!"
    set "pcmd=!pcmd:$[PATH]=%~dp2!"
    set "pcmd=!pcmd:$[NAME]=%~n2!"
    set "pcmd=!pcmd:$[EXT]=%~x2!"
    set "pcmd=!pcmd:$[FILE]=%~nx2!"
    set "pcmd=!pcmd:$[ATTR]=%~a2!"
    set "pcmd=!pcmd:$[TIME]=%~t2!"
    set "pcmd=!pcmd:$[SIZE]=%~z2!"
    set "pcmd=!pcmd:$[LOC_SRC]=%~3!"
    set "pcmd=!pcmd:$[LOC_DST]=%~4!"
    set "pcmd=!pcmd:$[LIST]=%~5!"
    set "pcmd=!pcmd:""="!"
goto :eof

rem Debug arrow to detect where problems are located
rem Just move this arrow around the problem 
rem Surround the detected sections with the numbered lines

    echo Debug-------1 \
    echo Debug  -------2 \
    echo Debug    -------3 \
    echo Debug      -------4 \
    echo Debug      -------4 /
    echo Debug    -------3 /
    echo Debug  -------2 /
    echo Debug-------1 /
