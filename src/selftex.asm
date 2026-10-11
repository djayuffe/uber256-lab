BITS 16
CPU 386
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
    mov cx,320
    mov bx,100h               ; XLAT table = the program itself
    xor bp,bp                 ; time
.x:
    mov ax,di
    xor dx,dx
    div cx                    ; ax = y, dx = x
    imul ax,dx                ; x*y
    shr ax,6
    add ax,bp                 ; + time
    xlat                      ; AL = [100h + AL]: the program's own bytes are the texture
    stosb
    test di,di
    jnz .x
    inc bp
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    in al,60h
    dec al
    jnz .x
    mov ax,3
    int 10h
    ret
