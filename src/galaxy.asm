BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:                         ; a glow palette: black -> red -> orange -> white-ish
    mov al,bl
    shr al,2
    out dx,al
    shr al,1
    out dx,al
    shr al,1
    out dx,al
    inc bl
    jnz .pal
    fninit
    mov al,3                  ; PC speaker on, driven by PIT channel 2
    out 61h,al
    mov bx,data
    fld1
    fld1
frame:
    mov cx,6000
.it:
    fld st1
    fmul dword [bx]
    fsin
    fld st1
    fmul dword [bx+4]
    fcos
    fsubp st1,st0
    fld st1
    fmul dword [bx+8]
    fsin
    fld st3
    fmul dword [bx+12]
    fcos
    fsubp st1,st0
    fxch st1
    fstp st2
    fstp st2
    fld st0
    fmul dword [bx+16]
    fistp word [bx+24]
    fld st1
    fmul dword [bx+16]
    fistp word [bx+26]
    imul ax,[bx+26],320       ; y*320 + x + (100*320+160): centre the picture
    add ax,[bx+24]
    add ax,32160
    xchg ax,di
    add byte [es:di],12
    loop .it
    mov si,12                 ; morph two parameters a little every frame (a and d)
.mp:
    fld dword [bx+si]
    fadd dword [bx+20]
    fstp dword [bx+si]
    sub si,12
    jnc .mp
    mov al,[bx+24]            ; the speaker's pitch follows the attractor's x coordinate
    out 42h,al
    mov al,3
    out 42h,al
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
.dec:                         ; fade: every pixel loses 1/16 of itself, plus 1, floored at 0
    mov al,[es:di]
    mov ah,al
    shr ah,4
    sub al,ah
    sub al,1
    adc al,0
    stosb
    loop .dec                 ; CX is 0 here: 65536 passes cover the whole segment
    in al,60h
    dec al
    jnz frame
    mov ax,3
    int 10h
    ret
data:
    dd 1.4, -2.3, 2.4, -2.1, 45.0, 0.0006   ; the pixel position words live just past the end, at +24 and +26
