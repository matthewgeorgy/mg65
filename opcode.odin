package main

import fmt "core:fmt"

opcode :: struct
{
						// Token count
	Implicit : u8, 		// 1: INT
	Branch : u8,		// 2: INT Label
	Accumulator : u8,	// 2: INT A
	Immediate : u8, 	// 2: INT #$44
	ZeroPage : u8, 		// 2: INT $44
	ZeroPageX : u8, 	// 4: INT $44 , X
	ZeroPageY : u8, 	// 4: INT $44 , Y
	Absolute : u8, 		// 2: INT $4400
	AbsoluteX : u8, 	// 4: INT $4400 , X
	AbsoluteY : u8, 	// 4: INT $4400 , Y
	IndirectX : u8,		// 5: INT ( $44 , X )
	IndirectY : u8,		// 5: INT ( $44 ) , Y
	Indirect : u8, 		// 4: INT ( $4400 )
}

gOpcodeTable : map[token_type]opcode

InitializeOpcodeTable :: proc(Table : ^map[token_type]opcode)
{
	Table[token_type.ADC] = opcode{Immediate = 0x69, ZeroPage = 0x65, ZeroPageX = 0x75, Absolute = 0x6D, AbsoluteX = 0x7D, AbsoluteY = 0x79, IndirectX = 0x61, IndirectY = 0x71}
	Table[token_type.AND] = opcode{Immediate = 0x29, ZeroPage = 0x25, ZeroPageX = 0x35, Absolute  = 0x2D, AbsoluteX = 0x3D, AbsoluteY = 0x39, IndirectX = 0x21, IndirectY = 0x31}
	Table[token_type.ASL] = opcode{Accumulator = 0x0A, ZeroPage = 0x06, ZeroPageX = 0x16, Absolute = 0x0E, AbsoluteX = 0x1E}
	Table[token_type.BIT] = opcode{ZeroPage = 0x24, Absolute = 0x2C}

	// Branch instructions
	Table[token_type.BPL] = opcode{Branch = 0x10}
	Table[token_type.BMI] = opcode{Branch = 0x30}
	Table[token_type.BVC] = opcode{Branch = 0x50}
	Table[token_type.BVS] = opcode{Branch = 0x70}
	Table[token_type.BCC] = opcode{Branch = 0x90}
	Table[token_type.BCS] = opcode{Branch = 0xB0}
	Table[token_type.BNE] = opcode{Branch = 0xD0}
	Table[token_type.BEQ] = opcode{Branch = 0xF0}
	Table[token_type.BRK] = opcode{Implicit = 0x00}

	Table[token_type.CMP] = opcode{Immediate = 0xC9, ZeroPage = 0xC5, ZeroPageX = 0xD5, Absolute = 0xCD, AbsoluteX = 0xdd, AbsoluteY = 0xd9, IndirectX = 0xc1, IndirectY = 0xd1}
	Table[token_type.CPX] = opcode{Immediate = 0xe0, ZeroPage = 0xe4, Absolute = 0xec}
	Table[token_type.CPY] = opcode{Immediate = 0xc0, ZeroPage = 0xc4, Absolute = 0xcc}
	Table[token_type.DEC] = opcode{ZeroPage = 0xc6, ZeroPageX = 0xd6, Absolute = 0xce, AbsoluteX = 0xde}
	Table[token_type.EOR] = opcode{Immediate = 0x49, ZeroPage = 0x45, ZeroPageX = 0x55, Absolute = 0x4d, AbsoluteX = 0x5d, AbsoluteY = 0x59, IndirectX = 0x41, IndirectY = 0x51}

	// Flag instructions
	Table[token_type.CLC] = opcode{Implicit = 0x18}	
	Table[token_type.SEC] = opcode{Implicit = 0x38}	
	Table[token_type.CLI] = opcode{Implicit = 0x58}	
	Table[token_type.SEI] = opcode{Implicit = 0x78}	
	Table[token_type.CLV] = opcode{Implicit = 0xB8}	
	Table[token_type.CLD] = opcode{Implicit = 0xD8}	
	Table[token_type.SED] = opcode{Implicit = 0xF8}	

	Table[token_type.INC] = opcode{ZeroPage = 0xe6, ZeroPageX = 0xf6, Absolute = 0xee, AbsoluteX = 0xfe}
	Table[token_type.JMP] = opcode{Absolute = 0x4c, Indirect = 0x6c}
	Table[token_type.JSR] = opcode{Absolute = 0x20}
	Table[token_type.LDA] = opcode{Immediate = 0xa9, ZeroPage = 0xa5, ZeroPageX = 0xb5, Absolute = 0xad, AbsoluteX = 0xbd, AbsoluteY = 0xb9, IndirectX = 0xa1, IndirectY = 0xb1}
	Table[token_type.LDX] = opcode{Immediate = 0xa2, ZeroPage = 0xa6, ZeroPageY = 0xb6, Absolute = 0xae, AbsoluteY = 0xbe}
	Table[token_type.LDY] = opcode{Immediate = 0xa0, ZeroPage = 0xa4, ZeroPageX = 0xb4, Absolute = 0xac, AbsoluteX = 0xbc}
	Table[token_type.LSR] = opcode{Accumulator = 0x4a, ZeroPage = 0x46, ZeroPageX = 0x56, Absolute = 0x4e, AbsoluteX = 0x5e}
	Table[token_type.NOP] = opcode{Implicit = 0xea}
	Table[token_type.ORA] = opcode{Immediate = 0x09, ZeroPage = 0x05, ZeroPageX = 0x15, Absolute = 0x0d, AbsoluteX = 0x1d, AbsoluteY = 0x19, IndirectX = 0x01, IndirectY = 0x11}

	// Register instructions
	Table[token_type.TAX] = opcode{Implicit = 0xaa}
	Table[token_type.TXA] = opcode{Implicit = 0x8a}
	Table[token_type.DEX] = opcode{Implicit = 0xca}
	Table[token_type.INX] = opcode{Implicit = 0xe8}
	Table[token_type.TAY] = opcode{Implicit = 0xa8}
	Table[token_type.TYA] = opcode{Implicit = 0x98}
	Table[token_type.DEY] = opcode{Implicit = 0x88}
	Table[token_type.INY] = opcode{Implicit = 0xc8}

	Table[token_type.ROL] = opcode{Accumulator = 0x2a, ZeroPage = 0x26, ZeroPageX = 0x36, Absolute = 0x2e, AbsoluteX = 0x3e}
	Table[token_type.ROR] = opcode{Accumulator = 0x6a, ZeroPage = 0x66, ZeroPageX = 0x76, Absolute = 0x6e, AbsoluteX = 0x7e}
	Table[token_type.RTI] = opcode{Implicit = 0x40}
	Table[token_type.RTS] = opcode{Implicit = 0x60}
	Table[token_type.SBC] = opcode{Immediate = 0xe9, ZeroPage = 0xe5, ZeroPageX = 0xf5, Absolute = 0xed, AbsoluteX = 0xfd, AbsoluteY = 0xf9, IndirectX = 0xe1, IndirectY = 0xf1}
	Table[token_type.STA] = opcode{ZeroPage = 0x85, ZeroPageX = 0x95, Absolute = 0x8d, AbsoluteX = 0x9d, AbsoluteY = 0x99, IndirectX = 0x81, IndirectY = 0x91}

	// Stack instructions
	Table[token_type.TXS] = opcode{Implicit = 0x9a}
	Table[token_type.TSX] = opcode{Implicit = 0xba}
	Table[token_type.PHA] = opcode{Implicit = 0x48}
	Table[token_type.PLA] = opcode{Implicit = 0x68}
	Table[token_type.PHP] = opcode{Implicit = 0x08}
	Table[token_type.PLP] = opcode{Implicit = 0x28}

	Table[token_type.STX] = opcode{ZeroPage = 0x86, ZeroPageY = 0x96, Absolute = 0x8e}
	Table[token_type.STY] = opcode{ZeroPage = 0x84, ZeroPageX = 0x94, Absolute = 0x8c}
}


