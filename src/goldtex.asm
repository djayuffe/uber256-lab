; GOLDTEX - the classic SELFTEX effect with golden blocks. Each pixel is a byte of the program's own machine
; code, picked by x*y/64 + t: hyperbolic bands of code, sliding as t grows, in a flowing palette. On top, the
; screen is a grid of 16x16 blocks, and the program's bytes decide which are gold: block (bx, by) is gold when
; the code byte at (16 by + bx + t/16) is a multiple of 16, so the golden blocks hop across the grid as t
; moves. A gold block shows the same code texture
; in the bright half of a gold ramp whose palette cycles, so it glitters. Music: the code bytes in order on a
; glockenspiel, doubled an octave up, over a drum kit and a walking bass (groove.inc).
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    mov ax,351Ch              ; hook the timer tick (INT 1Ch), keeping the old vector on the stack
    int 21h
    push es
    push bx
    mov ah,25h
    mov dx,isr
    int 21h
    push ax                   ; AX = 251Ch, for the unhook
    push word 0A000h
    pop es
    mov cx,320
    mov bx,100h               ; XLAT table = the program itself
    xor bp,bp                 ; time
.x:
    mov ax,di
    xor dx,dx
    div cx                    ; ax = y, dx = x
    mov si,ax                 ; y
    push dx                   ; x
    imul ax,dx                ; x*y
    shr ax,6
    add ax,bp                 ; + time
    xlat                      ; AL = [100h + AL]: the program's own bytes are the texture
    pop dx                    ; x
    xchg ax,dx                ; DL = the texel, AX = x
    shr ax,4                  ; the block: x/16 ...
    and si,-16
    add ax,si                 ; ... + 16 (y/16) ...
    mov si,bp
    shr si,4
    add ax,si                 ; ... + t/16
    xlat                      ; the code byte that rules this block
    test al,15
    xchg ax,dx                ; AL = the texel (XCHG keeps the flags)
    jnz .plain
    or al,0C0h                ; gold: colours 192..255
    db 3Dh                    ; (cmp ax,imm16: swallows the two-byte and below)
.plain:
    and al,127                ; the flowing colours 0..127
    stosb
    test di,di
    jnz .x
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
    mov cx,320
    in al,60h
    cbw
    dec ax
    jnz .x                    ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h                   ; text mode
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
isr:                          ; INT 1Ch, 18.2 Hz; BX = 100h in the main loop
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h to the MPU data port, then 3Fh (UART mode) to its command port
    out dx,ax
    mov al,9                  ; program 9: glockenspiel
    out dx,al
    mov al,90h                ; note on
    out dx,al
    mov ax,[fs:46Ch]
    shr ax,1
    jc .q
    cs xlat                   ; the code byte
    and al,30
    add al,46
    aam 5                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    aad 6
    out dx,al                 ; note
    out dx,al                 ; velocity = note
    add al,12                 ; doubled an octave up
    out dx,al
    out dx,al
.q:
%include "groove.inc"
    popa
    iret
