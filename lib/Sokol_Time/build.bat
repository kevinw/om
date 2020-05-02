@setlocal
@echo off

set CC=cl /nologo /O2 /I. /Z7 /c
set LD=lib /nologo
set RM=del

if not exist "win" mkdir win

%CC% sokol_time_d3d11.c && %LD% sokol_time_d3d11.obj /OUT:win/sokol_time_d3d11.lib && %RM% sokol_time_d3d11.obj
