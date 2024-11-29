@echo off

for %%f in (test\tests\*.asm) do (
	main.exe %%f
)
mv *.o test\out

cls

cd test
test.exe
cd ..

