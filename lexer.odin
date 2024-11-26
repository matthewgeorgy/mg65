package main

import fmt "core:fmt"
import strings "core:strings"
import libc "core:c/libc"

lexer :: struct
{
	LinesOfCode : [dynamic]string,
	Source : string,
	StartPos : int,
	CurrentPos : int,
	CurrentLine : int,
	Tokens : [dynamic]token,

	Opcodes : map[string]token_type
}

CreateLexer :: proc(Lexer : ^lexer, Lines : [dynamic]string)
{
	Lexer.LinesOfCode = Lines
	Lexer.StartPos = 0
	Lexer.CurrentPos = 0
	Lexer.CurrentLine = 1

	LexerInitializeOpcodeTable(Lexer)
}

LexerScanTokens :: proc(Lexer : ^lexer)
{
	for Line, LineNumber in Lexer.LinesOfCode
	{
		Lexer.Source = Line
		Lexer.StartPos = 0
		Lexer.CurrentPos = 0
		Lexer.CurrentLine = LineNumber + 1

		for !LexerIsAtEnd(Lexer)
		{
			Lexer.StartPos = Lexer.CurrentPos
			Err := LexerScanToken(Lexer)
			if Err
			{
				break
			}
		}
	}
}

LexerScanToken :: proc(Lexer : ^lexer) -> bool
{
	c := LexerAdvance(Lexer)
	Err : bool

	// TODO(matthew): need to add support for comments
	switch (c)
	{
		case '(' : { LexerAddToken(Lexer, token_type.LEFT_PAREN) }
		case ')' : { LexerAddToken(Lexer, token_type.RIGHT_PAREN) }
		case ',' : { LexerAddToken(Lexer, token_type.COMMA) }

		case ';' :
		{
			// NOTE(matthew): not actually an error, just to break out of comment
			Err = true
		}

		case ' ' :
		case '\t' :

		case '#':
		{
			Err = LexerNumber(Lexer)
		}

		case '$':
		{
			Err = LexerAddress(Lexer)
		}

		case:
		{
			if (LexerIsAlpha(c))
			{
				LexerIdentifier(Lexer)
			}
			else
			{
				ReportError(Lexer.CurrentLine, "Unexpected character")
			}
		}
	}

	return Err
}

LexerAddToken :: proc(Lexer : ^lexer, Type : token_type)
{
	Token : token
	Text := Lexer.Source[Lexer.StartPos : Lexer.CurrentPos]

	if (Type == token_type.NUMBER)
	{
		StringValue := strings.clone_to_cstring(Text[2:])
		Literal := u8(libc.strtol(StringValue, nil, 16))
		Token = token{ Type, Text, Literal, Lexer.CurrentLine}
	}
	else if (Type == token_type.ADDRESS8)
	{
		StringValue := strings.clone_to_cstring(Text[1:])
		Literal := u8(libc.strtol(StringValue, nil, 16))
		Token = token{ Type, Text, Literal, Lexer.CurrentLine}
	}
	else if (Type == token_type.ADDRESS16)
	{
		StringValue := strings.clone_to_cstring(Text[1:])
		Literal := u16(libc.strtol(StringValue, nil, 16))
		Token = token{ Type, Text, Literal, Lexer.CurrentLine}
	}
	else
	{
		Token = token{ Type, Text, u8(0), Lexer.CurrentLine}
	}

	append(&Lexer.Tokens, Token)
}

LexerAdvance :: proc(Lexer : ^lexer) -> u8
{
	C := Lexer.Source[Lexer.CurrentPos]
	Lexer.CurrentPos += 1

	return C
}

LexerIsAtEnd :: proc(Lexer : ^lexer) -> bool
{
	return (Lexer.CurrentPos >= len(Lexer.Source))
}

LexerMatch :: proc(Lexer : ^lexer, Expected : u8) -> bool
{
	if (LexerIsAtEnd(Lexer))
	{
		return false
	}

	if (Lexer.Source[Lexer.CurrentPos] != Expected)
	{
		return (false)
	}

	Lexer.CurrentPos += 1

	return true
}

LexerIsAlpha :: proc(C : u8) -> bool
{
	return ((C >= 'a' && C <= 'z') ||
		    (C >= 'A' && C <= 'Z') ||
	        (C == '_'))

}

LexerIsDigit :: proc(c : u8) -> bool
{
	return (c >= '0' && c <= '9')
}

LexerPeek :: proc(Lexer : ^lexer) -> u8
{
	if (LexerIsAtEnd(Lexer))
	{
		return 0
	}

	return Lexer.Source[Lexer.CurrentPos]
}

