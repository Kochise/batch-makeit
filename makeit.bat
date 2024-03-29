@echo off && setlocal EnableDelayedExpansion
if "%~dp0" neq "!guid!\" (set "guid=%tmp%\crlf.%~nx0.%~z0" & set "cd=%~dp0" & (if not exist "!guid!\%~nx0" (mkdir "!guid!" 2>nul & find "" /v<"%~f0" >"!guid!\%~nx0")) & call "!guid!\%~nx0" %* & rmdir /s /q "!guid!" 2>nul & exit /b) else (if "%cd:~-1%"=="\" set "cd=%cd:~0,-1%")

set "cver=2.9.5"

rem Extended Batch Makefile by David KOCH v%cver% 2013-2023
rem Command : makeit cmd "make_file" ["exclude_file.txt"] ["log_file"/"nolog"]
rem Argument	%0	%1		%2			%3					%4
rem					|		|			|					|
rem					|		|			|	specify a logfile, or if
rem					|		|			|	empty, will create one by
rem					|		|			|	default, unless "nolog"
rem					|		|			|	is used instead (useful
rem					|		|			|	when running under the
rem					|		|			|	Jenkins framework)
rem					|		|			|
rem					|		|	optional text file with one line per
rem					|		|	exclusion, 'findstr' format: just a part
rem					|		|	of the path and/or file name to be found
rem					|		|	is enough to exclude the whole line
rem					|		|
rem					|	make_file[.txt] is the configuration file
rem					|
rem				all		 - do "clean" to "run"
rem				partial	 - do "clean" to "flash" (no "run")
rem				rebuild	 - do "clean" to "link" (no "flash" and "run")
rem				quick	 - do "compile" to "run" (no "clean)
rem				build	 - do "compile" and "link" (with pre/post build)
rem				clean	 - clean destination folder from old files
rem				assemble - assemble ASM_EXT minus ASM_EXC files
rem				compile	 - compile CPP_EXT minus CPP_EXC files (pre build)
rem				link	 - link LNK_EXT files into LNK_OBJ (post build)
rem				flash	 - flash LNK_BIN file using default parameters
rem				run		 - launch the selected debugger executable
rem				map		 - perform mapping analysis

rem Todo list (Oh No! More Lemmings)
rem Correct error management through batch files for multi-core compilation
rem Try to synchronize output execution result with target execution message
rem Find the reason why it is so slow between steps, check for useless loops
rem Convert to native, lua, shell, whatever less bogus and snappier execution time
rem Praise the Lords...

rem Notes for maintenance
rem If something breaks, check the variables used for the 8191 bytes limit bug
rem Variable resolving is very fragile, stupid nasty delayed expansion stuff
rem 'findstr' sucks ass as hell, /r is buggy, first string should start with \
rem 'xcopy' is bug ridden, but so is 'robocopy', hence not much luck there
rem And these damn paths with a space into them, not easy to collate them

rem http://www.robvanderwoude.com/shorts.php
rem http://waynes-world-it.blogspot.fr/
rem http://ss64.com/nt/
rem http://ss64.com/nt/syntax-args.html

rem Save code page then set it to utf-8 (/!\ this file MUST be in utf-8)
for /f "tokens=2 delims=:." %%x in ('chcp') do set cp=%%x
chcp 65001>nul
REM	chcp 1252>nul

rem Change default helpers
set "quiet=1>nul 2>nul"
set "fquiet=/f /q 1>nul 2>nul"

REM	@set "odir=%cd%"
REM	cd /d %~dp0

rem Set this variable to get some fancy debug output
set "vdeb="

rem Set this variable to get more iterative pass
set /a "vpas=4"

rem Convert current time and date in a more usable format
for /f "tokens=1,2,3,4 delims=/ " %%a in ("%date%") do set "fdate=%%d%%c%%b%%a"
for /f "tokens=1,2,3,4 delims=:," %%a in ("%time%") do set "ftime=%%a%%b%%c%%d"
set "fdate=%fdate: =0%"
set "ftime=%ftime: =0%"

rem Call info
if "%1"=="" goto info
if "%1"=="/?" goto info
if "%1"=="-h" goto info
if "%1"=="--help" goto info
if "%1"=="--info" goto info
if "%1"=="-man" goto info
if "%1"=="--manual" goto info
if "%1"=="-rtfm" goto info
if "%1"=="-wat" goto info

rem Set command variables
set "vtxt=%1ing"
if "%1"=="all" set "vtxt=doing all"
if "%1"=="partial" set "vtxt=partial (no run)"
if "%1"=="rebuild" set "vtxt=rebuilding"
if "%1"=="quick" set "vtxt=quick build"
if "%1"=="build" set "vtxt=building"
if "%1"=="clean" set "vtxt=cleaning"
if "%1"=="assemble" set "vtxt=assembling"
if "%1"=="compile" set "vtxt=compiling"
if "%1"=="link" set "vtxt=linking"
if "%1"=="flash" set "vtxt=flashing"
if "%1"=="run" set "vtxt=running"
if "%1"=="map" set "vtxt=mapping"

rem Set command prefix sequence (default list)
if "%1"=="all" set "vpre=CLN_ ASM_ PRE_ CPP_ LNK_ PST_ FLH_ RUN_"
if "%1"=="partial" set "vpre=CLN_ ASM_ PRE_ CPP_ LNK_ PST_ FLH_"
if "%1"=="rebuild" set "vpre=CLN_ ASM_ PRE_ CPP_ LNK_ PST_"
if "%1"=="quick" set "vpre=PRE_ CPP_ LNK_ PST_ FLH_ RUN_"
if "%1"=="fast" set "vpre=PRE_ CPP_ LNK_ PST_ FLH_"
if "%1"=="build" set "vpre=PRE_ CPP_ LNK_ PST_"
if "%1"=="clean" set "vpre=CLN_"
if "%1"=="assemble" set "vpre=ASM_"
if "%1"=="compile" set "vpre=PRE_ CPP_"
if "%1"=="link" set "vpre=LNK_ PST_"
if "%1"=="flash" set "vpre=FLH_"
if "%1"=="run" set "vpre=RUN_"
if "%1"=="map" set "vpre=MAP_"

rem Set argument list (currently supported suffixes)
set "vvia=ARG DEF INC LIB TMP"
set "varg=EXE PWD SEP SRC DST MOV RPT CPU CLI VIA LOG DBG DEP OBJ LNK BIN DUP EXT EXC BUT DEL XPY CPY %vvia% REM"

rem Set default variables
set "verr=0"
set "vrel=%~dp2"
set "vsrc=%~f2"
if not exist "%vsrc%" (
	set "vsrc=%~f2.txt"
)
set "vloc=%~dp2"
set "vdst=%vloc%%fdate%_%ftime%_%2_%1"
set "vlnk=%vdst%\%2.link"
set "vslv=%vdst%\%2.solv"
set "vsrt=%vdst%\%2.sort"
set "vdir=/B /A:-D /ON /S"

rem Set default tags (GCC style), change them with LOC_SEP, LOC_DEF and LOC_INC
set "csep="
set "cdef=-D"
set "cinc=-I"

rem Create the folder (because Windows cannot do it automatically when writing a file)
mkdir "%vdst%" 2>nul

rem Logging management
set "vlog=nolog"
if not "%3"=="nolog" (
	rem Get excluded paths file
	if not "%3"=="" set "vexc=%~f3"

	rem Set specified or default log file
	if not "%4"=="nolog" if not "%4"=="" (
		set "vlog=%~f4"
	) else (
		set "vlog=%vdst%\%1.log"
	)
)

rem Set logging command
if not "%vlog%"=="nolog" (
	set "clog=> %vdst%\%2.line & type %vdst%\%2.line>> %vlog% & type %vdst%\%2.line"
)

rem Set the CPU scheduler parameters
set /a "cmin=1"
set /a "cmax=%NUMBER_OF_PROCESSORS%-(1-%cmin%)"

rem Set the CPU lock files
set "lbat=%vdst%\%2.lock.bat"
set "lcpu=%vdst%\%2.lock.cpu"
set "lerr=%vdst%\%2.lock.err"
set "lvia=%vdst%\%2.lock.via"

rem Create the error logger batch
for /l %%c in (%cmin%,1,%cmax%) do (
	echo ^@echo off>>"%lbat%.%%c.bat"
REM	echo echo 1=%%~1>>"%lbat%.%%c.bat"
REM	echo echo 2=%%~2>>"%lbat%.%%c.bat"
REM	echo echo 3=%%~3>>"%lbat%.%%c.bat"
REM	echo echo 4=%%~4>>"%lbat%.%%c.bat"
REM	echo echo 5=%%~5>>"%lbat%.%%c.bat"
REM	echo echo 6=%%~6>>"%lbat%.%%c.bat"
REM	echo echo 7=%%~7>>"%lbat%.%%c.bat"
REM	echo echo 8=%%~8>>"%lbat%.%%c.bat"
REM	echo echo 9=%%~9>>"%lbat%.%%c.bat"
REM	echo echo *=%%*>>"%lbat%.%%c.bat"
	echo %%*>>"%lbat%.%%c.bat"
	echo if not errorlevel 0 echo "%%errorlevel%%"^> %lerr%.%%c>>"%lbat%.%%c.bat"
)

rem Print the header
echo --- Extended Batch Makefile v%cver% - %fdate% @ %ftime% ------------------- %clog%
echo Cd : %CD% %clog%
echo Makeit cmd : %1 %clog%
echo Makeit cnf : !vsrc:%vrel%=.\! %clog%
if not "%vexc%"=="" echo Makeit exc : !vexc:%vrel%=.\! %clog%
echo Makeit log : !vlog:%vrel%=.\! %clog%
echo --- %vtxt% ------------------------------------------------------------- %clog%
echo:%clog%

rem Start the job
echo Parsing make file... %clog%

rem Resolve include files
echo Resolving static include files... %clog%

rem Multi-level include, aggregate files up to 20% cooler
copy /y "%vsrc%" "%vslv%.0" %quiet%

set "vtag=INCLUDE="

rem Three levels include (if more, you should question yourself)
for /l %%h in (1,1,%vpas%) do (
REM	echo   Inclusion level %%h/%vpas% %clog%
	if exist "%vslv%.0" (
		rem Find INCLUDE tags
		findstr /b "%vtag%" "%vslv%.0">"%vslv%.1"
		if "0"=="!errorlevel!" (
			rem Save original file before recreation
			copy /y "%vslv%.0" "%vslv%.3" %quiet%
			del "%vslv%.0" %fquiet%

			rem Read original file (include blank lines through 'findstr')
			for /f "tokens=1* delims=:" %%i in ('findstr /n "^" "%vslv%.3"') do (
				rem Read second token from 'findstr' ('%%i:%%j' = 'linenum:string')
				if not "%%j"=="" (
					set "vinc=%%j"
REM					echo vinc="!vinc:~0,8!" %clog%

					if "%vtag%"=="!vinc:~0,8!" (
						rem Get the name of the file to include (remove tag)
						set "vinc=!vinc:~8!"
						call :expandpath "!vinc!" && set "vinc=!pexp!"
						rem Inject include file
						type !vinc!>>"%vslv%.0"
					) else (
						rem Inject old line
						echo %%j>>"%vslv%.0"
					)
				) else (
					rem Inject old line
					echo:>>"%vslv%.0"
				)
			)
		)
	)
)

set "vtag=LOC_DST="

rem Solve destination path with current configuration
findstr /b "%vtag%" "%vslv%.0">"%vslv%.1"
if "0"=="!errorlevel!" (
	rem Adding config name to destination path (if defined)
	echo Adding config name to LOC_DST path... %clog%

	rem Save original file before recreation
	copy /y "%vslv%.0" "%vslv%.3" %quiet%
	del "%vslv%.0" %fquiet%

	rem Read original file (include blank lines through 'findstr')
	for /f "tokens=1* delims=:" %%i in ('findstr /n "^" "%vslv%.3"') do (
		rem Read second token from 'findstr' ('%%i:%%j' = 'linenum:string')
		if not "%%j"=="" (
			set "vinc=%%j"
REM			echo vinc="!vinc:~0,8!" %clog%

			if "LOC_DST="=="!vinc:~0,8!" (
REM				set "vinc=!vinc:~8!"
REM				call :expandpath "!vinc!" && set "vinc=!pexp!"
REM				echo vinc="!vinc!"
				rem Add configuration to the LOC_DST path
				echo %%j\%2>>"%vslv%.0"
			) else (
				rem Inject old line
				echo %%j>>"%vslv%.0"
			)
		) else (
			rem Inject old line
			echo:>>"%vslv%.0"
		)
	)
)

rem Quit (for debug)
REM	goto :eof

rem Find custom sequence name if defined (from command line parameter)
for /f "tokens=2 delims==" %%i in ('findstr "^%1=" %vslv%.0') do (
	rem Get sequence tags
	set "vpre=%%i"
)

rem Remove location tag
set "vpre=%vpre% "
set "vpre=%vpre:LOC_ =%"
rem Remove trailing blank
if "%vpre:~0,1%"==" " set "vpre=!vpre:~1!"
rem Process location tag first
set "vpre=LOC_ %vpre%"

rem Resolve ${...} variables with their corresponding parameter
echo Resolving static ${path}, ${CONF} and ${CD}... %clog%

set "vtag=${.*}"
REM	echo vtag="%vtag%" %clog%

rem Multipass (c) Leeloo Dallas
for /l %%h in (1,1,%vpas%) do (
REM	echo   Resolution level %%h/%vpas% %clog%
	rem Beware: this only resolve paths, it CANNOT be used for argument replacement
	rem Because: how can you differentiate a file (to expand) from an argument?
	if exist "%vslv%.0" (
		rem Find unsolved argument to process
		findstr /n "%vtag%" "%vslv%.0">"%vslv%.1"
		if "0"=="!errorlevel!" (
			rem Save original file before recreation
			copy /y "%vslv%.0" "%vslv%.3" %quiet%
			del "%vslv%.0" %fquiet%

			rem Start line number
			set /a "adst=0"

			rem Read unsolved argument to process (include blank lines through 'findstr')
			for /f "tokens=1* delims=:" %%i in (%vslv%.1) do (
				rem Read second token from 'findstr' ('%%i:%%j' = 'linenum:string')
				if not "%%j"=="" (
if not "!vdeb!"=="" echo --read line num - %%i
if not "!vdeb!"=="" echo --read line str - %%j
					rem Copy previous lines
					call :copyline !adst! %%i "%vslv%.3" "%vslv%.0"

					rem Each token found
					for /f "tokens=2 delims={}" %%k in ("%%j") do (
						rem Read second token ('_{%%k}%%l' = '_{tag}_')

						rem Get complete ${.*} line
						set "vtmp=%%j"
						rem Replace conf token with current 'conf' parameter
						set "vtmp=!vtmp:${CONF}=%2!"
						rem Replace cd token with current directory
						set "vtmp=!vtmp:${CD}=%vrel%!"

						rem Find first line
						call :findline "tokens=1,* delims==" "^%%k=" "%vslv%.3"

						rem Look for the resolved parameter
						if not "!plin!"=="" (
							rem Check if it can be solved as a path
							call :expandpath "!plin!" && set "vinc=!pexp!"
							set "vinc=!vinc:%vrel%=!"
if not "!vdeb!"=="" echo   --read line plin - !plin!
if not "!vdeb!"=="" echo   --read line pexp - !pexp!
if not "!vdeb!"=="" echo   --read line vinc - !vinc!

							rem If not solved into current path
							if "!vinc!"=="!plin!" (
								rem Replace token with target value
								call set "vtmp=%%vtmp:${%%k}=!plin!%%"
							) else (
								rem Replace token with resolved and expanded path (~f) parameter
								call set "vtmp=%%vtmp:${%%k}=!pexp!%%"
								rem Ensure backslash in path (because 'dir' produces such)
REM								set "vtmp=!vtmp:/=\!"
							)
						)

if not "!vdeb!"=="" echo   --read line vtmp - !vtmp!
						rem Store the resolved argument for the next pass
						echo !vtmp!>>"%vslv%.0"
					)
				) else (
					rem Inject old line
					echo:>>"%vslv%.0"
				)

				rem Next line number
				set /a "adst=%%i"
			)

			rem Copy remaining lines
			call :copyline !adst! 0 "%vslv%.3" "%vslv%.0"
		)
	)
)

rem Quit (for debug)
REM	goto :eof

rem You can compare "%vslv%.0" with "%vslv%.3" to check the variable expansion
REM	sort "%vslv%.0">"%vsrt%.0"
copy /y "%vslv%.0" "%vsrt%.0" %quiet%

rem Parse and execute commands
echo Executing make file... %clog%

rem And now the show begins
set "mrun=1"

rem For each command prefix
for %%i in (%vpre%) do (
	if not "%%i"=="" (
		set "vexe="

		set "mrem="
		set "mexe="
		set "mpwd="
		set "msep="
		set "msrc="
		set "mdst="
		set "mmov="
		set "mrpt="

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
		set "mbut="
		set "mdel="
		set "mxpy="
		set "mcpy="

		set "marg="
		set "mdef="
		set "minc="
		set "mlib="
		set "mtmp="

		rem Each argument suffix (don't forget to update the 'varg' list above)
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

				rem Try to resolve embedded path (tricky if inside an argument)
REM				set "vtmp=!vtmp:/=\!"
				if not "!vtmp!"=="!vtmp:..\=!" (
REM					call :expandpath "!vtmp!" && set "vtmp=!pexp!"
				)

				rem Try to expand folder
if "%vdeb%"=="TOTO" if not "%%j"=="SRC" if not "%%j"=="DST" if not "%%j"=="INC" (
					rem Inverse logic
				) else (
					rem If SRC or DST or INC
					for /f "delims=!" %%l in (!vtmp!) do (
						set "vexp=%%~fl"
						if not "!vexp!"=="" set "vtmp=!vexp!"
					)
				)

				rem Remove trailing and leading spaces
				for /l %%l in (1,1,2) do if "!vtmp:~-1!"==" " set "vtmp=!vtmp:~0,-1!"
				for /l %%l in (1,1,2) do if "!vtmp:~0,1!"==" " set "vtmp=!vtmp:~1!"

if not "!vdeb!"==""	echo i/j/vtmp=%%i/%%j/!vtmp!

				if "%%j"=="REM" set "mrem=!vtmp!"
				if "%%j"=="EXE" set "mexe=!vtmp!"
				if "%%j"=="PWD" set "mpwd=!vtmp!"
				if "%%j"=="SEP" set "msep=!vtmp!"
				if "%%j"=="SRC" set "msrc=!vtmp!"
				if "%%j"=="DST" set "mdst=!vtmp!"
				if "%%j"=="MOV" set "mmov=!vtmp!"
				if "%%j"=="RPT" set "mrpt=!vtmp!"

				if "%%j"=="CPU" set "mcpu=!vtmp!"

				if "%%j"=="CLI" set "mcli=!vtmp!"
				if "%%j"=="VIA" (
					rem If VIA tag previously empty, flush arguments
					if "!mvia!"=="" if not "!vtmp!"=="" (
						if not "!marg!"=="" call :writevar "!marg!" "%vsrt%.%%i.via.arg"
						if not "!mdef!"=="" call :writevar "!mdef!" "%vsrt%.%%i.via.def"
						if not "!minc!"=="" call :writevar "!minc!" "%vsrt%.%%i.via.inc"
						if not "!mlib!"=="" call :writevar "!mlib!" "%vsrt%.%%i.via.lib"
						if not "!mtmp!"=="" call :writevar "!mtmp!" "%vsrt%.%%i.via.tmp"
					)
					set "mvia=!vtmp!"
				)
				if "%%j"=="LOG" set "mlog=!vtmp!"
				if "%%j"=="DBG" set "mdbg=!vtmp!"
				if "%%j"=="DEP" set "mdep=!vtmp!"
				if "%%j"=="OBJ" set "mobj=!vtmp!"
				if "%%j"=="LNK" set "mlnk=!vtmp!"
				if "%%j"=="BIN" set "mbin=!vtmp!"
				if "%%j"=="DUP" set "mdup=!vtmp!"

				rem File operation specific arguments (accumulated)
				if "%%j"=="EXT" set "mext=!mext! !vtmp!"
				if "%%j"=="EXC" set "mexc=!mexc! !vtmp!"
				if "%%j"=="BUT" set "mbut=!mbut! !vtmp!"
				if "%%j"=="DEL" set "mdel=!mdel! !vtmp!"
				if "%%j"=="XPY" set "mxpy=!mxpy! !vtmp!"
				if "%%j"=="CPY" set "mcpy=!mcpy! !vtmp!"

				if "%%i"=="LOC_" (
					rem Change default tags
					if "%%j"=="SEP" set "csep=!vtmp!"
					if "%%j"=="DEF" set "cdef=!vtmp!"
					if "%%j"=="INC" set "cinc=!vtmp!"
				) else (
					rem Via-method compatible arguments (accumulated)
					if "!mvia!"=="" (
						if "%%j"=="ARG" set "marg=!marg! !vtmp!"
						if "%%j"=="DEF" set "mdef=!mdef! !cdef!!vtmp!"
						if "%%j"=="INC" (
							rem Check if spaces in path
							if "!vtmp!"=="!vtmp: =!" (
								set "minc=!minc! !cinc!!vtmp!"
							) else (
								set "minc=!minc! !cinc!^"!vtmp!^""
							)
						)
						if "%%j"=="LIB" set "mlib=!mlib! !vtmp!"
						if "%%j"=="TMP" set "mtmp=!mtmp! !vtmp!"
					) else (
						if "%%j"=="ARG" echo !vtmp!>>"%vsrt%.%%i.via.arg"
						if "%%j"=="DEF" (
							set "mdef=!cdef!!vtmp!"
							echo !mdef!>>"%vsrt%.%%i.via.def"
						)
						if "%%j"=="INC" (
							rem Check if spaces in path
							if "!vtmp!"=="!vtmp: =!" (
								set "minc=!cinc!!vtmp!"
							) else (
								set "minc=!cinc!^"!vtmp!^""
							)
							echo !minc!>>"%vsrt%.%%i.via.inc"
						)
						if "%%j"=="LIB" echo !vtmp!>>"%vsrt%.%%i.via.lib"
						if "%%j"=="TMP" echo !vtmp!>>"%vsrt%.%%i.via.tmp"
					)
				)
			)
		)

		rem Set separator
		if "!msep!"=="" set "msep=!csep!"

		set /a "narg=0"
		set /a "ndef=0"
		set /a "ninc=0"
		set /a "nlib=0"
		set /a "ntmp=0"

		rem Check Via-method compatible arguments
		for %%j in (%vvia%) do (
			if "!mvia!"=="" (
				if "%%j"=="ARG" if not "!marg!"=="" if not "!marg!"=="!marg:$[=!" set /a "narg=1"
				if "%%j"=="DEF" if not "!mdef!"=="" if not "!mdef!"=="!mdef:$[=!" set /a "ndef=1"
				if "%%j"=="INC" if not "!minc!"=="" if not "!minc!"=="!minc:$[=!" set /a "ninc=1"
				if "%%j"=="LIB" if not "!mlib!"=="" if not "!mlib!"=="!mlib:$[=!" set /a "nlib=1"
				if "%%j"=="TMP" if not "!mtmp!"=="" if not "!mtmp!"=="!mtmp:$[=!" set /a "ntmp=1"
			) else (
				set "nvia="

				Rem Select file extension
				if "%%j"=="ARG" set "nvia=arg"
				if "%%j"=="DEF" set "nvia=def"
				if "%%j"=="INC" set "nvia=inc"
				if "%%j"=="LIB" set "nvia=lib"
				if "%%j"=="TMP" set "nvia=tmp"

				rem Check if file is resolvable
				if exist "%vsrt%.%%i.via.!nvia!" (
					findstr "$[" "%vsrt%.%%i.via.!nvia!">"%vsrt%.%%i.via.!nvia!.1"
					if exist "%vsrt%.%%i.via.!nvia!.1" (
						call :expandsize "%vsrt%.%%i.via.!nvia!.1"
						if not "!pexp!"=="0" (
							rem Remember which file is resolvable
							if "%%j"=="ARG" set /a "narg=1"
							if "%%j"=="DEF" set /a "ndef=1"
							if "%%j"=="INC" set /a "ninc=1"
							if "%%j"=="LIB" set /a "nlib=1"
							if "%%j"=="TMP" set /a "ntmp=1"
						)
						del "%vsrt%.%%i.via.!nvia!.1" %fquiet%
					)
				)
			)
		)

		rem Adapt exclusion list
		if not "!mexc!"=="" (
			rem Remove double (back)slash before doubling them again
REM			for /l %%l in (1,1,5) do set "mexc=!mexc://=/!"
REM			for /l %%l in (1,1,5) do set "mexc=!mexc:\\=\!"
			rem Transform everything into slash
REM			set "mexc=!mexc:\=/!"
			rem Transform everything into backslash
REM			set "mexc=!mexc:/=\!"
			rem Double backslash for 'findstr'
			set "mexc=!mexc:\=\\!"
		)

		rem Adapt exclusion list
		if not "!mbut!"=="" (
			rem Remove double (back)slash before doubling them again
REM			for /l %%l in (1,1,5) do set "mbut=!mbut://=/!"
REM			for /l %%l in (1,1,5) do set "mbut=!mbut:\\=\!"
			rem Transform everything into slash
REM			set "mbut=!mbut:\=/!"
			rem Transform everything into backslash
REM			set "mbut=!mbut:/=\!"
			rem Double backslash for 'findstr'
			set "mbut=!mbut:\=\\!"
		)

		rem If executable path is empty, use current one
		if "!mpwd!"=="" set "mpwd=!mdst!"
		if "!mpwd!"=="" set "mpwd=%CD%"

		rem Remove the ending backslash of path
		call :cleanpath "!mexe!" && set "mexe=!pcln!"
		call :cleanpath "!mpwd!" && set "mpwd=!pcln!"
		call :cleanpath "!msrc!" && set "msrc=!pcln!"
		call :cleanpath "!mdst!" && set "mdst=!pcln!"
		call :cleanpath "!mmov!" && set "mmov=!pcln!"
		call :cleanpath "!mrpt!" && set "mrpt=!pcln!"
		call :cleanpath "!mdup!" && set "mdup=!pcln!"

		rem Correct the CPU max
		if "!mcpu!"=="" set /a "mcpu=0"
		if "!mcpu:~-1!"=="%%" (
			rem CPU ratio
			set /a "mcpu=!mcpu:~0,-1!"
			set /a "mcpu=!mcpu!*%cmax%/100"
		)
		if !mcpu! equ 0 (
			rem No CPU
			set "mcpu=%cmax%"
		) else (
			rem CPU number
			if !mcpu! gtr 0 (
				rem Positive
				set /a "mcpu=!mcpu!-(1-%cmin%)"
			) else (
				rem Negative
				set /a "mcpu=%cmax%+!mcpu!"
			)
		)
		if !mcpu! gtr %cmax% set /a "mcpu=%cmax%"

		rem If no source path, switch to destination path
		if "!msrc!"=="" if not "!mdst!"=="" set "msrc=!mdst!"

		rem Command prefix to execute (default list)
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
			if "%%i"=="ELF_" echo Now dumping assembly... %clog%
			if "%%i"=="COV_" echo Now generating gcov... %clog%
			if "%%i"=="COB_" echo Now converting in cobertura format... %clog%
			if "%%i"=="COP_" echo Now cleaning coverage... %clog%

			rem Command remark to print
			if not "!mrem!"=="" (
				echo --!mrem! %clog%
			)
		) else (
REM			echo  ERROR : No executable file defined for "%%i" ! %clog%
		)

		rem /!\ Do *NOT* link these two 'not "!mexe!"==""' sections -> BUG

if not "!vdeb!"==""	echo mexe=!mexe!
if not "!vdeb!"==""	echo msrc=!msrc!
if not "!vdeb!"==""	echo mdst=!mdst!

			rem Beware buddies, "LOC_" always *HAVE* to be the first tag in %vpre%
			if "%%i"=="LOC_" (
				rem Keep the build path of binaries and build report folder
				set "mloc=!mexe!"
				set "vrpt=!mrpt!"
if not "!vdeb!"=="" echo mloc=!mloc!
if not "!vdeb!"=="" echo vrpt=!vrpt!
		) else (
			if not "!mexe!"=="" if "!msrc!"=="" (
				echo  ERROR : Neither source nor destination path for "%%i" ! %clog%
			) else (
				rem Yeah, because if the path doesn't exist, file creation fails
				if not "!mdst!"=="" (
					rem If not same destination directory as previous step
					if not "!mdst!"=="!mold!" (
						echo  Creating destination folder... %clog%
						rem Create root destination directory
						mkdir "!mdst!" 2>nul
						set "mold=!mdst!"

						rem If not self directory
						if not "!msrc!"=="!mdst!" (
							echo  Copying source folder tree... %clog%
REM							xcopy "!msrc!" "!mdst!" /e /t /y /q %quiet%
							rem Xcopy can produce an 'insufficient memory' error
							robocopy "!msrc!" "!mdst!" /e /xf * %quiet%
						)
					)

					rem Delete specific files from destination folder
					for /l %%l in (1,1,1) do (
						if "!mdel:~0,1!"==" " set "mdel=!mdel:~1!"
					)

					if not "!mdel!"=="" (
if not "!vdeb!"=="" echo mdel=!mdel!
						echo  Deleting old destination files... %clog%
						for %%j in (!mdel!) do (
if not "!vdeb!"=="" echo del=!mdst!\*.%%j
							del "!mdst!\*.%%j" /s %fquiet%
						)
					)

					rem Xcopy specific files into destination folder
					for /l %%l in (1,1,1) do (
						if "!mxpy:~0,1!"==" " set "mxpy=!mxpy:~1!"
					)

					if not "!mxpy!"=="" (
if not "!vdeb!"=="" echo mxpy=!mxpy!
						echo  Xcopying source files... %clog%
						for %%j in (!mxpy!) do (
if not "!vdeb!"=="" echo xcopy=!msrc!\*.%%j
							xcopy "!msrc!\*.%%j" "!mdst!" /s /i /y /q %quiet%
REM							robocopy "!msrc!\*.%%j" "!mdst!" /s %quiet%
						)
					)

					rem Copy the files into destination folder
					for /l %%l in (1,1,1) do (
						if "!mcpy:~0,1!"==" " set "mcpy=!mcpy:~1!"
					)

					if not "!mcpy!"=="" (
						echo  Copying specific files... %clog%
						set "vcmd=!mcpy!"
						call :adaptvcmd "%2" "%2" "!msrc!" "!mdst!" "!mmov!" "" && set "mcpy=!pcmd!"
if not "!vdeb!"=="" echo mcpy=!mcpy!
						for %%j in (!mcpy!) do (
							if exist "%%j" copy /y "%%j" "!mdst!" %quiet%
						)
					)

					if not "!mmov!"=="" (
						echo  Creating move folder... %clog%
						mkdir "!mmov!" 2>nul
						if not "!msrc!"=="!mmov!" (
							robocopy "!msrc!" "!mmov!" /e /xf * %quiet%
						)
					)
				)

				rem Construct the argument chain
				set "vtmp="
				if not "!mcli!"=="" for %%j in (!mcli!) do (
					if "%%j"=="LOC" (
if not "!vdeb!"=="" echo "mloc"\vexe2="!mloc!"\!vexe!
						set "vexe=!vexe!"!mloc!\"
					)
					if "%%j"=="EXE" (
						if "!mexe:~1,1!"==":" (
							rem If executable seems absolute, expand and keep it as-is
							call :expandpath "!mexe!" && set "vexe=!pexp!"
						) else (
if not "!vdeb!"=="" echo "vexe3"\mexe="!vexe!"\!mexe!
							set "vexe=!vexe!!mexe!"
						)
						rem If command line started with a quote (note the hideous syntax)
						if "!vexe:~0,1!"==^"^"^" set "vexe=!vexe!^""
if not "!vdeb!"=="" echo "vexe4"="!vexe!"
REM						set "vexe=!vexe! "
					)

					if "%%j"=="SRC" set "vtmp=!vtmp!!msrc! "
					if "%%j"=="DST" set "vtmp=!vtmp!!mdst! "

					if "%%j"=="DBG" set "vtmp=!vtmp!!mdbg! "
					if "%%j"=="DEP" set "vtmp=!vtmp!!mdep! "
					if "%%j"=="OBJ" set "vtmp=!vtmp!!mobj! "
					if "%%j"=="BIN" set "vtmp=!vtmp!!mbin! "

					rem File operation specific arguments
					if "%%j"=="EXT" set "vtmp=!vtmp!^"$[THIS]^" "
					if "%%j"=="EXC" set "vtmp=!vtmp!!mexc! "
					if "%%j"=="BUT" set "vtmp=!vtmp!!mbut! "
					if "%%j"=="LST" set "vtmp=!vtmp!$[LIST] "

					rem Via-method compatible arguments
					if "!mvia!"=="" (
						if "%%j"=="ARG" set "vtmp=!vtmp!!marg! "
						if "%%j"=="DEF" set "vtmp=!vtmp!!mdef! "
						if "%%j"=="INC" set "vtmp=!vtmp!!minc! "
						if "%%j"=="LIB" set "vtmp=!vtmp!!mlib! "
						if "%%j"=="TMP" set "vtmp=!vtmp!!mtmp! "
					) else (
REM						if "%%j"=="ARG" type "%vsrt%.%%i.via.arg">>"%vsrt%.%%i.via"
REM						if "%%j"=="DEF" type "%vsrt%.%%i.via.def">>"%vsrt%.%%i.via"
REM						if "%%j"=="INC" type "%vsrt%.%%i.via.inc">>"%vsrt%.%%i.via"
REM						if "%%j"=="LIB" type "%vsrt%.%%i.via.lib">>"%vsrt%.%%i.via"
REM						if "%%j"=="TMP" type "%vsrt%.%%i.via.tmp">>"%vsrt%.%%i.via"
					)
				)

if not "!vdeb!"=="" echo "arg"/vtmp="%%j"/!vtmp!
if not "!vdeb!"=="" echo vexe=!vexe!

				rem Clean up the command line
				if not "!vexe!"=="" set "vcmd=!vexe!" && call :cleanvcmd && set "vexe=!pcmd!"
				if not "!vtmp!"=="" set "vcmd=!vtmp!" && call :cleanvcmd && set "vtmp=!pcmd!"

if not "!vdeb!"=="" echo vexe=!vexe!
if not "!vdeb!"=="" echo vtmp=!vtmp!

				rem Each extension, list files
				if not "!mext!"=="" for %%a in (!mext!) do (
if not "!vdeb!"=="" echo msrc=!msrc!\*.%%a
					dir "!msrc!\*.%%a" %vdir% >>"%vsrt%.%%i.0" 2>nul
				) else (
					rem If no extension, execute at least once (ie. simple batch execution)
					echo:>"%vsrt%.%%i.0" 2>nul
					set "vcmd=$[FILE]"
					call :adaptvcmd "%2" "!vexe!" "!msrc!" "!vrel!" "!mmov!" ""
					echo Running '!pcmd!'...> "%vsrt%.%%i.1" 2>nul
				)

				rem If linker and destination link files list present
				if "%%i"=="LNK_" if not "!mlnk!"=="" if exist %vlnk%.0 (
REM					copy "%vlnk%.0" "%vsrt%.%%i.0" /y %quiet%
					findstr "!mlnk!" "%vlnk%.0">"%vsrt%.%%i.0"
				)

				rem Start anew
				set "vcmd="

if not "!vdeb!"=="" echo   Listing and excluding... %clog%

				rem List real files to process
				set "vlst="
if not "!vdeb!"=="" if not "!mexc!"=="" echo mexc=!mexc!
				if exist %vsrt%.%%i.0 (
					rem The 'findstr' command is buggy, it never excludes only /xxx/
					if "!mexc!"=="" (
						rem Keep all files
						copy "%vsrt%.%%i.0" "%vsrt%.%%i.4" /y %quiet%
					) else (
						rem Remove excluded files (bug: never '/xxx/', at least 'dummy /xxx/')
						findstr /i /v "!mexc!" "%vsrt%.%%i.0">"%vsrt%.%%i.4"
						if not "!mbut!"=="" (
							rem Add anti excluded files
							findstr /i "!mbut!" "%vsrt%.%%i.0">>"%vsrt%.%%i.4"
							rem Sort remaining files
							sort "%vsrt%.%%i.4">"%vsrt%.%%i.5"
REM							copy "%vsrt%.%%i.4" "%vsrt%.%%i.5" /y %quiet%
							rem Remove duplicate lines
							if exist %vsrt%.%%i.5 (
								del "%vsrt%.%%i.4" %fquiet%
								for /f "delims=!" %%a in (%vsrt%.%%i.5) do (
									if not "%vdup%"=="%%a" (
										set "vdup=%%a"
										echo:%%a>>"%vsrt%.%%i.4"
									)
								)
							)
						)
					)

if not "!vdeb!"=="" echo     Listing remaining files... %clog%

					rem List the remaining files
					if exist %vsrt%.%%i.4 (
						rem Apply external excludes
						if not "%vexc%"=="" (
REM							for /f "delims=!" %%a in (%vexc%) do set "mexc=!mexc! %%a"
							findstr /i /v /g:"%vexc%" "%vsrt%.%%i.4">"%vsrt%.%%i.5"
							copy "%vsrt%.%%i.5" "%vsrt%.%%i.4" /y %quiet%
							del "%vsrt%.%%i.5" %fquiet%
						)

						for /f "delims=!" %%a in (%vsrt%.%%i.4) do (
							echo:%%a>>"%vsrt%.%%i.1"
							rem FIXME Beware of files with space in name
							set "vlst=!vlst! %%a"
							rem Resolve file list as being relative to source
							call set "vlst=%%vlst:!msrc!=.%%"
						)
					)

if not "!vdeb!"=="" echo     Remove remaining files... %clog%

					rem Remove the remaining files list
					del "%vsrt%.%%i.4" %fquiet%
REM					if not "!vlst!"=="" echo !vlst! >"%vsrt%.%%i.4"
				)

if not "!vdeb!"=="" echo   File list finished... %clog%

				rem Linking just requires one pass with many inputs (LST)
				if "%%i"=="LNK_" (
					echo !msrc!\%2.!mbin! >"%vsrt%.%%i.1"
				)

				rem Cpu locking variables
				set /a "csrt=0"
				set /a "cend=0"
				for /l %%c in (%cmin%,1,%cmax%) do set "cexe%%c="

				rem Check if the executable file actually really exists
				if exist !vexe! if exist "%vsrt%.%%i.1" (
					rem Display here a false message because the real work is done in the loop below
					if not "!mdep!"=="" echo  Checking dependencies... %clog%

if not "!vdeb!"=="" echo   Executing command on each listed file... %clog%

					rem Now execute the commands for each source files found
					for /f "delims=!" %%a in (%vsrt%.%%i.1) do (
						set "vrel=%%a"

						rem Remove trailing and leading spaces
						for /l %%l in (1,1,2) do if "!vrel:~-1!"==" " set "vrel=!vrel:~0,-1!"
						for /l %%l in (1,1,2) do if "!vrel:~0,1!"==" " set "vrel=!vrel:~1!"

						rem Create the relative destination path from source path
						if not "!vrel!"=="" set "vrel=%%~dpa"

if not "!vdeb!"=="" echo     vrel=!vrel!
if not "!vdeb!"=="" echo     msrc=!msrc!
if not "!vdeb!"=="" echo     mdst=!mdst!

REM						set "vrel=!vrel:/=\!"
						if "!vrel:~-1!"=="/" set "vrel=!vrel:~0,-1!"
						if "!vrel:~-1!"=="\" set "vrel=!vrel:~0,-1!"
						call set "vrel=%%vrel:!msrc!=!mdst!%%"
						call set "vrel=%%vrel:!mpwd!=.%%"

if not "!vdeb!"=="" echo     Checking if file is newer... %clog%

						rem File to process flag
						set "vchk="

						rem Check if the source file is newer than destination file
						set "vobj="
						if not "!mobj!"=="" (
							set "vrem=%%~na.!mobj!"
							rem Try in destination folder first
							set "vobj=!mdst!\!vrem!"
							rem Try in relative folder next
							if not exist "!vobj!" set "vobj=!vrel!\!vrem!"
							if exist "!vobj!" (
								rem If more recent
								xcopy /D /L /Y "%%a" "!vobj!" | findstr /BC:"1 ">nul && set "vchk=1"
							) else (
								rem No object file found? Objection! Generate it...
								set "vchk=1"
							)
						) else (
							rem Execute even if no object file defined
							set "vchk=1"
						)

if not "!vdeb!"=="" echo     Checking file dependencies... %clog%

						rem Check file dependencies (can be quite long, sadly)
						set "vdep="
						rem Has been currently disabled due to poor xcopy performance
if not "!mdep!"=="TOTO" if exist "!vobj!" if not "!mdep!"=="" (
							rem Try in destination folder first
							set "vdep=!mdst!\%%~na.!mdep!"
							rem Try in relative folder next
							if not exist "!vdep!" set "vdep=!vrel!\%%~na.!mdep!"
							if exist "!vdep!" (
								for /f "delims=!" %%b in (!vdep!) do (
									rem Get the dependency line
									set "vtst=%%b"
									rem Parse dependency line to keep only the dependency file path
									call set "vtst=%%vtst:!vrem!: =%%"
									rem If more recent
									xcopy /D /L /Y "!vtst!" "!vobj!" | findstr /BC:"1 ">nul && set "vchk=1"
								)
							) else (
								rem No dependency file? Well, misconfiguration maybe...
								set "vchk=1"
							)
						)

						rem If destination file absent or source file more recent
						if not "!vchk!"=="" (
							rem Start the process on the first unlocked CPU
							if !csrt! lss !mcpu! (
								set /a "csrt+=1"
								set /a "cnxt=csrt"
							) else (
								call :waitcpu
							)
							del "%lcpu%.!cnxt!" %fquiet%

if not "!vdeb!"=="" echo       Adapt destination file... %clog%

							rem Adapt destination link file if found
							if not "%%i"=="LNK_" if not "!mlnk!"=="" (
								set "vcmd=!mlnk!"
								rem Pass the file list only if used (try to avoid the 8191 bytes bug)
								if not "!mlnk!"=="!mlnk:$[LIST]=!" (
									call :adaptvcmd "%2" "%%a" "!msrc!" "!vrel!" "!mmov!" "!vlst!"
								) else (
									call :adaptvcmd "%2" "%%a" "!msrc!" "!vrel!" "!mmov!" ""
								)
								set "vcmd=!pcmd!"
								rem Change separator
								if not "!msep!"=="" call set "vcmd=%%vcmd:/=!msep!%%"
								if not "!msep!"=="" call set "vcmd=%%vcmd:\=!msep!%%"
								echo !vcmd!>>"%vlnk%.0"
							)

if not "!vdeb!"=="" echo       Create argument list... %clog%

REM							echo vcmd1="!vcmd!"

							if "!mvia!"=="" (
								rem Get the clean command line
REM								echo vtmp3="!vtmp!"
								if not "!vtmp!"=="" (
REM									echo Do it :/
									set "vcmd=!vtmp!"
									rem Pass the file list only if used (try to avoid the 8192 bytes bug)
									if not "!vtmp!"=="!vtmp:$[LIST]=!" (
										call :adaptvcmd "%2" "%%a" "!msrc!" "!vrel!" "!mmov!" "!vlst!"
									) else (
										call :adaptvcmd "%2" "%%a" "!msrc!" "!vrel!" "!mmov!" ""
									)
									set "vcmd=!pcmd!"
									rem Change separator
									if not "!msep!"=="" call set "vcmd=%%vcmd:/=!msep!%%"
									if not "!msep!"=="" call set "vcmd=%%vcmd:\=!msep!%%"
								)
REM								echo vcmd2="!vcmd!"
							) else (
								rem Del the via file
								del "%lvia%.!cnxt!" %fquiet%

								if not "!mcli!"=="" for %%j in (!mcli!) do (
									set "nvia="

									if "%%j"=="ARG" if !narg! gtr 0 set "nvia=arg"
									if "%%j"=="DEF" if !ndef! gtr 0 set "nvia=def"
									if "%%j"=="INC" if !ninc! gtr 0 set "nvia=inc"
									if "%%j"=="LIB" if !nlib! gtr 0 set "nvia=lib"
									if "%%j"=="TMP" if !ntmp! gtr 0 set "nvia=tmp"

									if not "!nvia!"=="" (
										rem Adapt the via file
										if exist "%vsrt%.%%i.via.!nvia!" for /f "delims=!" %%b in (%vsrt%.%%i.via.!nvia!) do (
											rem Adapt the via line and store it
											set "vcmd=%%b"
											call :cleanvcmd && set "vcmd=!pcmd!"
											if "!vcmd!"=="$[LIST]" (
												rem Copy the list of source files if requested
												if "%%i"=="LNK_" (
													rem If a destination link files list exists, use it for linking
													if exist "%vlnk%.0" (
														rem Linking requires the destination link files list
														type "%vlnk%.0">>"%lvia%.!cnxt!"
													) else (
														rem Linking requires the original source files list
														type "%vsrt%.%%i.0">>"%lvia%.!cnxt!"
													)
												) else (
													type "%vsrt%.%%i.1">>"%lvia%.!cnxt!"
												)
											) else (
												rem Adapt the command-line in !vcmd!
												call :adaptvcmd "%2" "%%a" "!msrc!" "!vrel!" "!mmov!" "" && set "vcmd=!pcmd!"
												rem Change separator
												if not "!msep!"=="" call set "vcmd=%%vcmd:/=!msep!%%"
												if not "!msep!"=="" call set "vcmd=%%vcmd:\=!msep!%%"
												echo:!vcmd!>>"%lvia%.!cnxt!"
											)
										)
									) else (
										if "%%j"=="ARG" type "%vsrt%.%%i.via.arg">>"%lvia%.!cnxt!"
										if "%%j"=="DEF" type "%vsrt%.%%i.via.def">>"%lvia%.!cnxt!"
										if "%%j"=="INC" type "%vsrt%.%%i.via.inc">>"%lvia%.!cnxt!"
										if "%%j"=="LIB" type "%vsrt%.%%i.via.lib">>"%lvia%.!cnxt!"
										if "%%j"=="TMP" type "%vsrt%.%%i.via.tmp">>"%lvia%.!cnxt!"
									)
								)

								rem Set the via file
								set "vcmd=!mvia!^"%lvia%.!cnxt!^""
							)

if not "!vdeb!"=="" echo       Process file... %clog%

							rem Keep the expanded command line for debugging purpose
							echo !vexe! !vcmd!>>"%vsrt%.%%i.2"
							if not "!mvia!"=="" (
								type "%lvia%.!cnxt!">>"%vsrt%.%%i.2"
								echo:>>"%vsrt%.%%i.2"
							)

							rem Display the file being processed
							set "mrel=%%a"
							call set "mrel=%%mrel:!msrc!=.%%"
							echo   !mrel! %clog%

REM							echo vcmd3="!vcmd!"

							rem Remove bad formated argument
							if "!vcmd!"=="^" =^"" (
REM								set "vcmd="
							)

							rem The 'affinity' parameter BITFIELD select the CPU
							set /a "crun=!cnxt!-1"
							call :tohex !crun!

							rem If command line not started with a quote, add them
REM							if not "!vexe:~0,1!"==^"^"^" set vexe="!vexe!"

							if "!mmov!"=="" (
								rem Direct execution
								start "" /d "!mpwd!" /low /affinity !hex! /b cmd /v:on /c 1^>"%lcpu%.!cnxt!" 2^>^&1 !vexe! !vcmd!
							) else (
								rem Execute and move source file (on success)
								set "mrel=%%a"
								call set "mrel=%%mrel:!msrc!=!mmov!%%"
								start "" /d "!mpwd!" /low /affinity !hex! /b cmd /v:on /c " 1^>"%lcpu%.!cnxt!" 2^>^&1 !vexe! !vcmd! ^&^& move /y "%%a" "!mrel!" 1^>nul "
							)

							rem Log the executed command line (in case of lock conflict)
							echo !vexe! !vcmd!>>"%vsrt%.%%i.3"
							if not "!mvia!"=="" (
								type "%lvia%.!cnxt!">>"%vsrt%.%%i.3"
								echo:>>"%vsrt%.%%i.3"
							)

							rem Remote batch execution to catch errorlevel exit code
rem FIXME: currently batch file error loggers unused (not enough parameters)
							rem If the !vcmd! argument chain gets exploded and unresolved, use the via option
REM							start "" /d "!mpwd!" /low /affinity !hex! /b cmd /c 1^>"%lcpu%.!cnxt!" 2^>^&1 "%lbat%.!cnxt!" "!vexe!" "!vcmd!"
						)

						rem Check exit code
						call :waiterr
						if "!verr!" gtr "0" (
							echo Errorlevel=!verr! %clog%
REM							exit /b !verr!
						)
					)
				)
			)

			rem Wait for all processes to exit
			call :waitall

			rem Check exit code
			call :waiterr
			if "!verr!" gtr "0" (
				echo Errorlevel=!verr! %clog%
REM				exit /b !verr!
			)

			rem Duplicate object files if necessary
			if not "!mdup!"=="" (
				set "mdup=!mdup:$[CONF]=%2!"
				if not "!mdup!"=="!mdst!" (
					mkdir "!mdup!" 2>nul
					del "%vsrt%.%%i.6" /q %quiet%
					if not "!mobj!"=="" dir "!mdst!\*.!mobj!" %vdir% >>"%vsrt%.%%i.6"
					if not "!mbin!"=="" dir "!mdst!\*.!mbin!" %vdir% >>"%vsrt%.%%i.6"
					if exist "%vsrt%.%%i.6" (
REM						sort "%vsrt%.%%i.6">"%vsrt%.%%i.5"
						copy "%vsrt%.%%i.6" "%vsrt%.%%i.5" /y %quiet%

						rem Remove already duplicated files
						findstr /i /v "!mdup!" "%vsrt%.%%i.5">"%vsrt%.%%i.6"
if not "!vdeb!"=="" echo mdup=!mdup!
						echo  Duplicating destination files... %clog%
						if exist "%vsrt%.%%i.6" for /f "delims=!" %%a in (%vsrt%.%%i.6) do (
if not "!vdeb!"=="" echo dup=%%a
							copy "%%a" "!mdup!" /y %quiet%
						)
					)
				)
			)

			rem Include the log file into the output stream
			if not "!mlog!"=="" (
				set "vcmd=!mlog!"
				call :adaptvcmd "%2" "%2" "!msrc!" "!mdst!" "!mmov!" "" && set "mlog=!pcmd!"
				call :expandsize "!mlog!"
				if not "!pexp!"=="0" (
					type "!mlog!" %clog%

					rem Backup step log into step report folder
					if not "!mrpt!"=="" (
						copy "!mlog!" "!mrpt!" /y %quiet%
					)
				)
			)

			rem Echo only if something really happened
			echo: %clog%
		)
	)
)
set "mrun="

	call :waitall

