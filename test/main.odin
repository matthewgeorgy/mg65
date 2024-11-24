package main

import fmt		"core:fmt"
import strings	"core:strings"
import win32	"core:sys/windows"

main :: proc()
{
	OutputFiles := []string{
		"out/adc.o",  "out/beq.o",  "out/brk.o",  "out/cli.o",  "out/dec.o",  "out/inx.o",  "out/ldx.o",  "out/pha.o",  "out/ror.o",  "out/sed.o",  "out/tay.o",
		"out/and.o",  "out/bit.o",  "out/bvc.o",  "out/clv.o",  "out/dex.o",  "out/iny.o",  "out/ldy.o",  "out/php.o",  "out/rti.o",  "out/sei.o",  "out/tsx.o",
		"out/asl.o",  "out/bmi.o",  "out/bvs.o",  "out/cmp.o",  "out/dey.o",  "out/jmp.o",  "out/lsr.o",  "out/pla.o",  "out/rts.o",  "out/sta.o",  "out/txa.o",
		"out/bcc.o",  "out/bne.o",  "out/clc.o",  "out/cpx.o",  "out/eor.o",  "out/jsr.o",  "out/nop.o",  "out/plp.o",  "out/sbc.o",  "out/stx.o",  "out/txs.o",
		"out/bcs.o",  "out/bpl.o",  "out/cld.o",  "out/cpy.o",  "out/inc.o",  "out/lda.o",  "out/ora.o",  "out/rol.o",  "out/sec.o",  "out/sty.o",  "out/tya.o",
	}

	GoldFiles := []string{
		"gold/adc.o",  "gold/beq.o",  "gold/brk.o",  "gold/cli.o",  "gold/dec.o",  "gold/inx.o",  "gold/ldx.o",  "gold/pha.o",  "gold/ror.o",  "gold/sed.o",  "gold/tay.o",
		"gold/and.o",  "gold/bit.o",  "gold/bvc.o",  "gold/clv.o",  "gold/dex.o",  "gold/iny.o",  "gold/ldy.o",  "gold/php.o",  "gold/rti.o",  "gold/sei.o",  "gold/tsx.o",
		"gold/asl.o",  "gold/bmi.o",  "gold/bvs.o",  "gold/cmp.o",  "gold/dey.o",  "gold/jmp.o",  "gold/lsr.o",  "gold/pla.o",  "gold/rts.o",  "gold/sta.o",  "gold/txa.o",
		"gold/bcc.o",  "gold/bne.o",  "gold/clc.o",  "gold/cpx.o",  "gold/eor.o",  "gold/jsr.o",  "gold/nop.o",  "gold/plp.o",  "gold/sbc.o",  "gold/stx.o",  "gold/txs.o",
		"gold/bcs.o",  "gold/bpl.o",  "gold/cld.o",  "gold/cpy.o",  "gold/inc.o",  "gold/lda.o",  "gold/ora.o",  "gold/rol.o",  "gold/sec.o",  "gold/sty.o",  "gold/tya.o",
	}

	OutputBuffer := make([]u8, 256)
	GoldBuffer := make([]u8, 256)
	OutputRead, GoldRead : win32.DWORD
	Passed : bool

	for i := 0; i < len(OutputFiles); i += 1
	{
		OutputFileName := OutputFiles[i]
		GoldFileName := GoldFiles[i]

		OutputFileNameW := win32.utf8_to_wstring(OutputFileName)
		GoldFileNameW := win32.utf8_to_wstring(GoldFileName)

		OutputFile := win32.CreateFileW(OutputFileNameW, win32.GENERIC_READ, 0, nil, win32.OPEN_ALWAYS, win32.FILE_ATTRIBUTE_NORMAL, nil)
		GoldFile := win32.CreateFileW(GoldFileNameW, win32.GENERIC_READ, 0, nil, win32.OPEN_ALWAYS, win32.FILE_ATTRIBUTE_NORMAL, nil)

		win32.ReadFile(OutputFile, rawptr(&OutputBuffer[0]), 256, &OutputRead, nil)
		win32.ReadFile(GoldFile, rawptr(&GoldBuffer[0]), 256, &GoldRead, nil)

		fmt.printf("TEST: %s...................", strings.clone_to_cstring(OutputFileName))
		Passed = true

		if OutputRead == GoldRead
		{
			for j : win32.DWORD = 0; j < OutputRead; j += 1
			{
				if (OutputBuffer[j] != GoldBuffer[j])
				{
					Passed = false
					break
				}
			}
		}
		else
		{
			Passed = false
		}

		if Passed
		{
			fmt.printf(" PASS!\n")
		}
		else
		{
			fmt.printf(" FAIL!\n")
		}

		win32.CloseHandle(OutputFile)
		win32.CloseHandle(GoldFile)
	}
}

