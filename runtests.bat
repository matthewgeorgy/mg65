@echo off

for %%f in (test\tests\*.asm) do (
	main.exe %%f
)

cls

mv *.o test\out

cd test
test.exe
cd ..