:cleanup
	rem Deleting CPU lock files
	del "%lbat%*" %fquiet%
	del "%lcpu%*" %fquiet%
	del "%lerr%*" %fquiet%
	del "%lvia%*" %fquiet%

	rem Deleting source files list, log files, command files, etc...
REM	del "%vdst%" /s %fquiet%

	rem Expand again the relative path of the configuration file
	set "vrel=%~dp2"

	rem Tell user where is the log file
	echo: %clog%
	if not "%vlog%"=="nolog" if not "%vlog%"=="nul" echo Get the %vtxt% log into !vlog:%vrel%=.\! !

REM	cd "%odir%"

	rem Gogo gadget au poing
	goto end

:info
	echo Perform a source code action
	echo Usage : makeit "cmd" "make_file" ["exclude_file.txt"] ["log_file"/"nolog"]
	echo Store the result in a log file (default is ".\'cmd'.log")
	echo:
	echo Param = cmd
	echo          : all      - do "clean" to "run"
	echo          : partial  - do "clean" to "flash" (no "run")
	echo          : rebuild  - do "clean" to "link" (no "flash" and "run")
	echo          : quick    - do "compile" to "run" (no "clean")
	echo          : build    - do "compile" and "link" (with pre/post build)
	echo          : clean    - clean destination folder from old files
	echo          : assemble - assemble ASM_EXT minus ASM_EXC files
	echo          : compile  - compile CPP_EXT minus CPP_EXC files (pre build)
	echo          : link     - link LNK_EXT files into LNK_OBJ (post build)
	echo          : flash    - flash LNK_BIN file using default parameters
	echo          : run      - launch the selected debugger executable
	echo          : map      - perform mapping analysis
	echo Param = make_file
	echo          : the configuration file that contain the making rules
	echo Param = ["exclude_file.txt"]
	echo          : a text file which contains paths to exclude
	echo Param = ["log_file"/"nolog"]
	echo          : name of a log file to produce, "nolog" for nul

