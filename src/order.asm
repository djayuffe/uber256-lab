; ORDER - geometry from orderings, not distances. Three cheap per-pixel expressions
;   a = (x*y)/64 + t   (hyperbolas)     b = x - 2t   (vertical lines)     c = 3y + t   (horizontal lines)
; are never drawn. Only their ORDER is: three comparisons give one of the six orderings (as 3 bits, via the
; carry flag), which picks a band of the palette, and a shades it. As t moves, regions fold, collide and swap.
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
frame:
    xor di,di
.px:
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; ax = y, dx = x
    mov bx,ax                 ; a = (x*y)/64 + t
    imul bx,dx
    sar bx,6
    add bl,byte [t]
    mov cl,dl                 ; b = x - 2t
    sub cl,byte [t]
    sub cl,byte [t]
    mov ch,al                 ; c = 3y + t
    add ch,al
    add ch,al
    add ch,byte [t]
    xor al,al                 ; region = ordering of (a, b, c): three comparisons -> 3 bits
    cmp bl,cl
    rcl al,1
    cmp cl,ch
    rcl al,1
    cmp bl,ch
    rcl al,1
    shl al,5                  ; region picks a band of the palette...
    mov ah,bl
    shr ah,3
    add al,ah                 ; ...and a shades it
    stosb
    cmp di,64000
    jb .px
    inc byte [t]
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
t: db 0
