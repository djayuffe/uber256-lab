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
    add bx,bp
    mov cx,dx                 ; b = x - 2t
    sub cx,bp
    sub cx,bp
    imul ax,ax,3              ; c = 3y + t
    add ax,bp
    xor ah,ah                 ; which of the six orderings of (a, b, c)? three comparisons -> 3 bits in AH
    cmp bl,cl
    rcl ah,1
    cmp cl,al
    rcl ah,1
    cmp bl,al
    rcl ah,1
    shl ah,5                  ; the ordering picks a band of the palette...
    mov al,bl
    shr al,3
    add al,ah                 ; ...and a shades it
    stosb
    cmp di,64000
    jb .px
    inc bp
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
