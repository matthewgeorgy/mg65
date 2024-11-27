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

	Keywords : map[string]token_type
}

CreateLexer :: proc(Lexer : ^lexer, Lines : [dynamic]string)
{
	Lexer.LinesOfCode = Lines
	Lexer.StartPos = 0
	Lexer.CurrentPos = 0
	Lexer.CurrentLine = 1

	LexerInitializeKeywordTable(Lexer)
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

		case '.':
		{
			Err = LexerDirective(Lexer)
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

	if (Type == token_type.NUMBER8)
	{
		StringValue := strings.clone_to_cstring(Text[2:])
		Literal := u8(libc.strtol(StringValue, nil, 16))
		Token = token{ Type, Text, Literal, Lexer.CurrentLine}
	}
	else if (Type == token_type.NUMBER16)
	{
		StringValue := strings.clone_to_cstring(Text[2:])
		Literal := u16(libc.strtol(StringValue, nil, 16))
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

		if DigitsCounted == 2
		{
			LexerAddToken(Lexer, token_type.NUMBER8)
		}
		else if DigitsCounted == 4
		{
			LexerAddToken(Lexer, token_type.NUMBER16)
		}
		else
		{
			ReportError(Lexer.CurrentLine, "A constant must be 1 or 2 byte(s) long")
			Err = true
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

LexerDirective :: proc(Lexer : ^lexer) -> (Err : bool)
{
	for LexerIsAlpha(LexerPeek(Lexer))
	{
		LexerAdvance(Lexer)
	}

	Text := Lexer.Source[Lexer.StartPos + 1 : Lexer.CurrentPos]
	Type, Exists := Lexer.Keywords[Text]
	if !Exists
	{
		ReportError(Lexer.CurrentLine, "Unrecognized directive")
		Err = true
	}

	LexerAddToken(Lexer, Type)

	return
}

LexerIdentifier :: proc(Lexer : ^lexer)
{
	for (LexerIsAlphaNumeric(LexerPeek(Lexer)))
	{
		LexerAdvance(Lexer)
	}

	Text := Lexer.Source[Lexer.StartPos : Lexer.CurrentPos]
	Type, Exists := Lexer.Keywords[Text]
	if !Exists
	{
		Type = token_type.IDENTIFIER
	}

	LexerAddToken(Lexer, Type)
}

LexerInitializeKeywordTable :: proc(Lexer : ^lexer)
{
	Lexer.Keywords["ADC"] = token_type.ADC
	Lexer.Keywords["AND"] = token_type.AND
	Lexer.Keywords["ASL"] = token_type.ASL
	Lexer.Keywords["BCC"] = token_type.BCC
	Lexer.Keywords["BCS"] = token_type.BCS
	Lexer.Keywords["BEQ"] = token_type.BEQ
	Lexer.Keywords["BIT"] = token_type.BIT
	Lexer.Keywords["BMI"] = token_type.BMI
	Lexer.Keywords["BNE"] = token_type.BNE
	Lexer.Keywords["BPL"] = token_type.BPL
	Lexer.Keywords["BRK"] = token_type.BRK
	Lexer.Keywords["BVC"] = token_type.BVC
	Lexer.Keywords["BVS"] = token_type.BVS
	Lexer.Keywords["CLC"] = token_type.CLC
	Lexer.Keywords["CLD"] = token_type.CLD
	Lexer.Keywords["CLI"] = token_type.CLI
	Lexer.Keywords["CLV"] = token_type.CLV
	Lexer.Keywords["CMP"] = token_type.CMP
	Lexer.Keywords["CPX"] = token_type.CPX
	Lexer.Keywords["CPY"] = token_type.CPY
	Lexer.Keywords["DEC"] = token_type.DEC
	Lexer.Keywords["DEX"] = token_type.DEX
	Lexer.Keywords["DEY"] = token_type.DEY
	Lexer.Keywords["EOR"] = token_type.EOR
	Lexer.Keywords["INC"] = token_type.INC
	Lexer.Keywords["INX"] = token_type.INX
	Lexer.Keywords["INY"] = token_type.INY
	Lexer.Keywords["JMP"] = token_type.JMP
	Lexer.Keywords["JSR"] = token_type.JSR
	Lexer.Keywords["LDA"] = token_type.LDA
	Lexer.Keywords["LDX"] = token_type.LDX
	Lexer.Keywords["LDY"] = token_type.LDY
	Lexer.Keywords["LSR"] = token_type.LSR
	Lexer.Keywords["NOP"] = token_type.NOP
	Lexer.Keywords["ORA"] = token_type.ORA
	Lexer.Keywords["PHA"] = token_type.PHA
	Lexer.Keywords["PHP"] = token_type.PHP
	Lexer.Keywords["PLA"] = token_type.PLA
	Lexer.Keywords["PLP"] = token_type.PLP
	Lexer.Keywords["ROL"] = token_type.ROL
	Lexer.Keywords["ROR"] = token_type.ROR
	Lexer.Keywords["RTI"] = token_type.RTI
	Lexer.Keywords["RTS"] = token_type.RTS
	Lexer.Keywords["SBC"] = token_type.SBC
	Lexer.Keywords["SEC"] = token_type.SEC
	Lexer.Keywords["SED"] = token_type.SED
	Lexer.Keywords["SEI"] = token_type.SEI
	Lexer.Keywords["STA"] = token_type.STA
	Lexer.Keywords["STX"] = token_type.STX
	Lexer.Keywords["STY"] = token_type.STY
	Lexer.Keywords["TAX"] = token_type.TAX
	Lexer.Keywords["TAY"] = token_type.TAY
	Lexer.Keywords["TSX"] = token_type.TSX
	Lexer.Keywords["TXA"] = token_type.TXA
	Lexer.Keywords["TXS"] = token_type.TXS
	Lexer.Keywords["TYA"] = token_type.TYA
	Lexer.Keywords["BYTE"] = token_type.BYTE
	Lexer.Keywords["WORD"] = token_type.WORD
	Lexer.Keywords["DEFINE"] = token_type.DEFINE

	Lexer.Keywords["adc"] = token_type.ADC
	Lexer.Keywords["and"] = token_type.AND
	Lexer.Keywords["asl"] = token_type.ASL
	Lexer.Keywords["bcc"] = token_type.BCC
	Lexer.Keywords["bcs"] = token_type.BCS
	Lexer.Keywords["beq"] = token_type.BEQ
	Lexer.Keywords["bit"] = token_type.BIT
	Lexer.Keywords["bmi"] = token_type.BMI
	Lexer.Keywords["bne"] = token_type.BNE
	Lexer.Keywords["bpl"] = token_type.BPL
	Lexer.Keywords["brk"] = token_type.BRK
	Lexer.Keywords["bvc"] = token_type.BVC
	Lexer.Keywords["bvs"] = token_type.BVS
	Lexer.Keywords["clc"] = token_type.CLC
	Lexer.Keywords["cld"] = token_type.CLD
	Lexer.Keywords["cli"] = token_type.CLI
	Lexer.Keywords["clv"] = token_type.CLV
	Lexer.Keywords["cmp"] = token_type.CMP
	Lexer.Keywords["cpx"] = token_type.CPX
	Lexer.Keywords["cpy"] = token_type.CPY
	Lexer.Keywords["dec"] = token_type.DEC
	Lexer.Keywords["dex"] = token_type.DEX
	Lexer.Keywords["dey"] = token_type.DEY
	Lexer.Keywords["eor"] = token_type.EOR
	Lexer.Keywords["inc"] = token_type.INC
	Lexer.Keywords["inx"] = token_type.INX
	Lexer.Keywords["iny"] = token_type.INY
	Lexer.Keywords["jmp"] = token_type.JMP
	Lexer.Keywords["jsr"] = token_type.JSR
	Lexer.Keywords["lda"] = token_type.LDA
	Lexer.Keywords["ldx"] = token_type.LDX
	Lexer.Keywords["ldy"] = token_type.LDY
	Lexer.Keywords["lsr"] = token_type.LSR
	Lexer.Keywords["nop"] = token_type.NOP
	Lexer.Keywords["ora"] = token_type.ORA
	Lexer.Keywords["pha"] = token_type.PHA
	Lexer.Keywords["php"] = token_type.PHP
	Lexer.Keywords["pla"] = token_type.PLA
	Lexer.Keywords["plp"] = token_type.PLP
	Lexer.Keywords["rol"] = token_type.ROL
	Lexer.Keywords["ror"] = token_type.ROR
	Lexer.Keywords["rti"] = token_type.RTI
	Lexer.Keywords["rts"] = token_type.RTS
	Lexer.Keywords["sbc"] = token_type.SBC
	Lexer.Keywords["sec"] = token_type.SEC
	Lexer.Keywords["sed"] = token_type.SED
	Lexer.Keywords["sei"] = token_type.SEI
	Lexer.Keywords["sta"] = token_type.STA
	Lexer.Keywords["stx"] = token_type.STX
	Lexer.Keywords["sty"] = token_type.STY
	Lexer.Keywords["tax"] = token_type.TAX
	Lexer.Keywords["tay"] = token_type.TAY
	Lexer.Keywords["tsx"] = token_type.TSX
	Lexer.Keywords["txa"] = token_type.TXA
	Lexer.Keywords["txs"] = token_type.TXS
	Lexer.Keywords["tya"] = token_type.TYA
	Lexer.Keywords["byte"] = token_type.BYTE
	Lexer.Keywords["word"] = token_type.WORD
	Lexer.Keywords["define"] = token_type.DEFINE
}


