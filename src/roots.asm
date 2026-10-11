; ROOTS - polynomial root migration. For each pixel, v = X^3/64 + X*(16S - 6T - 6Y) + Y*Y*T/16 (X, Y centred;
; T and S are two triangle waves, S four times slower).
; The picture is v's SIGN: where it changes against the pixel to the left or above, the pixel is a root and
; is drawn at full brightness (orange on the positive side, blue on the negative); elsewhere |v| draws faint
; contour bands, warm where v > 0 and cool where v < 0. As T sweeps,
; the roots migrate, pinch together and split.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:                         ; index = sign*128 + shade; shade 63 (index 127/255) is a root: the brightest of its ramp
    mov al,bl
    and al,63                 ; s = 0..63
    mov cl,al
    shr cl,1                  ; G = s/2
    mov ah,al
    shr ah,2                  ; s/4
    test bl,bl
    jns .warm
    xchg al,ah                ; negative side: cool (R and B swap)
.warm:
    out dx,al                 ; R
    mov al,cl
    out dx,al                 ; G
    mov al,ah
    out dx,al                 ; B
    inc bl
    jnz .pal
frame:
    mov al,[t]                ; T = a triangle wave -32..+31
    call tri
    mov [tt],eax
    imul ebp,eax,-6           ; K = 16 S - 6 T: both linear coefficients folded into one per frame
    mov al,[t]                ; S = a four-times-slower triangle
    shr al,2
    call tri
    shl eax,4
    add ebp,eax
    xor di,di
.px:
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; ax = y, dx = x
    sub dx,160
    sub ax,100
    movsx ecx,dx              ; X
    movsx esi,ax              ; Y
    mov eax,ecx
    imul eax,ecx
    imul eax,ecx
    sar eax,6                 ; X^3/64
    imul ebx,esi,-6
    add ebx,ebp
    imul ebx,ecx
    add eax,ebx               ; + X (16 S - 6 T - 6 Y)
    mov ebx,esi
    imul ebx,esi
    imul ebx,[tt]
    sar ebx,4
    add eax,ebx               ; + Y*Y*T/16
    cdq                       ; edx = sign mask
    xor eax,edx
    sub eax,edx               ; |v|
    shr eax,9                 ; the field uses the dim half of each ramp (0..31)
    and al,31
    and dl,128                ; sign bit as bit 7 of the colour
    or al,dl
    cmp cx,-160               ; column 0 has no left neighbour
    je .above
    mov ah,al                 ; root if the sign differs from the left or the upper neighbour
    xor ah,[es:di-1]
    js .root
.above:
    cmp di,320                ; row 0 has no row above
    jb .put
    mov ah,al
    xor ah,[es:di-320]
    jns .put
.root:
    or al,127
.put:
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
tri:                          ; al -> eax = triangle(al) - 32, i.e. -32..+31 and back
    test al,64
    jz .up
    not al
.up:
    and al,63
    sub al,32
    movsx eax,al
    ret
t: db 0
tt: dd 0
