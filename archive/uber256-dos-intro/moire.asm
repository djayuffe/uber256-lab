; MOIRE - a 131-byte DOS demo: two ring families, one orbiting the other, XORed into a moire.
; NASM: nasm -f bin moire.asm -o MOIRE.COM      Target: DOS/DOSBox, VGA, 386+
;
; Size hacks:
;  * DOS enters a .COM with AX = BX = 0, and the VGA BIOS leaves the DAC write index at 0, so
;    the palette is just streamed to port 3C9h: three OUTs per entry from one running value,
;    R = i, G = 2i, B = 4i (the DAC keeps 6 bits). 12 bytes for a dense, saturated palette.
;  * No loop nest: DI runs over the whole 64 KB segment and wraps to 0 by itself, which ends
;    the frame; x and y come from one DIV by 320 (AX = y, DX = x).
;  * No sine table: the second centre orbits on two triangle waves, |signed byte| = CBW / XOR AL,AH
;    (3 bytes), a quarter turn apart.
;  * No square roots: r^2 per family, shifted right by 7; the families are XORed, which is what
;    makes the interference pattern (a SUM of squared distances would just be one bigger circle).
;  * y - 100 fits a signed byte, so SUB AL / IMUL AL squares it in 4 bytes.
;  * The frame counter lives in the memory just past the end of the file: no initial value, so
;    nothing to store. One short wait for retrace (70 fps); Esc is read from port 60h.
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

frame:
    mov al,[t]                    ; second centre: x = 64 + tri(t), y = 36 + tri(t + 64)
    cbw
    xor al,ah                     ; |signed byte|: a triangle wave 0..127
    add al,64
    xor ah,ah
    mov si,ax
    mov al,[t]
    add al,64
    cbw
    xor al,ah
    add al,36
    xor ah,ah
    mov bp,ax
.x:
    mov ax,di
    xor dx,dx
    div cx                        ; ax = y, dx = x
    push ax
    push dx
    sub dx,160
    imul dx,dx
    sub al,100
    imul al
    add ax,dx
    shr ax,7                      ; first ring family: r^2 from the screen centre
    pop dx
    pop bx
    push ax
    sub dx,si
    imul dx,dx
    sub bx,bp
    imul bx,bx
    add bx,dx
    shr bx,7                      ; second ring family: r^2 from the orbiting centre
    pop ax
    xor ax,bx                     ; the moire
    add al,[t]                    ; the colours roll too
    stosb
    test di,di
    jnz .x                        ; DI wrapped: the frame is complete
    inc byte [t]
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs                        ; wait for vertical retrace
    in al,60h
    dec al
    jnz frame
    mov ax,3
    int 10h
    ret
t:                                ; the frame counter: just past the end of the file
