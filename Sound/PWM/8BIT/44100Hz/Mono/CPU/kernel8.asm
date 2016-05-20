; Raspberry Pi 3 'Bare Metal' Sound 8Bit Mono 44100Hz CPU Demo by krom (Peter Lemon):
; 1. Set 3.5" Phone Jack To PWM 
; 2. Setup PWM Sound Buffer
; 3. Play Sound Sample Using CPU & FIFO

code64
processor cpu64_v8
format binary as 'img'
include 'LIB\R_PI2.INC'

org $0000

; Return CPU ID (0..3) Of The CPU Executed On
mrs x0,MPIDR_EL1 ; X0 = Multiprocessor Affinity Register (MPIDR)
ands x0,x0,3 ; X0 = CPU ID (Bits 0..1)
b.ne CoreLoop ; IF (CPU ID != 0) Branch To Infinite Loop (Core ID 1..3)

; Set GPIO 40 & 45 (Phone Jack) To Alternate PWM Function 0
mov w0,PERIPHERAL_BASE + GPIO_BASE
mov w1,GPIO_FSEL0_ALT0
orr w1,w1,GPIO_FSEL5_ALT0
str w1,[x0,GPIO_GPFSEL4]

; Set Clock
mov w0,(PERIPHERAL_BASE + CM_BASE) and $0000FFFF
mov w1,(PERIPHERAL_BASE + CM_BASE) and $FFFF0000
orr w0,w0,w1
mov w1,CM_PASSWORD
orr w1,w1,$2000 ; Bits 0..11 Fractional Part Of Divisor = 0, Bits 12..23 Integer Part Of Divisor = 2
str w1,[x0,CM_PWMDIV]

mov w1,CM_PASSWORD
orr w1,w1,CM_ENAB
orr w1,w1,CM_SRC_OSCILLATOR ; Use Default 100MHz Clock
str w1,[x0,CM_PWMCTL]

; Set PWM
mov w0,(PERIPHERAL_BASE + PWM_BASE) and $0000FFFF
mov w1,(PERIPHERAL_BASE + PWM_BASE) and $FFFF0000
orr w0,w0,w1
mov w1,$1B4 ; Range = 8bit 44100Hz Mono
str w1,[x0,PWM_RNG1]
str w1,[x0,PWM_RNG2]

mov w1,PWM_USEF2 + PWM_PWEN2 + PWM_USEF1 + PWM_PWEN1 + PWM_CLRF1
str w1,[x0,PWM_CTL]

Loop:
  adr x1,SND_Sample ; X1 = Sound Sample
  mov w2,SND_SampleEOF and $0000FFFF ; W2 = End Of Sound Sample
  mov w3,SND_SampleEOF and $FFFF0000
  orr w2,w2,w3
  FIFO_Write:
    ldrb w3,[x1],1 ; Write 1 Byte To FIFO
    str w3,[x0,PWM_FIF1] ; FIFO Address
    FIFO_Wait:
      ldr w3,[x0,PWM_STA]
      tst w3,PWM_FULL1 ; Test Bit 1 FIFO Full
      b.ne FIFO_Wait
    cmp w1,w2 ; Check End Of Sound Sample
    b.ne FIFO_Write

  b Loop ; Play Sample Again

CoreLoop: ; Infinite Loop For Core 1..3
  b CoreLoop

SND_Sample: ; 8bit 44100Hz Unsigned Mono Sound Sample
  file 'Sample.bin'
  SND_SampleEOF: