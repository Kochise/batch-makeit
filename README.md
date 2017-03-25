# Makeit

Embeddable make engine for DOS and Windows

* Introduction

Development do not just involves source code, a compiler and voilà. There is also the need to feed the compiler with the source code and some options according to some rules in order to get the binary image you will either run directly or flash in an embedded system.

There is already several ways to do so, by using the IDE's integrated build system (Visual Studio, Eclipse) or using the infamous GNU make that looks like another cryptic programming language that yet ressemble nothing else.

When coding, the programmer have already to deal with a large variety of programming languages, from C/C++ for the main code, Perl and Python for development environment and/or source control extension, Java for Jenkins, etc.

And with each additional language, additional installations, size cost, dependencies, updates, incompatibilities, maintenance. That's why I wanted to get the build engine as light, portable, embeddable, configurable and maintainable as possible.

* History

The very first incarnation of the Makeit engine took place as a little batch file used to compile an Erlang port of the Minilight monte-carlo based raytracer :

\- - - 8< - - - -<br>
@echo off<br>
<br>
if "%1"=="test" goto test<br>
<br>
set esrc=.\\src<br>
goto compile<br>
<br>
:test<br>
set esrc=.\\test<br>
<br>
:compile<br>
set ebin=.\\ebin<br>
set erlinc=.\\include<br>
set erlp=C:\\Erlang\\bin<br>
set erlc=erlc<br>
set erl_flags=-I%erlinc%<br>
set erlsrc=*.erl<br>
set erldst=*.beam<br>
<br>
del Make_E.lst /Q<br>
del Make_E.log /Q<br>
<br>
dir /B /A:-D /ON %esrc%\\%erlsrc% > Make_E.lst<br>
<br>
for /F %%i in (Make_E.lst) do (<br>
echo Compiling %esrc%\%%i<br>
echo === %esrc%\%%i ====================================== >> Make_E.log<br>
"%erlp%\\%erlc%" -W -bbeam %erl_flags% -o%ebin% "%esrc%\\%%i" >> Make_E.log<br>
echo. >> Make_E.log<br>
)<br>
<br>
del Make_E.lst<br>
<br>
echo.<br>
echo Get the compile log into '.\\Make_E.log' !<br>
<br>
@echo on<br>
\- - - 8< - - - -<br>

* Conception

The main idea behind Makeit is to have easily readable and editable configuration files, that could be compared between revisions, stored under the source control manager, and also controlled by several little batch files to start several sequences, from assembling to linking, called from the IDE or run directly.

Working under Windows, I had the choice of the programming language or platform like C++, Vb, .Net, etc. However I wanted to stay as much bare to the metal as possible, so I choose the hard way : plain DOS batch script. A simple open-source text script that do not requires prior compiling.

However the feature set of such make engine was set pretty high considering the development platform selected : configuration file to be parsed, analysed, sequenced, spreading the execution of programs across the available CPU cores to fasten the compilation time.

Batch files do provides some good functions through the use of extended DOS commands, even though it proven some of them to behave strangely if not just buggy, the string collating is implicit, but search and replace is tricky. Debugging is a real mess, delayed variable expansion breaks your mind, yet here it goes.

But the hugest limitation I've met was the most stupid 8191 bytes per variable. Some command lines could be quite long when you have several include paths, hence I had to develop a 'via' fall back to generate the command in external files what showed the slow performance of batch script in this area.

* Sequence

The Makeit engine provides the generation of all the compiler's (or any external program, even another batch scripts) command lines by providing resolvable elements into a configuration file. Resolving such configuration file proved to be tricky using a batch script, but feasible using the 'findstr' command.

Several steps (clean, compile, link, ...) can be embedded into such a configuration file, and a command provided to the Makeit engine tells what sequence (rebuild, ...) of steps to apply. While it features common case sequences, some additional sequences can be provided as well in the configuration file.

Each step involves an executable file, the maximum number of CPU to limit resource usage or conflicts during linking for instance, the command line structure, the source folder, the destination folder, various extensions of source files to process, arguments, include paths, defines and some other things.

In general, the executable file is called for each source file found in the source folder and matching the extensions provided. Yet some files might be excluded from the process, so exclude patterns can be added directly inside the configuration file and/or provided in an external file.

Some basic verification is processed, like the existence of the actual executable file, source files are listed so they sure exists, destination folder used as source if no source folder is specified, etc.

