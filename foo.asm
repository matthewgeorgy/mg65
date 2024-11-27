; .byte #$40
; .word #$1234
; .word #$5678
; .define X $45
.define C1 $4016
.define C2 $20
.define C3 #$55

ASL A
adc C3
ADC C1
LDA C2, X
LDX $5050
ADC #$4A
TSX ; this is a comment
LDA $4015 ; more