:end
	echo ------------------------------------------------------------------------------- %clog%

	rem Open log file in default application if "quick" build
	if not "%vlog%"=="" if not "%vlog%"=="nolog" (
		rem Backup build log into build report folder
		if not "!vrpt!"=="" (
			copy "%vlog%" "!vrpt!" /y %quiet%
		)

		if "%1"=="quick" start "" "%vlog%"
	)

	chcp %cp%>nul
goto :eof

:copyline
	rem Copy lines from a file (include blank lines through 'findstr')
if not "!vdeb!"=="" echo copyline
if not "!vdeb!"=="" echo   read line beg - %1
if not "!vdeb!"=="" echo   read line end - %2
if not "!vdeb!"=="" echo   read file src - %3
if not "!vdeb!"=="" echo   read file dst - %4
	if 0 lss %1 (
		set skipline=skip=%1
	) else (
		set skipline=
	)
if not "!vdeb!"=="" echo   read skip - %skipline%
	for /f "%skipline% tokens=1,* delims=:" %%l in ('findstr /n "^" "%3"') do (
		rem Read second token from 'findstr' ('linenum:string' : %%l:%%m)
		if 0 lss %2 (
			if %%l lss %2 (
if not "!vdeb!"=="" echo     read file num - %%l
if not "!vdeb!"=="" echo     read file str - %%m
				echo:%%m>>%4
			) else (
				exit /b
			)
		) else (
			echo:%%m>>%4
		)
	)