Then the make engine loop each step to generate the command line, call the executable file for each source file, and go to the next step in the sequence. Pretty straightforward, really.

* Configuration file

A configuration file is a text file that will set your workspace build configuration. It is mostly like an '.ini' file in the sense that there are sections and parameters. But instead to have [...] sections and child parameters, you have a 'STEP_PARAM=' format that allows a same '_PARAM' be defined multiple times.

\- The list of the common step prefixes tags defined inside the Makeit engine is :

CLN_ = clean<br>
ASM_ = assemble<br>
PRE_ = pre compilation (do something before compilation)<br>
CPP_ = compilation<br>
LNK_ = link<br>
PST_ = post compilation (do something after, such convert binary, strip symbols, etc.)<br>
FLH_ = flash (flash the binary file inside the embedded target)<br>
RUN_ = run (launch the debugger)<br>
MAP_ = map analysis (after LNK_)<br>

Please bear in mind that you can create your own. Keep it short (3 capital letters is good) and add an underscore at the end.

\- The list of the current step suffixes tags is :

REM = remark, print (the last declared) before running the step<br>
LOC = files' location (BAT, EXE, SRC and DST)<br>
EXE = executable file to execute, in PATH variable or LOC_EXE (NEEDED)<br>
SRC = source folder (recursive and sorted alphabetically)<br>
DST = destination folder (NEEDED, use SRC if empty)<br>
RPT = report folder or file to save generated logs<br>
CPU = number of CPU maximum, default is the %NUMBER_OF_CPU% variable<br>
CLI = command line order (those are LOC EXE SRC DST DBG DEP OBJ BIN EXT EXC LST ARG DEF INC LIB TMP)<br>
VIA = if not empty, will create VIA files and be added to the command line (very slow, only ARG DEF INC LIB TMP)<br>
LOG = log file generated by the executable and to be printed out at the end of the step's execution<br>
DBG = optional free parameter, can be used in the CLI parameter<br>
DEP = file extension to survey in the SRC tree to increment build (not stable)<br>
OBJ = object files collected for the link (and compared to DEP files if incremenatl build)<br>
BIN = binary files to generate in the DST folder<br>
LNK = optionnal list of files to link, only during the LNK_ step<br>
DUP = optionnal backup folder for generated OBJ and BIN files in the DST folder<br>
EXT = file extensions to list in the SRC folder<br>
EXC = path and filename elements to filter out from the list (bug, first one without \)<br>
DEL = extension of files to delete in the destination folder before EXE is run<br>
XPY = extension of files to xcopy from source to destination folder<br>
CPY = files to copy from from source to destination folder<br>
ARG = optional free parameter, can be used in the CLI parameter<br>
DEF = defines prefixed with '-D'<br>
INC = include paths prefixed with '-I'<br>
LIB = optional free parameter, can be used in the CLI parameter<br>
TMP = optional free parameter, can be used in the CLI parameter<br>

This list cannot be extended because it is wired in the core of the Makeit engine and there is a behavior linked to each of them.

\- The list of the common sequences defined inside the Makeit engine is :

