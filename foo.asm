; .byte #$40
; .word #$1234
; .word #$5678
; .define X $45
; .define Z $4016

ASL A
ADC A
LDA $5050, A
ADC #$4A
TSX ; this is a comment
LDA $4015 ; more

