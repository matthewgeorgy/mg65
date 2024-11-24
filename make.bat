@echo off

odin build . -out:main.exe -debug
cd test
odin build . -out:test.exe
cd ..

