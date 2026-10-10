; JULIA - a Julia set in 8.8 fixed point whose constant c circles slowly (a Minsky oscillator: x += y>>5, y -= x>>5).
; No FPU, no sine table. Colour = how fast the point escapes, through a wrapping RGB palette.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:                         ; R = i, G = 2i, B = 4i (the DAC keeps 6 bits): bands of saturated colour
    mov al,bl
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    inc bl
    jnz .pal
frame:
    xor di,di
.px:
    mov ax,di
    xor dx,dx
    mov bx,320
    div bx                    ; ax = y, dx = x
    sub dx,160
    shl dx,1
    mov bx,dx                 ; bx = x  (8.8, +-1.25)
    sub ax,100
    shl ax,1
    mov si,ax                 ; si = y
    mov cx,31
.it:
    mov ax,bx
    imul bx
    shrd ax,dx,8
    push ax                   ; x*x
    mov ax,si
    imul si
    shrd ax,dx,8
    push ax                   ; y*y
    mov ax,bx
    imul si
    shrd ax,dx,7              ; 2*x*y
    add ax,[ci]
    mov si,ax                 ; y' = 2xy + cy
    pop ax                    ; y*y
    pop bx                    ; x*x
    mov dx,bx
    add dx,ax
    cmp dx,1024               ; |z|^2 > 4: escaped
    ja .out
    sub bx,ax
    add bx,[cr]               ; x' = x*x - y*y + cx
    loop .it
.out:
    mov al,cl
    shl al,3
    stosb
    cmp di,64000
    jb .px
    mov ax,[ci]               ; move c round a circle
    sar ax,5
    add [cr],ax
    mov ax,[cr]
    sar ax,5
    sub [ci],ax
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    in al,60h
    dec al
    jnz frame
    mov ax,3
    int 10h
    ret
cr: dw -180
ci: dw 0
