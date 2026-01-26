@echo off
echo Compiling VDU project with MinGW...

REM Compile main.c
echo Compiling main.c...
gcc -g -Wall -I. -I./src -I../LvglLuaBinding/lvgl -I../LvglLuaBinding/lua -D_DEFAULT_SOURCE -D_BSD_SOURCE -c src/main.c -o src/main.o
if %errorlevel% neq 0 (
    echo Failed to compile main.c
    exit /b 1
)

REM Compile lv_lua.c
echo Compiling lv_lua.c...
gcc -g -Wall -I. -I./src -I../LvglLuaBinding/lvgl -I../LvglLuaBinding/lua -D_DEFAULT_SOURCE -D_BSD_SOURCE -c src/lv_lua.c -o src/lv_lua.o
if %errorlevel% neq 0 (
    echo Failed to compile lv_lua.c
    exit /b 1
)

echo Compilation completed successfully!
echo Note: Full linking requires LVGL and Lua object files. Use mingw32-make for complete build.
