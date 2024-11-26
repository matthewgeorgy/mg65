package main

import fmt		"core:fmt"
import os		"core:os"
import strings	"core:strings"
import slice	"core:slice"
import win32	"core:sys/windows"

file :: struct
{
	Data : []u8,
	Ptr : uint,
}

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

DefineTable : map[string]token

main :: proc()
{
	Args := os.args
	InputFileName : string
	OutputFileName : string
	OutputFileNameW : [^]u16

	if len(Args) > 1
	{
		InputFileName = Args[1]

		Temp := strings.split(InputFileName, "\\")
		OutputFileName = strings.split(Temp[len(Temp) - 1], ".")[0]
		OutputFileName = strings.concatenate([]string{OutputFileName, string(".o")})

		OutputFileNameW = win32.utf8_to_wstring(OutputFileName)

		fmt.println(OutputFileName)
	}
	else
	{
		fmt.println("No input file specified...!")
		return
	}

	FileContents := StringFile(InputFileName)

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

	// Validate tokens in order
	for LineNumber in LineNumbers
	{
		Tokens := TokenSet[LineNumber]
		// fmt.println(LineNumber, Tokens)
		ValidateTokens(Tokens[:])
	}

	// Report errors
	slice.sort_by(gErrors[:], SortErrors)
	for Error in gErrors
	{
		fmt.printf("%s(%d)", strings.clone_to_cstring(InputFileName), Error.LineNumber)
		fmt.printf(" Error: ")
		fmt.printf("%s\n", strings.clone_to_cstring(Error.Message))
	}

	// fmt.println(DefineTable)

	// Generate code
	if len(gErrors) == 0
	{
		File : file
		File.Data = make([]u8, 64000)

		for LineNumber in LineNumbers
		{
			Tokens := TokenSet[LineNumber]
			GenerateCode(Tokens[:], &File)
		}

		hFile : win32.HANDLE
		BytesWritten : win32.DWORD

		hFile = win32.CreateFileW(OutputFileNameW, win32.GENERIC_WRITE, 0, nil, win32.CREATE_ALWAYS, win32.FILE_ATTRIBUTE_NORMAL, nil)
		win32.WriteFile(hFile, rawptr(&File.Data[0]), u32(File.Ptr), &BytesWritten, nil)
		win32.CloseHandle(hFile)

		fmt.println("Wrote", BytesWritten, "bytes to", OutputFileName)
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
	else if token_type.BYTE <= Instruction.Type && Instruction.Type <= token_type.DEFINE
	{
		if len(Tokens[1:]) == 1
		{
			Constant := Tokens[1]

			if Instruction.Type == token_type.BYTE
			{
				if Constant.Type != token_type.NUMBER8
				{
					ReportError(CurrentLine, ".BYTE directive must take a byte constant")
				}
			}
			else // Instruction.Type == token_type.WORD
			{
				if Constant.Type != token_type.NUMBER16
				{
					ReportError(CurrentLine, ".WORD directive must take a word constant")
				}
			}
		}
		else if len(Tokens[1:]) == 2
		{
			Name := Tokens[1]
			Value := Tokens[2]

			if Name.Type == token_type.IDENTIFIER
			{
				if (Value.Type == token_type.ADDRESS8) ||
				   (Value.Type == token_type.ADDRESS16) ||
				   (Value.Type == token_type.NUMBER8)
			   {
				   DefineTable[Name.Lexeme] = Value
			   }
			   else
			   {
				   ReportError(CurrentLine, "Must be an 8bit or 16bit address OR an 8bit constant")
			   }
			}
			else
			{
				ReportError(CurrentLine, "Define symbol must be an identifier")
			}
		}
		else
		{
			ReportError(CurrentLine, "Wrong number of arguments for a directive")
		}

		return
	}
	else
	{
		ReportError(CurrentLine, "Code must start with an instruction or directive")
		return
	}

	RemainingTokens := Tokens[1:]
	TokenCount := len(RemainingTokens)

	for Token, Index in RemainingTokens
	{
		if Token.Type == token_type.IDENTIFIER
		{
			NewToken, Exists := DefineTable[Token.Lexeme]
			if !Exists
			{
				ReportError(CurrentLine, strings.concatenate([]string{"Unknown symbol", Token.Lexeme}))
				return
			}
			else
			{
				RemainingTokens[Index] = NewToken
			}
		}
	}

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

		if Arg.Type == token_type.A
		{
			if Opcode.Accumulator == 0
			{
				ReportError(CurrentLine, "This instruction does not support accumulator")
			}
		}
		else if Arg.Type == token_type.NUMBER8 // Immediate
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
				if Args[2].Type == token_type.X
				{
					if Opcode.ZeroPageX == 0
					{
						ReportError(CurrentLine, "This instruction does not support ZeroPageX")
					}
				}
				else if Args[2].Type == token_type.Y
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
				if Args[2].Type == token_type.X
				{
					if Opcode.AbsoluteX == 0
					{
						ReportError(CurrentLine, "This instruction does not support AbsoluteX")
					}
				}
				else if Args[2].Type == token_type.Y
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
					if Args[3].Type == token_type.X
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
						if Args[4].Type == token_type.Y
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

GenerateCode :: proc(Tokens : []token, File : ^file)
{
	Opcode : opcode
	CurrentLine := Tokens[0].LineNumber

	Instruction := Tokens[0]

	if Instruction.Type == token_type.BYTE || Instruction.Type == token_type.WORD
	{
		Constant := Tokens[1]

		if Instruction.Type == token_type.BYTE
		{
			File.Data[File.Ptr] = Constant.Literal.(u8)
			File.Ptr += 1
		}
		else
		{
			File.Data[File.Ptr]     = u8(0x00FF & Constant.Literal.(u16)) // lo-byte
			File.Data[File.Ptr + 1] = u8((0xFF00 & Constant.Literal.(u16)) >> 8) // hi-byte
			File.Ptr += 2
		}

		return
	}

	Opcode = gOpcodeTable[Instruction.Type]

	if Opcode.Implicit != 0 || Instruction.Type == token_type.BRK
	{
		File.Data[File.Ptr] = Opcode.Implicit

		File.Ptr += 1
		return
	}

	TokenCount := len(Tokens[1:])

	if TokenCount == 1
	{
		Arg := Tokens[1]

		if Arg.Type == token_type.IDENTIFIER
		{
			Arg = DefineTable[Arg.Lexeme]
		}

		if Arg.Type == token_type.NUMBER8 // Immediate
		{
			File.Data[File.Ptr] = Opcode.Immediate
			File.Data[File.Ptr + 1] = Arg.Literal.(u8)
			File.Ptr += 2

			return
		}
		else if Arg.Type == token_type.ADDRESS8 // ZeroPage
		{
			File.Data[File.Ptr] = Opcode.ZeroPage
			File.Data[File.Ptr + 1] = Arg.Literal.(u8)
			File.Ptr += 2

			return
		}
		else if Arg.Type == token_type.ADDRESS16 // Absolute
		{
			File.Data[File.Ptr] = Opcode.Absolute
			File.Data[File.Ptr + 1] = u8(0x00FF & Arg.Literal.(u16)) // lo-byte
			File.Data[File.Ptr + 2] = u8((0xFF00 & Arg.Literal.(u16)) >> 8) // hi-byte
			File.Ptr += 3

			return
		}
		else
		{
			File.Data[File.Ptr] = Opcode.Accumulator
			File.Ptr += 1

			return
		}
	}
	else if TokenCount == 3
	{
		Args := Tokens[1:]

		if Args[0].Type == token_type.ADDRESS8 // ZeroPageX, ZeroPageY
		{
			if Args[2].Type == token_type.X
			{
				File.Data[File.Ptr] = Opcode.ZeroPageX
			}
			else if Args[2].Type == token_type.Y
			{
				File.Data[File.Ptr] = Opcode.ZeroPageY
			}
			File.Data[File.Ptr + 1] = Args[0].Literal.(u8)
			File.Ptr += 2

			return
		}
		else if Args[0].Type == token_type.ADDRESS16 // AbsoluteX, AbsoluteY
		{
			if Args[2].Type == token_type.X
			{
				File.Data[File.Ptr] = Opcode.AbsoluteX
			}
			else if Args[2].Type == token_type.Y
			{
				File.Data[File.Ptr] = Opcode.AbsoluteY
			}
			File.Data[File.Ptr + 1] = u8(0x00FF & Args[0].Literal.(u16)) // lo-byte
			File.Data[File.Ptr + 2] = u8((0xFF00 & Args[0].Literal.(u16)) >> 8) // hi-byte
			File.Ptr += 3

			return
		}
		else if Args[0].Type == token_type.LEFT_PAREN // Indirect
		{
			File.Data[File.Ptr] = Opcode.Indirect
			File.Data[File.Ptr + 1] = u8(0x00FF & Args[1].Literal.(u16)) // lo-byte
			File.Data[File.Ptr + 2] = u8((0xFF00 & Args[1].Literal.(u16)) >> 8) // hi-byte
			File.Ptr += 3

			return
		}
	}
	else if TokenCount == 5
	{
		Args := Tokens[1:]

		if Args[2].Type == token_type.COMMA // IndirectX
		{
			File.Data[File.Ptr] = Opcode.IndirectX
			File.Data[File.Ptr + 1] = Args[1].Literal.(u8)
			File.Ptr += 2

			return
		}
		else if Args[2].Type == token_type.RIGHT_PAREN // IndirectY
		{
			File.Data[File.Ptr] = Opcode.IndirectY
			File.Data[File.Ptr + 1] = Args[1].Literal.(u8)
			File.Ptr += 2

			return
		}
	}
}

