package main

token_type :: enum
{
	// Single character tokens
	LEFT_PAREN, RIGHT_PAREN, COMMA,

	// Literals
	IDENTIFIER, STIRNG, NUMBER8, NUMBER16, ADDRESS8, ADDRESS16,

	// Directives
	BYTE, WORD, DEFINE,

	// Opcodes
	ADC, AND, ASL, BCC, BCS, BEQ, BIT, BMI, BNE, BPL, BRK, BVC, BVS, CLC,
	CLD, CLI, CLV, CMP, CPX, CPY, DEC, DEX, DEY, EOR, INC, INX, INY, JMP,
	JSR, LDA, LDX, LDY, LSR, NOP, ORA, PHA, PHP, PLA, PLP, ROL, ROR, RTI,
	RTS, SBC, SEC, SED, SEI, STA, STX, STY, TAX, TAY, TSX, TXA, TXS, TYA,

	EOF
}

token :: struct
{
	Type : token_type,
	Lexeme : string,
	Literal : union { u8, u16 },
	LineNumber : int
}