LexerAddress :: proc(Lexer : ^lexer) -> (Err : bool)
{
	DigitsCounted := 0
	for LexerIsHex(LexerPeek(Lexer))
	{
		LexerAdvance(Lexer)
		DigitsCounted += 1
	}

	if (DigitsCounted == 2)
	{
		LexerAddToken(Lexer, token_type.ADDRESS8)
	}
	else if (DigitsCounted == 4)
	{
		LexerAddToken(Lexer, token_type.ADDRESS16)
	}
	else
	{
		ReportError(Lexer.CurrentLine, "An absolute address must be either 1 or 2 bytes long")
		Err = true
	}

	return
}

LexerNumber :: proc(Lexer : ^lexer) -> (Err : bool)
{
	Err = false
	c := LexerAdvance(Lexer)

	if (c != '$')
	{
		ReportError(Lexer.CurrentLine, "Syntax error, expected $")
		Err = true
	}
	else
	{
		DigitsCounted := 0
		for LexerIsHex(LexerPeek(Lexer))
		{
			LexerAdvance(Lexer)
			DigitsCounted += 1
		}

		if (DigitsCounted != 2)
		{
			ReportError(Lexer.CurrentLine, "A constant must be 1 byte long")
			Err = true
		}
		else
		{
			// Lexer.Start += 2
			LexerAddToken(Lexer, token_type.NUMBER)
		}
	}

	return
}

LexerIsHex :: proc(C : u8) -> bool
{
	return (LexerIsDigit(C) || ('A' <= C  && C <= 'F') || ('a' <= C  && C <= 'f'))
}

LexerIsAlphaNumeric :: proc(C : u8) -> bool
{
	return (LexerIsAlpha(C) || LexerIsDigit(C))
}

LexerIdentifier :: proc(Lexer : ^lexer)
{
	for (LexerIsAlphaNumeric(LexerPeek(Lexer)))
	{
		LexerAdvance(Lexer)
	}

	Text := Lexer.Source[Lexer.StartPos : Lexer.CurrentPos]
	Type, Exists := Lexer.Opcodes[Text]
	if !Exists
	{
		Type = token_type.IDENTIFIER
	}

	LexerAddToken(Lexer, Type)
}

