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
    in al,61h                 ; PC speaker on, driven by PIT channel 2
    or al,3
    out 61h,al
    mov bx,data
    fld1
    fldz
frame:
    mov cx,6000
.it:
    fld st1
    fmul dword [bx]           ; a*y
    fsin
    fld st1
    fmul dword [bx]           ; a*x
    fcos
    fmul dword [bx+8]         ; c*cos(a*x)
    faddp st1,st0             ; x' = sin(a*y) + c*cos(a*x)
    fld st1
    fmul dword [bx+4]         ; b*x
    fsin
    fld st3
    fmul dword [bx+4]         ; b*y
    fcos
    fmul dword [bx+12]        ; d*cos(b*y)
    faddp st1,st0             ; y' = sin(b*x) + d*cos(b*y)
    fxch st1
    fstp st2
    fstp st2
    fld st0
    fmul dword [bx+16]
    fistp word [bx+20]
    fld st1
    fmul dword [bx+16]
    fistp word [bx+22]
    mov ax,[bx+22]
    add ax,100
    imul ax,ax,320
    add ax,[bx+20]
    add ax,160
    mov di,ax
    add byte [es:di],4
    dec cx
    jnz .it
    fld dword [bx]            ; morph the first parameter a little every frame
    fadd dword [bx+24]
    fstp dword [bx]
    mov al,[bx+20]            ; the speaker's pitch follows the attractor's x coordinate
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
    test di,di
    jnz .dec
    in al,60h
    dec al
    jnz frame
    mov ax,3
    int 10h
    ret
data:
    dd -1.4, 1.6, 1.0, 0.7, 45.0, 0.0, 0.0004
