; UBER256 - a 256-byte-class DOS demo, in 141 bytes: an XOR rotozoomer.
; NASM: nasm -f bin src/uber256.asm -o UBER256.COM      Target: DOS/DOSBox, VGA, 386+
;
; An XOR texture, the top byte of (u ^ v), rotating about the screen centre, with a
; rolling rainbow palette.
;
; Size hacks:
;  * No multiplies and no sine table. (c, s) is a vector rotated a little every frame
;    by Minsky's trick (c -= s>>5; s += c>>5), which traces a near-perfect circle. It is
;    held in 16.16 fixed point in 32-bit registers: with 16-bit values the truncation of
;    the shifts made the circle spiral inwards within a few seconds. The
;    texture coordinates then just ACCUMULATE: u += c and v += s along a row, u -= s and
;    v += c from row to row. Two ADDs per pixel replace four IMULs.
;  * The top-left corner's coordinates (u0, v0) = (-160c + 100s, -160s - 100c) are the
;    centre offset rotated by the same angle, so they are rotated by the same Minsky step
;    in the same loop as (c, s): the image turns about the screen centre, not a corner.
;  * Data lives right after the code, addressed through BX ([bx], [bx+4], ... are 2-3
;    byte operands). Only the initial vector is in the file; the rest of the block (the
;    row accumulators and the colour counter) needs no initial value and is not stored.
;  * DOS enters with BX = 0 and AX = 0; the DAC write index is 0 after the mode set, so
;    the palette streams straight to 3C9h (R = i, G = 2i, B = 4i; the DAC keeps 6 bits).
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
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    inc bl
    jnz .pal
    mov bx,data

frame:
    mov si,bx                     ; Minsky step for (c, s) and then for (u0, v0)
    mov cx,2
.m:
    mov eax,[si+4]
    sar eax,5
    sub [si],eax
    mov eax,[si]
    sar eax,5
    add [si+4],eax
    add si,8
    loop .m
    mov eax,[bx+8]                ; the first row starts at (u0, v0)
    mov [bx+16],eax
    mov eax,[bx+12]
    mov [bx+20],eax
    xor di,di
    mov dx,200
.y:
    mov ebp,[bx+16]
    mov esi,[bx+20]
    mov cx,320
.x:
    add ebp,[bx]                  ; u += c
    add esi,[bx+4]                ; v += s
    mov eax,ebp
    xor eax,esi
    shr eax,24                    ; index = the top byte of u ^ v
    add al,[bx+24]                ; the colours roll with time
    stosb
    loop .x
    mov eax,[bx+4]
    sub [bx+16],eax               ; next row: u -= s
    mov eax,[bx]
    add [bx+20],eax               ;            v += c
    dec dx
    jnz .y
    inc byte [bx+24]
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

data:                             ; 16.16 fixed point: |(c, s)| = 56 texture units per pixel
    dd 56 << 16, 0                ; c, s
    dd -160 * 56 << 16            ; u0 = -160 c
    dd -100 * 56 << 16            ; v0 = -100 c
