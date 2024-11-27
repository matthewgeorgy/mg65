; .byte #$40
; .word #$1234
; .word #$5678
.define X $45
.define Z $4016

ADC #$4A
ADC X
TSX ; this is a comment
LDA $4015 ; more
LDA Z ; more