all		= CLN_ ASM_ PRE_ CPP_ LNK_ PST_ FLH_ RUN_ (clean to run)<br>
partial	= CLN_ ASM_ PRE_ CPP_ LNK_ PST_ FLH_ (flash the embedded device but don't run it)<br>
rebuild	= CLN_ ASM_ PRE_ CPP_ LNK_ PST_ (the classic rebuild command)<br>
quick	= PRE_ CPP_ LNK_ PST_ FLH_ RUN_ (build, flash and run)<br>
fast	= PRE_ CPP_ LNK_ PST_ FLH_ (build and flash)<br>
build	= PRE_ CPP_ LNK_ PST_ (build)<br>
clean	= CLN_<br>
assemble = ASM_<br>
compile	= PRE_ CPP_<br>
link	= LNK_ PST_<br>
flash	= FLH_<br>
run		= RUN_<br>
map		= MAP_<br>

Don't forget that additional custom steps and sequences can be added directly in the configuration file in the following format (beware of the spurious space characters between steps) :

\<sequence>=\<step1> \<step2> \<...> \<stepn><br>

Something like :

custom=FIT_ ASM_ MAP_ LNK_

\- Here is the list of resolvable keys :

${...} = static, resolved at Makeit start, when the configuration file is parsed, must only be relative paths<br>

${CONF} = the configuration name ('conf' in 'makeit rebuild conf' command line)
${CD} = the current directory from which makeit is launched

$[...] = dynamic, resolved at each step execution, the complete list is below :<br>

$[CONF] = the configuration parameter, like 'debug' or 'release'<br>
$[THIS] = the complete path and file name of the source file processed<br>
$[PATH] = the path of the source file processed<br>
$[NAME] = the name of the source file processed<br>
$[EXT] = the extension of the source file processed ('.c' vs '.cpp')<br>
$[FILE] = the file name and extension of the source file processed<br>
$[ATTR] = the attribute string of the source file processed (DOS format)<br>
$[TIME] = the modification time of the source file processed (DOS format)<br>
$[SIZE] = the size of the source file processed (DOS format)<br>
$[LOC_SRC] = the resolved source path<br>
$[LOC_DST] = the resolved destination path with configuration sub folder<br>
$[LIST] = the list of link files during the 'LNK_' step<br>

Before explaining the engine's depths, let's show and explain a simple configuration script :

\- - - 8< - - - -<br>
LOC_BAT=C:\\GNU<br>
LOC_EXE=${LOC_BAT}\bin<br>
LOC_SRC=.\\..\\..\\..\\SOURCE<br>
LOC_DST=.\\..\\..\\..\\BUILD\EXE<br>
LOC_RPT=.\\..\\..\\..\\REPORT<br>
<br>
INCLUDE=probe.txt<br>
<br>
CROSS=x86-none-eabi-
<br>
custom=ASM_ CPP_ TST_<br>
<br>
CLN_EXE=del<br>
CLN_CPU=1<br>
CLN_DST=${LOC_DST}<br>
CLN_CLI=EXE ARG EXT<br>
CLN_EXT=exe<br>
CLN_DEL=d<br>
CLN_DEL=h<br>
CLN_DEL=o<br>
<br>
ASM_EXE=${CROSS}as.exe<br>
ASM_SRC=${LOC_SRC}<br>
ASM_DST=${LOC_DST}<br>
ASM_CLI=LOC EXE ARG EXT<br>
ASM_EXT=s<br>
ASM_DEP=d<br>
ASM_OBJ=o<br>
ASM_LNK=$[NAME].o<br>
ASM_ARG=--mcpu=x86<br>
ASM_ARG=--list=$[CONF].lst<br>
ASM_ARG=--depend "$[NAME].d"<br>
ASM_ARG=-o "$[NAME].o"<br>
<br>
CPP_EXE=${CROSS}c++.exe<br>
CPP_SRC=${LOC_SRC}<br>
CPP_DST=${LOC_DST}<br>
CPP_CLI=LOC EXE DEF ARG INC EXT<br>
CPP_EXT=cpp<br>
CPP_EXT=c<br>
CPP_EXC=\\tests\\<br>
CPP_DEP=d<br>
CPP_OBJ=o<br>
CPP_LNK=$[NAME].o<br>
CPP_ARG=--mcpu=x86<br>
CPP_ARG=--depend "$[NAME].d"<br>
CPP_ARG=-o "$[NAME].o"<br>
CPP_DEF=VIRTUAL_RELAY<br>
CPP_INC=${LOC_SRC}<br>
CPP_INC=${LOC_DST}<br>
<br>
LNK_EXE=${CROSS}ld.exe<br>
LNK_CPU=1<br>
LNK_DST=${LOC_DST}<br>
LNK_CLI=LOC EXE ARG LIB LST TMP<br>
LNK_TMP=${LOC_DST}\\$[CONF]<br>
LNK_EXT=o<br>
LNK_OBJ=o<br>
LNK_LNK=.*.o<br>
LNK_BIN=exe<br>
LNK_ARG=--mcpu=x86<br>
LNK_ARG=--log "$[LOC_DST]\\$[CONF].link.log"<br>
LNK_LOG=$[LOC_DST]\\$[CONF].link.log<br>
LNK_LIB=-o "$[LOC_DST]\\$[CONF].exe"<br>
<br>
TST_EXE=test.exe<br>
TST_CPU=1<br>
TST_SRC=${LOC_DST}\\Test<br>
TST_CLI=EXE<br>
TST_EXT=tst<br>
\- - - 8< - - - -<br>

Here is the explanation of each tag and the way it is resolved :

The command provided to the Makeit engine select the sequence. Each prefix in the sequence is then collated to each suffix (from REM to TMP) to look if the combination has been defined in the configuration file. If so, the data is either read (for some parameters like EXE, SRC, DST, CLI, CPU, ...) or stacked (ARG, DEF, INC, ...)

If the EXE and DST tags are valid, EXT files are listed and triggers the step execution. By using wisely the various suffixes, the CLI tag that defines the construction order of the command line and the resolvable keys, you can generate very complex commands for the compilation process.

From the DOS command prompt :

"makeit rebuild debug"

The Makeit engine will trigger the 'rebuild' sequence (CLN_ ASM_ PRE_ CPP_ LNK_ PST_) using the 'debug.txt' configuration file. It will try first to find the 'CLN_' steps lines and scan the 'REM' to 'TMP' suffixes arguments. If the parameters are valid, using the 'CLI' parameter, will execute the suitable 'EXE'.

If no 'CLN_' step is found, it is discarded and try the next step in the sequence, which is presently the 'ASM_' step. Again all 'ASM_' lines are parsed, stored, resolved before launching the 'ASM_EXE' executable with the corresponding 'ASM_CLI' constructed command line.

Each time an executable is run, its output is redirected inside a text file that serve as process locker/stamp and is then output in the process flow when the 'EXE' process' execution ends. If the 'CPU' argument is set to 1, the execution is sequential, but if 'CPU' is greater than 1, the output can be delayed.

* Architecture

At first I wanted to use a INI file and its hierarchical structure. However parsing such a file using just a batch file revealed to be a bit too complex and mostly prevented forward file inclusions of steps. So I got back to something more KISS like. Here is a basic overview of the batch file with each core part located and explained further down :




\-

\-

* Logging

Each step of the configuration file parsing, sorting, analysis, resolving, execution is saved in separate files named after their respective steps. This guarantee a full transparency and analysis of the generated command lines send to the executable file. It is then even possible to execute the command lines by hand.

Each time the Makeit engine is called, a '%date%_%time%_$[CONF]_$[CMD]' sub-folder is created in the calling directory. This folder will contain the (re)solved configuration files ($[CONF].solv.* and $[CONF].sort.0) as well as the different file lists ($[CONF].solv.$[STEP].0 and filtered 1) and commands (2 and executed 3).

The *.0 lists are the EXT(ension) files and the *.1 lists are without the EXC(luded) files. The *.2 lists are the generated commands and the *.3 lists are the commands that are really sent to the EXE(cutable) file. If the *.2 and *.3 are different, here lies an error that might explain the compilation failure.

During the Makeit engine generation, everything sent to the console is mirrored into a '$[CONF].log' file that may then be analysed in case of failure. By using wisely the 'LOG' tag, you can also save the step's execution log (if you add a suitable 'ARG' tag) into the Makeit log. Nice for archiving/parsing no additional file.

You can point for each step a xxx_LOG file generated by the xxx_EXE executable to be included in the build log at the end of the step execution. If you specified a LOC_RPT folder or file, the build log will be copied there at the end of the build procedure. This is useful for further processing with code analysis tools.

* Maintenance

The maintenance of the Makeit engine is pretty easy, provided you have common knowledge of the DOS functionalities and commands. You can already copy and paste some existing code to extend the engine features at will, there are enough comments to provide you with some insight and hints.

The various configuration files also need maintenance and regular clean-up upon the development of your source code. That implies adding defines, include paths, arguments, perhaps post-build step to copy pre configured debugger's project files to the destination folder before flashing/running the generated binary file.

Another step would be to convert the Makeit engine into Perl (115 MB) and Lua/or (8 MB) that are two well known and accepted environment programming languages. That would certainly solve the 8191 bytes limit bug, however the command line should stay within a certain limit, so the via option might still be helpful.

* Evolution

I'll try to avoid the sorting of the resolved configuration files which implies the unsorting of the actual commands. If 'ARG', 'DEF' or 'INC' tags had a specific sorting, currently my configuration file resolution mechanism imply scrambling the carefully set order of step's commands to a alphabetical sorting.

Another path of exploration would be to use a simple .ini file with '[step]' and 'suffix=' yet it is arguable how exactly the 'suffix=' would be parsed and ordered. Right now the Makeit parameter discrimination engine is very straightforward due to the '(\w)_(\w)=(.*)' format.

* Creating the calling batch files

It is possible to call the Makeit engine directly, or use a (large) set of pre configured batch files you might run by hand, or link to your favourite IDE and/or continuous testing framework (like Jenkins). You just have to set the batch file's directory as current folder, and run the suitable batch file. It will execute the steps.

Common IDE provides different build configurations, like 'debug', 'release', etc. This can be mimicked by writing 'debug.txt' and 'release' configuration files only different on some compiling options (like optimization flags and including the symbols). Then the set of calling batch have to be duplicated as well.

Each calling batch file is pretty dumb though, and just contains the following line :

(relative path)\makeit(.bat) COMMAND CONFIGURATION

The Makeit engine can be located elsewhere, not always duplicated in each of your configuration folder. Yet the Makeit log folder will be generated in the same directory than the configuration file. Beware, all path in the configuration file are relative to the Makeit engine location, though.

Don't forget that while setting up your first configuration file, the '$[CONF].sort.0' resolved file is located in the '%date%_%time%_$[CONF]_$[CMD]' sub-folder, so you can always check what the resolving produced. Change your paths accordingly up to get the desired behaviour and compilation output.

You will find some pre-configured configuration files and projects inside the ZIP file.

* Tricks

I'll now explain some tricks to be used inside and outside the configuration for maximum throughput performance using the Makeit engine. Dynamic configuration file generation/modification is also one of them, since it is just a text file.

The 'INCLUDE=' tag is three level deep, that's to say that you can also 'INCLUDE=' back another file from the first included file. For instance, this is used for probes' type selection without having to modify the main configuration files. Just modify the 'probe.txt' file to include the actual fitted probe configuration file.

That's to say, first the configuration file two-levels inclusion occurs, then its resolution and its execution. Common commands and tags can be located in the first level inclusion files (here 'probe.txt') then the specific tags in the second level inclusion files. At the end of resolving, the '$[CONF].sort.0' file will contain everything.

For little projects you may want to avoid adding a load of include paths to prevent the need of the 'VIA' tag, that will dramatically slow down the Makeit execution. Using a 'PRE_' step, you can copy all '*.h' files from the source folder tree and flatten them in the destination folder, provided there is no name collision.

Here is what it might look like :

\- - - 8< - - - -<br>
ASM_DST=${LOC_DST}\\_<br>
CPP_DST=${LOC_DST}\\_<br>
LNK_DST=${LOC_DST}\\_<br>
<br>
PRE_EXE=copy<br>
PRE_CPU=1<br>
PRE_SRC=${LOC_SRC}<br>
PRE_DST=${LOC_DST}<br>
PRE_CLI=EXE EXT ARG<br>
PRE_XPY=h<br>
PRE_OBJ=h<br>
PRE_DUP=${LOC_DST}\\_<br>
PRE_ARG="$[LOC_DST]\\$[FILE]"<br>
<br>
CPP_REM=Only one path to include, neat...<br>
CPP_INC=${LOC_DST}\\_<br>
\- - - 8< - - - -<br>

Hence you will only have one '_' folder to include, which reduce the size of the command line. Don't forget to specify this '_' folder as your new destination folder in all your build steps. By using the underscore character, it will always be located at first position and will also shorten the generated command line.

* Additional batch files

There is couple of really useful batch files to the Makeit engine. One that bulk delete all previous Makeit log folders and one that bulk delete all generated binary files. Hence this allows a fast and easy cleanup of the workspace, either for archiving or syncing with an SCM.

\- - - delete_all_builds.bat - - -<br>
@echo off<br>
<br>
rem Delete all previous build files<br>
rmdir "..\\BUILD" /s /q 1>nul 2>nul<br>
\- - - 8< - - - -<br>

\- - - delete_makeit_logs.bat - - -<br>
@echo off<br>
<br>
rem Delete all previous build logs<br>
dir "20??????_????????_*" /B /A:D /ON /S > liste.txt<br>
if exist "liste.txt" (<br>
    for /f %%a in (liste.txt) do (<br>
        rmdir "%%a" /s /q 1>nul 2>nul<br>
    )<br>
    del "liste.txt" /q 1>nul 2>nul<br>
)<br>
\- - - 8< - - - -<br>

According to you own workspace setup, it will be really easy to work out every of your developments' needs. Just be sure to use a very precise development directory tree, one folder for the source code files, one for the libraries, one for the generated binary images, one for the executable programs, etc.

* Eclipse build configuration

Like Visual Studio, Eclipse allows to create various build configurations. The trick to link Eclipse's build procedure to the Makeit engine is to use Eclipse's 'BUILD_CONF' internal variable with different targets through a suitable makefile.



