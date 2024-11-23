package main

import fmt		"core:fmt"
import os		"core:os"
import strings	"core:strings"

StringFile :: proc(FileName : string) -> [dynamic]string
{
	Lines : [dynamic]string

	Data, ok := os.read_entire_file(FileName)
	if !ok
	{
		fmt.println("Failed to read file:", FileName)
	}

	It := string(Data)
	for Line in strings.split_lines_iterator(&It)
	{
		append(&Lines, Line)
	}

	return Lines
}

main :: proc()
{
	fmt.println("blah")

	FileContents := StringFile("foo.asm")

	fmt.println(FileContents)
}