goto :eof

:findline
	rem Find first line from a file (include blank lines through 'findstr')
if not "!vdeb!"=="" echo findline
if not "!vdeb!"=="" echo   read line tok - %1
if not "!vdeb!"=="" echo   read line tag - %2
	set "vtag=%2"
	rem Remove escape character doubling
	set "vtag=!vtag:^^=^!"
if not "!vdeb!"=="" echo   read line tag - !vtag!
if not "!vdeb!"=="" echo   read file src - %3
	set "vcmd=findstr /n !vtag! ^"%3^""
if not "!vdeb!"=="" echo   read file cmd - !vcmd!
	for /f %1 %%l in ('!vcmd!') do (
		rem Read tokens from 'findstr'
if not "!vdeb!"=="" echo     read file num - %%l
if not "!vdeb!"=="" echo     read file str - %%m
		set "plin=%%m"
if not "!vdeb!"=="" echo     read file ret - !plin!
		exit /b
	)
goto :eof

:readline
	rem Read line from a file (include blank lines through 'findstr')
if not "!vdeb!"=="" echo readline
if not "!vdeb!"=="" echo   read line beg - %1
if not "!vdeb!"=="" echo   read file src - %2
	if 0 lss %1 (
		set skipline=skip=%1
	) else (
		set skipline=
	)
if not "!vdeb!"=="" echo   read skip - %skipline%
	for /f "%skipline% tokens=1,* delims=:" %%l in ('findstr /n "^" "%2"') do (
		rem Read second token from 'findstr' ('%%l:%%m' = 'linenum:string')
if not "!vdeb!"=="" echo     read file num - %%l
if not "!vdeb!"=="" echo     read file str - %%m
		set "plin=%%m"
if not "!vdeb!"=="" echo     read file ret - !plin!
		exit /b
	)
goto :eof

:writevar
	rem Parse and flush variable into file
if not "!vdeb!"=="" echo writevar
if not "!vdeb!"=="" echo   write line var - %1
if not "!vdeb!"=="" echo   write file dst - %2
	for %%l in (%1) echo %%l>>"%2"
goto :eof

:waiterr
	rem Check %errorlevel% exit codes, if any (not accurate, needs rework)
	for %%l in ("%lerr%*") do (
		for /f "delims=!" %%m in ("%%l") do (
			set "perr=%%~m"
			if "%perr%" gtr "%verr%" (
				set "verr=%perr%"
			)
		)
		ping /n 0 ::1 %quiet%
		del "%%l" %fquiet%
	)
goto :eof

:waitall
	rem Wait remaining CPU to unlock
REM	echo - - - START - - - - - - - - - - - - -%clog%
	rem Set timing to at least '2' if you have weird message logging
	ping /n 2 ::1 %quiet%
	for %%l in ("%lcpu%*") do (
		call :expandsize "%%l"
		if not "!pexp!"=="0" (
			rem Include remaining logs into the stream
REM			echo - - - "%%l" - - - - - - - - - - - - -%clog%
			type "%%l" %clog%
			rem Flush file
			ping /n 0 ::1 %quiet%
			del "%%l" %fquiet%
REM			echo>"%%l"
REM			echo - - - "%%l" - - - - - - - - - - - - -%clog%
		)
		(call ) 9>"%%l" || (
REM			ping /n 1 ::1 %quiet%
			goto :waitall
		)
	) 2>nul
