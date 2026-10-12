; GOLDTEX - the classic SELFTEX effect with golden blocks. Each pixel is a byte of the program's own machine
; code, picked by x*y/64 + t: hyperbolic bands of code, sliding as t grows, in a flowing palette. On top, the
; screen is a grid of 16x16 blocks, and the program's bytes decide which are gold: block (bx, by) is gold when
; the code byte at (16 by + bx + t/16) is a multiple of 16, so the golden blocks hop across the grid as t
; moves. A gold block shows the same code texture in the bright half of a gold ramp whose palette cycles, so it
; glitters. The screen is drawn in 16-pixel runs, each inside one block, so the block test is made once per run and
; a pixel is seven instructions: 70 frames a second. Music: the code bytes in order on a glockenspiel, doubled an
; octave up, over a drum kit and a walking bass (groove.inc).
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,13h
    int 10h
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
    mov bx,100h               ; XLAT table = the program itself
    xor bp,bp                 ; time
frame:
    xor di,di
.blk:                         ; a 16-pixel run of one block, set up from its screen offset
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; AX = y, DX = x
    imul si,ax,4              ; SI = 4y
    and al,-16                ; the block key: 16 (y/16) + x/16 + t/16
    mov cx,dx
    shr cx,4
    add al,cl
    mov cx,bp
    shr cx,4
    add al,cl
    xlat                      ; the code byte that rules this block
    mov ah,0C0h               ; a multiple of 16: AH = C0h, gold (colours 192..255)
    test al,15
    jz .gold
    mov ah,0                  ; otherwise AH = 0
.gold:
    imul dx,si                ; DX = 256t + 4xy: its high byte is x*y/64 + t
    mov cx,bp
    add dh,cl
    mov cx,16
.px:
    mov al,dh
    xlat                      ; the program's own byte: the texture
    and al,127                ; the flowing colours 0..127, or gold
    or al,ah
    stosb
    add dx,si
    loop .px
    test di,di                ; on to the 64 KB wrap (the last 1536 bytes are past the screen)
    jnz .blk
    inc bp
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    mov dl,0C9h               ; the palette (768 values, so the DAC index comes back to 0 each frame):
    mov cx,256                ; entry k = (k + t) as i, 2i, 4i for 0..191, a cycling gold ramp for 192..255
.flow:
    mov ax,cx
    add ax,bp
    cmp cx,64
    ja .col
    add ax,bp                 ; gold, cycling twice as fast: it glitters
    and al,63
    or al,32                  ; and kept in the bright half of the ramp
    out dx,al                 ; R = s
    mov ah,al
    shr ah,2
    sub al,ah
    out dx,al                 ; G = 3s/4
    mov al,ah
    jmp short .b
.col:
    out dx,al
    add al,al
    out dx,al
    add al,al
.b:
    out dx,al
    loop .flow
    ESC_OR_LOOP frame
isr:                          ; INT 1Ch, 18.2 Hz; BX = 100h in the main loop
    pusha
    MIDI_START 9              ; program 9: glockenspiel
    mov ax,[fs:46Ch]
    shr ax,1
    jc .q
    cs xlat                   ; the code byte
    and al,30
    add al,46
    PENTA                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    out dx,al                 ; note
    out dx,al                 ; velocity = note
    add al,12                 ; doubled an octave up
    out dx,al
    out dx,al
.q:
%include "groove.inc"
    popa
    iret
