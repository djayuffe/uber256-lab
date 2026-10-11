; CHLADNI - the nodal lines of a vibrating plate: f(x,y) = sin(a*x)*sin(b*y) - sin(b*x)*sin(a*y) = 0.
; Sand collects where the plate does not move, so the picture is bright where |f| is small. The mode numbers
; a and b drift, and the same value tunes the PC speaker, so the figure and the tone change together.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:                         ; glow palette
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
    mov al,3
    out 61h,al
    mov bx,data
frame:
    xor di,di
.px:
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; ax = y, dx = x
    sub dx,160
    sub ax,100
    mov [bx+16],dx
    mov [bx+18],ax
    fild word [bx+16]
    fmul dword [bx+8]         ; X
    fild word [bx+18]
    fmul dword [bx+8]         ; Y
    fld st1
    fmul dword [bx]
    fsin                      ; sin(aX)
    fld st1
    fmul dword [bx+4]
    fsin                      ; sin(bY)
    fmulp st1,st0
    fld st2
    fmul dword [bx+4]
    fsin                      ; sin(bX)
    fld st2
    fmul dword [bx]
    fsin                      ; sin(aY)
    fmulp st1,st0
    fsubp st1,st0             ; f
    fabs
    fmul dword [bx+12]
    fistp word [bx+16]
    fstp st0
    fstp st0
    mov ax,[bx+16]
    test ah,ah                ; |f| * 600 above 255: clamp
    jz .ok
    mov al,255
.ok:
    not al                    ; bright where the plate is still
    stosb
    test di,di                ; to the 64 KB wrap: the last 1536 pixels are off screen
    jnz .px
    fld dword [bx+28]         ; drift the mode number a through [1.5, 4.5) so it never meets b
    fld dword [bx]
    fsub dword [bx+24]
    fadd dword [bx+20]
    fprem
    fadd dword [bx+24]
    fst dword [bx]
    fistp word [bx+16]
    fstp st0
    mov al,[bx+16]            ; the speaker follows the first mode number
    shl al,4
    out 42h,al
    mov al,3
    out 42h,al
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
data:
    dd 1.5, 6.0, 0.02, 600.0, 0.0, 0.01, 1.5, 3.0