REM	echo - - - END - - - - - - - - - - - - -%clog%
goto :eof

:waitcpu
REM	echo = = = START = = = = = = = = = = = = =%clog%
REM	ping /n 0 ::1 %quiet%
	for /l %%c in (%cmin%,1,!mcpu!) do (
		if not defined cexe%%c if exist "%lcpu%.%%c" (
			call :expandsize "%lcpu%.%%c"
			if not "!pexp!"=="0" (
				rem Include current log into the stream
REM				echo = = = "%lcpu%.%%c" = = = = = = = = = = = = =%clog%
				type "%lcpu%.%%c" %clog%
				rem Flush file
				ping /n 0 ::1 %quiet%
				del "%lcpu%.%%c" %fquiet%
REM				echo>"%lcpu%.%%c"
REM				echo = = = "%lcpu%.%%c" = = = = = = = = = = = = =%clog%
			)
			if defined mrun (
				set /a cnxt=%%c
				exit /b
			)
			set /a "cend+=1"
			set /a "cexe%%c=1"
		) 9>>"%lcpu%.%%c"
	) 2>nul

	if %cend% lss %csrt% (
		ping /n 1 ::1 %quiet%
		goto :waitcpu
	)
REM	echo = = = END = = = = = = = = = = = = =%clog%
goto :eof

