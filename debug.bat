@echo off
if not exist debug mkdir debug
nvcc main.cu -o debug\ASColour.exe
if "%ERRORLEVEL%"=="0" nvprof debug\ASColour.exe test.bmp testOutput.bmp testOutput.tmg