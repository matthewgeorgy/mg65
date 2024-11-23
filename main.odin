package main

import fmt		"core:fmt"
import os		"core:os"
import strings	"core:strings"
import slice	"core:slice"

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
	FileContents := StringFile("foo.asm")

	Lexer : lexer

	CreateLexer(&Lexer, FileContents)
	LexerScanTokens(&Lexer)

	InitializeOpcodeTable(&gOpcodeTable)

	TokenSet := make(map[int][dynamic]token)
	LineNumbers : [dynamic]int

	// Put generated tokens in the map
	for Token in Lexer.Tokens
	{
		if !(Token.LineNumber in TokenSet)
		{
			TokenSet[Token.LineNumber] = {}
			append(&LineNumbers, Token.LineNumber)
		}
		append(&TokenSet[Token.LineNumber], Token)
	}

	// Validate tokens in any order
	for LineNumber, Tokens in TokenSet
	{
		ValidateTokens(Tokens[:])
	}

	// Report errors
	slice.sort_by(gErrors[:], SortErrors)
	for Error in gErrors
	{
		// fmt.println(Error.LineNumber, Error.Message)
		// fmt.printf("foo.asm(%d) Error: %s\n", Error.LineNumber, strings.clone_to_cstring(Error.Message))
		fmt.printf("foo.asm(%d)", Error.LineNumber)
		fmt.printf(" Error: ")
		fmt.printf("%s\n", strings.clone_to_cstring(Error.Message))
	}
}

