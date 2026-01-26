@echo off
echo ========================================
echo Building VDU Project (Complete Build)
echo ========================================
echo.

REM Set common compiler flags
set "CFLAGS=-g -Wall -I. -I./src -I../LvglLuaBinding/lvgl -I../LvglLuaBinding/lua -D_DEFAULT_SOURCE -D_BSD_SOURCE"
set "LDFLAGS=-lmingw32 -lSDL2main -lSDL2 -lm"

echo Step 1: Compiling Lua library...
cd ..\LvglLuaBinding\lua
for %%f in (*.c) do (
    if not "%%f"=="lua.c" if not "%%f"=="luac.c" (
        echo Compiling %%f...
        gcc %CFLAGS% -c %%f -o %%~nf.o
        if %errorlevel% neq 0 exit /b 1
    )
)
cd ..\..\VduSimulator

echo.
echo Step 2: Compiling LVGL library...
for /r "..\LvglLuaBinding\lvgl\src" %%f in (*.c) do (
    echo Compiling %%f...
    gcc %CFLAGS% -c "%%f" -o "%%~dpnf.o"
    if %errorlevel% neq 0 exit /b 1
)
if %errorlevel% neq 0 (
    echo Failed to compile LVGL
    exit /b 1
)

echo.
echo Step 3: Compiling application source files...
gcc %CFLAGS% -c src\main.c -o src\main.o
if %errorlevel% neq 0 exit /b 1

gcc %CFLAGS% -c src\lv_lua.c -o src\lv_lua.o
if %errorlevel% neq 0 exit /b 1

echo.
echo Step 4: Creating static library libvdu.a...
REM Generate response file with forward slashes for ar
del /q lvgl_objs.rsp 2>nul
for /r "..\LvglLuaBinding\lvgl\src" %%f in (*.o) do (
    set "objpath=%%f"
    setlocal enabledelayedexpansion
    echo !objpath:\=/!>>lvgl_objs.rsp
    endlocal
)
setlocal enabledelayedexpansion
set "lv_lua_path=%CD%\src\lv_lua.o"
echo !lv_lua_path:\=/!>>lvgl_objs.rsp
endlocal
cmd /c "ar rcs libvdu.a @lvgl_objs.rsp"
if %errorlevel% neq 0 (
    echo Failed to create static library
    exit /b 1
)

echo.
echo Step 5: Linking final executable...
REM Generate response file for lua objects with forward slashes
del /q lua_objs.rsp 2>nul
for %%f in ("..\LvglLuaBinding\lua\*.o") do (
    set "objpath=%%~ff"
    setlocal enabledelayedexpansion
    echo !objpath:\=/!>>lua_objs.rsp
    endlocal
)
REM Note: libvdu.a depends on Lua functions, so Lua objects must come AFTER libvdu.a
REM Also add libvdu.a again at end to resolve circular dependencies
cmd /c "gcc -o vdu_sim.exe src/main.o libvdu.a @lua_objs.rsp libvdu.a %LDFLAGS% -lstdc++"
if %errorlevel% neq 0 (
    echo Failed to link executable
    exit /b 1
)

echo.
echo ========================================
echo Build completed successfully!
echo Output: vdu_sim.exe
echo ========================================
