; WARP - the DOS screen, untouched in memory, squashed, stretched and sheared by two CRT-controller registers:
; CR09 (character height) follows a fast triangle wave and CR13 (words per text row) a slow one.
BITS 16
CPU 386
ORG 100h
    mov dx,3D4h
frame:
    inc bx                    ; time
    mov al,bl                 ; triangle wave from the counter
    test al,32
    jz .up
    not al
.up:
    and al,31
    shr al,1                  ; 0..15
    add al,3                  ; character height 4..19 scan lines (16 is normal)
    or al,40h                 ; keep CR09 bit 6 (line compare bit 9)
    mov ah,al
    mov al,09h                ; CR09: maximum scan line = character height - 1
    out dx,ax
    mov al,bl                 ; a slower triangle, -4..+3, for the line stride
    shr al,3
    test al,8
    jz .up2
    not al
.up2:
    and al,7
    add al,40-4               ; CR13: 36..43 words per row (40 = the normal 80 columns)
    mov ah,al
    mov al,13h
    out dx,ax
    push dx
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
.vs2:
    in al,dx
    test al,8
    jnz .vs2
    pop dx
    in al,60h
    dec al
    jnz frame
    mov ax,3
    int 10h
    ret