// TODO(matthew): this needs a LOT of tidying up...
ValidateTokens :: proc(Tokens : []token)
{
	Opcode : opcode
	CurrentLine := Tokens[0].LineNumber

	Instruction := Tokens[0]
	if token_type.ADC <= Instruction.Type && Instruction.Type <= token_type.TYA
	{
		Opcode = gOpcodeTable[Instruction.Type]
	}
	else
	{
		ReportError(CurrentLine, "Code must start with an instruction")
		return
	}

	RemainingTokens := Tokens[1:]
	TokenCount := len(RemainingTokens)
	// 0 = Implicit
	// 1 = Accumulator, Immediate, ZeroPage, Absolute
	// 3 = ZeroPageX, ZeroPageY, AbsoluteX, AbsoluteY, Indirect
	// 4 = IndirectX, IndirectY

	if Opcode.Implicit != 0 || Instruction.Type == token_type.BRK
	{
		if TokenCount != 0
		{
			ReportError(CurrentLine, "Implicit instructions take 0 arguments.")
		}
		return
	}

	if Opcode.Implicit == 0 && TokenCount == 0
	{
		ReportError(CurrentLine, "This instruction does not support implicit mode")
		return
	}
	
	if TokenCount == 1 // Accumulator, Immediate, ZeroPage, Absolute
	{
		Arg := RemainingTokens[0] 

		if Arg.Type == token_type.NUMBER // Immediate
		{
			if Opcode.Immediate == 0
			{
				ReportError(CurrentLine, "This instruction does not support immediates")
			}
		}
		else if Arg.Type == token_type.ADDRESS8 // ZeroPage
		{
			if Opcode.ZeroPage == 0
			{
				ReportError(CurrentLine, "This instruction does not support zero-page addressing")
			}
		}
		else if Arg.Type == token_type.ADDRESS16 // Absolute
		{
			if Opcode.Absolute == 0
			{
				ReportError(CurrentLine, "This instruction does not support absolute addressing")
			}
		}
		else if Arg.Type == token_type.IDENTIFIER // Accumulator
		{
			if Arg.Lexeme == "A" || Arg.Lexeme == "a"
			{
				if Opcode.Accumulator == 0
				{
					ReportError(CurrentLine, "This instruction does not support accumulator")
				}
			}
			else
			{
				ReportError(CurrentLine, "Invalid argument")
			}
		}
		else
		{
			ReportError(CurrentLine, "Invalid argument")
		}
	}
	else if TokenCount == 3 // ZeroPageX, ZeroPageY, AbsoluteX, AbsoluteY, Indirect
	{
		Args := RemainingTokens

		if Args[0].Type == token_type.ADDRESS8 // ZeroPageX, ZeroPageY
		{
			Address8 := Args[0].Literal.(u8)

			if Args[1].Type == token_type.COMMA
			{
				if Args[2].Lexeme == "X" || Args[2].Lexeme == "x"
				{
					if Opcode.ZeroPageX == 0
					{
						ReportError(CurrentLine, "This instruction does not support ZeroPageX")
					}
				}
				else if Args[2].Lexeme == "Y" || Args[2].Lexeme == "y"
				{
					if Opcode.ZeroPageY == 0
					{
						ReportError(CurrentLine, "This instruction does not support ZeroPageY")
					}
				}
				else
				{
					ReportError(CurrentLine, "Invalid argument")
				}
			}
			else
			{
				ReportError(CurrentLine, "Invalid argument")
			}
		}
		else if Args[0].Type == token_type.ADDRESS16 // AbsoluteX, AbsoluteY
		{
			Address16 := Args[0].Literal.(u16)

			if Args[1].Type == token_type.COMMA
			{
				if Args[2].Lexeme == "X" || Args[2].Lexeme == "x"
				{
					if Opcode.AbsoluteX == 0
					{
						ReportError(CurrentLine, "This instruction does not support AbsoluteX")
					}
				}
				else if Args[2].Lexeme == "Y" || Args[2].Lexeme == "y"
				{
					if Opcode.AbsoluteY == 0
					{
						ReportError(CurrentLine, "This instruction does not support AbsoluteY")
					}
				}
				else
				{
					ReportError(CurrentLine, "Invalid argument")
				}
			}
			else
			{
				ReportError(CurrentLine, "Invalid argument")
			}
		}
		else if Args[0].Type == token_type.LEFT_PAREN // Indirect
		{
			if Args[1].Type == token_type.ADDRESS16
			{
				if Args[2].Type == token_type.RIGHT_PAREN
				{
					if Opcode.Indirect == 0
					{
						ReportError(CurrentLine, "This instruction does not support indirect addressing")
					}
				}
				else
				{
					ReportError(CurrentLine, "Invalid argument")
				}
			}
			else
			{
				ReportError(CurrentLine, "Invalid argument")
			}
		}
		else
		{
			ReportError(CurrentLine, "Invalid argument")
		}
	}
	else if TokenCount == 5 // IndirectX, IndirectY
	{
		Args := RemainingTokens

		if Args[0].Type == token_type.LEFT_PAREN
		{
			if Args[1].Type == token_type.ADDRESS8
			{
				if Args[2].Type == token_type.COMMA // IndirectX
				{
					if Args[3].Lexeme == "X" || Args[3].Lexeme == "x"
					{
						if Args[4].Type == token_type.RIGHT_PAREN
						{
							if Opcode.IndirectX == 0
							{
								ReportError(CurrentLine, "This instruction does not support IndirectX")
							}
						}
						else
						{
							ReportError(CurrentLine, "Invalid argument")
						}
					}
					else
					{
						ReportError(CurrentLine, "Invalid argument")
					}
				}
				else if Args[2].Type == token_type.RIGHT_PAREN // IndirectY
				{
					if Args[3].Type == token_type.COMMA
					{
						if Args[4].Lexeme == "Y" || Args[4].Lexeme == "y"
						{
							if Opcode.IndirectY == 0
							{
								ReportError(CurrentLine, "This instruction does not support IndirectY")
							}
						}
						else
						{
							ReportError(CurrentLine, "Invalid argument")
						}
					}
					else
					{
						ReportError(CurrentLine, "Invalid argument")
					}
				}
				else
				{
					ReportError(CurrentLine, "Invalid argument")
				}
			}
			else
			{
				ReportError(CurrentLine, "Indirect addressing requires a 1 byte address")
			}
		}
		else
		{
			ReportError(CurrentLine, "Invalid argument")
		}
	}
	else
	{
		ReportError(CurrentLine, "Too many arguments")
	}
}


