; GOLDTEX - the classic SELFTEX effect with polished gold blocks. Each pixel is a byte of the program's own machine
; code, picked by x*y/64 + t: hyperbolic bands of code, sliding as t grows, in a flowing palette. On top, the
; screen is a grid of 16x16 blocks, and the program's bytes decide which are gold: block (bx, by) is gold when
; the code byte at (16 by + bx + t/16) is a multiple of 16, so the golden blocks hop across the grid as t moves.
; A gold block is a smooth diagonal ramp, colour 132 + 4(u + v), and the palette turns the ramp into polished
; metal: a band of light, a triangle wave one tile-diagonal long, sweeps over every tile from corner to corner,
; deep gold in the troughs and white-gold in the glint. The screen is drawn in 16-pixel runs, each inside one
; block, so the block test is made once per run: 70 frames a second. Music: the code bytes in order on a
; glockenspiel, doubled an octave up, over a drum kit and a walking bass (groove.inc).
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,13h
    int 10h
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
    mov bx,100h               ; XLAT table = the program itself; time is BP, from wherever DOS left it
frame:
    xor di,di
.blk:                         ; a 16-pixel run of one block, set up from its screen offset
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; AX = y, DX = x
    imul si,ax,4              ; SI = 4y
    and al,-16                ; the block key: 16 (y/16) + (x + t)/16, which at a block's left edge
    mov cx,dx                 ; is x/16 + t/16
    add cx,bp
    shr cx,4
    add al,cl
    xlat                      ; the code byte that rules this block
    mov cx,16
    test al,15
    jnz .tex
    mov ax,si                 ; gold: no texture, a smooth diagonal ramp across the tile,
    and al,60                 ; colour 132 + 4 (u + v), u and v the pixel's place in it
    add al,132
.gold:
    stosb
    add al,4
    loop .gold
    jmp short .next
.tex:
    imul dx,si                ; DX = 256t + 4xy: its high byte is x*y/64 + t
    mov ax,bp
    add dh,al
.px:
    mov al,dh
    xlat                      ; the program's own byte: the texture
    and al,127                ; in the flowing colours 0..127
    stosb
    add dx,si
    loop .px
.next:
    test di,di                ; on to the 64 KB wrap (the last 1536 bytes are past the screen)
    jnz .blk
    inc bp
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    mov dl,0C9h               ; the palette (768 values, so the DAC index comes back to 0 each frame):
    mov ch,1                  ; (CX is 0 here) entry k = (k + t) as i, 2i, 4i for 0..128; polished gold for 129..255
.flow:
    mov ax,cx
    add ax,bp
    cmp cx,127
    ja .col
    add al,al                 ; gold: a triangle wave of (t - k) with one period per tile diagonal, so a band
    cbw                       ; of light sweeps over every tile, corner to corner: the shine
    xor al,ah
    shr al,2
    or al,32                  ; R = s, 32..63: never dark
    out dx,al
    sub al,8
    out dx,al                 ; G = s - 8
    sub al,24                 ; B = s - 32: from deep gold (32, 24, 0) to a white-gold glint (63, 55, 31)
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
