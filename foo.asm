  LDX #$08
  BNE decrement
  DEX
  STX $0200
  CPX #$03
decrement:
  STX $0201
  BRK
