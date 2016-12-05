# Eclipse makefile to call the right target

# Invocate build command
all: build

# Build Keil
build:
	make -j4 all

main-build:
	make -j4 main-build

pre-build:
	make pre-build	
	
clean:
	make clean
	
Makeit_all:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_all.bat"

Makeit_quick:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_quick.bat"

Makeit_fast:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_fast.bat"

Makeit_clean:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_clean.bat"

Makeit_rebuild:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_rebuild.bat"

Makeit_build:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_build.bat"

Makeit_flash:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_flash.bat"

Makeit_run:
	cd "$(subst \,\\,$(SRC_ROOT)\makefiles)"; cmd.exe /c "$(BUILD_CONF)_run.bat"
