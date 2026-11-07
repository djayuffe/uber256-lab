; UBER128 - a 128-byte-class DOS demo, in 79 bytes: rainbow rings, endlessly flowing out
; of the screen centre.
; NASM: nasm -f bin src/uber128.asm -o UBER128.COM      Target: DOS/DOSBox, VGA, 386+
;
; Size hacks:
;  * y - 100 is -100..104, a signed byte, so SUB AL / IMUL AL (4 bytes) square it instead of
;    the 6-byte 16-bit forms. (x - 160 does not fit a byte.)
;  * DOS enters a .COM with BX = 0, so BL is the palette index and then the frame counter
;    with no setup, and AX = 0 so `mov al,13h` is enough for the mode set.
;  * The VGA BIOS leaves the DAC write index at 0 after a mode set, so the palette is
;    simply streamed to port 3C9h: three OUTs per entry from one running value:
;    R = i, G = 2i, B = 4i (the DAC keeps 6 bits). Nothing but doubling, yet it gives a
;    dense, saturated, seamless-looking rainbow.
;  * There is no pixel loop nest. DI runs over the whole 64 KB segment and wraps to 0 by
;    itself, which ends the frame; x and y come from one DIV by 320 (AX = y, DX = x).
;  * r^2 = dx^2 + dy^2 instead of a square root; the colour is r^2/64 + frame counter.
;  * One short wait for retrace (70 fps); Esc is read straight from port 60h.
BITS 16
ORG 100h

    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:
    mov al,bl
    out dx,al                     ; R = i
    add al,al
    out dx,al                     ; G = 2i
    add al,al
    out dx,al                     ; B = 4i
    inc bl
    jnz .pal
    mov cx,320
.x:
    mov ax,di
    xor dx,dx
    div cx                        ; ax = y, dx = x
    sub dx,160
    imul dx,dx
    sub al,100                    ; y - 100 fits a signed byte, so the one-byte-operand
    imul al                       ; IMUL (AX = AL * AL) squares it in 2 bytes
    add ax,dx                     ; r^2 from the screen centre
    shr ax,6
    add al,bl                     ; the colours roll with the frame counter
    stosb
    test di,di
    jnz .x                        ; DI wrapped: the frame is complete
    inc bx
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs                        ; wait for vertical retrace
    in al,60h
    dec al
    jnz .x                        ; not Esc: next frame
    mov ax,3
    int 10h
    ret