:tohex
	rem Return the hexadecimal representation of a shifted bit
	set /a "dec=1<<%1"
	set "hex="
	set "map=0123456789ABCDEF"
	rem Set the length of the string
	set "len=4"
	for /l %%n in (1,1,%len%) do (
		set /a "d=dec&15,dec>>=4"
		rem Look in the hex table for the right character
		for %%m in (!d!) do set "hex=!map:~%%m,1!!hex!"
	)
goto :eof

:expandpath
	rem Poor-man's full-path variable expansion
	set "pexp=%~f1"
goto :eof

:expandsize
	rem Poor-man's size variable expansion
	set "pexp=%~z1"
goto :eof

:cleanpath
	set "pcln="
	if not "%~1"=="" (
		rem Expand argument
		set "pcln=%~1"
		rem Change slashes
REM		set "pcln=!pcln:/=\!"
		rem Remove last backslash
		if "!pcln:~-1!"=="/" set "pcln=!pcln:~0,-1!"
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
	rem %5 : move
	rem %6 : list
	rem When a command includes spaces and/or double quotes, it gets exploded
	rem That's why I process the !vcmd! variable directly
	set "pcmd=!vcmd!"
	set "pcmd=!pcmd:$[CONF]=%~1!"
	set "pcmd=!pcmd:$[THIS]=%~2!"
	set "pcmd=!pcmd:$[FULL]=%~f2!"
	set "pcmd=!pcmd:$[DISK]=%~d2!"
	set "pcmd=!pcmd:$[FOLD]=%~p2!"
	set "pcmd=!pcmd:$[PATH]=%~dp2!"
	set "pcmd=!pcmd:$[LANG]=%~dpn2!"
	set "pcmd=!pcmd:$[NAME]=%~n2!"
	set "pcmd=!pcmd:$[DOSN]=%~s2!"
	set "pcmd=!pcmd:$[EXT]=%~x2!"
	set "pcmd=!pcmd:$[FILE]=%~nx2!"
	set "pcmd=!pcmd:$[ATTR]=%~a2!"
	set "pcmd=!pcmd:$[TIME]=%~t2!"
	set "pcmd=!pcmd:$[SIZE]=%~z2!"
	set "pcmd=!pcmd:$[LOC_SRC]=%~3!"
	set "pcmd=!pcmd:$[LOC_DST]=%~4!"
	set "pcmd=!pcmd:$[LOC_MOV]=%~5!"
	set "pcmd=!pcmd:$[LIST]=%~6!"
	rem Remove double characters
	set "pcmd=!pcmd:\\=\!"
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