LexerInitializeOpcodeTable :: proc(Lexer : ^lexer)
{
	Lexer.Opcodes["ADC"] = token_type.ADC
	Lexer.Opcodes["AND"] = token_type.AND
	Lexer.Opcodes["ASL"] = token_type.ASL
	Lexer.Opcodes["BCC"] = token_type.BCC
	Lexer.Opcodes["BCS"] = token_type.BCS
	Lexer.Opcodes["BEQ"] = token_type.BEQ
	Lexer.Opcodes["BIT"] = token_type.BIT
	Lexer.Opcodes["BMI"] = token_type.BMI
	Lexer.Opcodes["BNE"] = token_type.BNE
	Lexer.Opcodes["BPL"] = token_type.BPL
	Lexer.Opcodes["BRK"] = token_type.BRK
	Lexer.Opcodes["BVC"] = token_type.BVC
	Lexer.Opcodes["BVS"] = token_type.BVS
	Lexer.Opcodes["CLC"] = token_type.CLC
	Lexer.Opcodes["CLD"] = token_type.CLD
	Lexer.Opcodes["CLI"] = token_type.CLI
	Lexer.Opcodes["CLV"] = token_type.CLV
	Lexer.Opcodes["CMP"] = token_type.CMP
	Lexer.Opcodes["CPX"] = token_type.CPX
	Lexer.Opcodes["CPY"] = token_type.CPY
	Lexer.Opcodes["DEC"] = token_type.DEC
	Lexer.Opcodes["DEX"] = token_type.DEX
	Lexer.Opcodes["DEY"] = token_type.DEY
	Lexer.Opcodes["EOR"] = token_type.EOR
	Lexer.Opcodes["INC"] = token_type.INC
	Lexer.Opcodes["INX"] = token_type.INX
	Lexer.Opcodes["INY"] = token_type.INY
	Lexer.Opcodes["JMP"] = token_type.JMP
	Lexer.Opcodes["JSR"] = token_type.JSR
	Lexer.Opcodes["LDA"] = token_type.LDA
	Lexer.Opcodes["LDX"] = token_type.LDX
	Lexer.Opcodes["LDY"] = token_type.LDY
	Lexer.Opcodes["LSR"] = token_type.LSR
	Lexer.Opcodes["NOP"] = token_type.NOP
	Lexer.Opcodes["ORA"] = token_type.ORA
	Lexer.Opcodes["PHA"] = token_type.PHA
	Lexer.Opcodes["PHP"] = token_type.PHP
	Lexer.Opcodes["PLA"] = token_type.PLA
	Lexer.Opcodes["PLP"] = token_type.PLP
	Lexer.Opcodes["ROL"] = token_type.ROL
	Lexer.Opcodes["ROR"] = token_type.ROR
	Lexer.Opcodes["RTI"] = token_type.RTI
	Lexer.Opcodes["RTS"] = token_type.RTS
	Lexer.Opcodes["SBC"] = token_type.SBC
	Lexer.Opcodes["SEC"] = token_type.SEC
	Lexer.Opcodes["SED"] = token_type.SED
	Lexer.Opcodes["SEI"] = token_type.SEI
	Lexer.Opcodes["STA"] = token_type.STA
	Lexer.Opcodes["STX"] = token_type.STX
	Lexer.Opcodes["STY"] = token_type.STY
	Lexer.Opcodes["TAX"] = token_type.TAX
	Lexer.Opcodes["TAY"] = token_type.TAY
	Lexer.Opcodes["TSX"] = token_type.TSX
	Lexer.Opcodes["TXA"] = token_type.TXA
	Lexer.Opcodes["TXS"] = token_type.TXS
	Lexer.Opcodes["TYA"] = token_type.TYA

	Lexer.Opcodes["adc"] = token_type.ADC
	Lexer.Opcodes["and"] = token_type.AND
	Lexer.Opcodes["asl"] = token_type.ASL
	Lexer.Opcodes["bcc"] = token_type.BCC
	Lexer.Opcodes["bcs"] = token_type.BCS
	Lexer.Opcodes["beq"] = token_type.BEQ
	Lexer.Opcodes["bit"] = token_type.BIT
	Lexer.Opcodes["bmi"] = token_type.BMI
	Lexer.Opcodes["bne"] = token_type.BNE
	Lexer.Opcodes["bpl"] = token_type.BPL
	Lexer.Opcodes["brk"] = token_type.BRK
	Lexer.Opcodes["bvc"] = token_type.BVC
	Lexer.Opcodes["bvs"] = token_type.BVS
	Lexer.Opcodes["clc"] = token_type.CLC
	Lexer.Opcodes["cld"] = token_type.CLD
	Lexer.Opcodes["cli"] = token_type.CLI
	Lexer.Opcodes["clv"] = token_type.CLV
	Lexer.Opcodes["cmp"] = token_type.CMP
	Lexer.Opcodes["cpx"] = token_type.CPX
	Lexer.Opcodes["cpy"] = token_type.CPY
	Lexer.Opcodes["dec"] = token_type.DEC
	Lexer.Opcodes["dex"] = token_type.DEX
	Lexer.Opcodes["dey"] = token_type.DEY
	Lexer.Opcodes["eor"] = token_type.EOR
	Lexer.Opcodes["inc"] = token_type.INC
	Lexer.Opcodes["inx"] = token_type.INX
	Lexer.Opcodes["iny"] = token_type.INY
	Lexer.Opcodes["jmp"] = token_type.JMP
	Lexer.Opcodes["jsr"] = token_type.JSR
	Lexer.Opcodes["lda"] = token_type.LDA
	Lexer.Opcodes["ldx"] = token_type.LDX
	Lexer.Opcodes["ldy"] = token_type.LDY
	Lexer.Opcodes["lsr"] = token_type.LSR
	Lexer.Opcodes["nop"] = token_type.NOP
	Lexer.Opcodes["ora"] = token_type.ORA
	Lexer.Opcodes["pha"] = token_type.PHA
	Lexer.Opcodes["php"] = token_type.PHP
	Lexer.Opcodes["pla"] = token_type.PLA
	Lexer.Opcodes["plp"] = token_type.PLP
	Lexer.Opcodes["rol"] = token_type.ROL
	Lexer.Opcodes["ror"] = token_type.ROR
	Lexer.Opcodes["rti"] = token_type.RTI
	Lexer.Opcodes["rts"] = token_type.RTS
	Lexer.Opcodes["sbc"] = token_type.SBC
	Lexer.Opcodes["sec"] = token_type.SEC
	Lexer.Opcodes["sed"] = token_type.SED
	Lexer.Opcodes["sei"] = token_type.SEI
	Lexer.Opcodes["sta"] = token_type.STA
	Lexer.Opcodes["stx"] = token_type.STX
	Lexer.Opcodes["sty"] = token_type.STY
	Lexer.Opcodes["tax"] = token_type.TAX
	Lexer.Opcodes["tay"] = token_type.TAY
	Lexer.Opcodes["tsx"] = token_type.TSX
	Lexer.Opcodes["txa"] = token_type.TXA
	Lexer.Opcodes["txs"] = token_type.TXS
	Lexer.Opcodes["tya"] = token_type.TYA
}


