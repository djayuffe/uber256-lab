; ROOTS - polynomial root migration. For each pixel, v = X^3/64 - 6*X*(Y+T) + Y*Y*T/16 (X, Y centred, T moving).
; The picture is v's SIGN: where it changes against the pixel to the left or above, the pixel is a root and
; turns white; elsewhere |v| draws faint contour bands, warm where v > 0 and cool where v < 0. As T sweeps,
; the roots migrate, pinch together and split.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:                         ; index = sign*128 + shade: 0..63 warm shades, 128..191 cool, 127 and 255 white
    mov al,bl
    and al,127
    cmp al,127
    jne .shade
    mov al,63
    out dx,al
    out dx,al
    out dx,al
    jmp short .next
.shade:
    and al,63
    shr al,1                  ; 0..31
    mov ah,al
    shr ah,1
    test bl,bl
    js .cool
    out dx,al                 ; warm: R = s, G = s/2, B = s/4
    mov al,ah
    out dx,al
    shr al,1
    out dx,al
    jmp short .next
.cool:
    shr al,2                  ; cool: R = s/4, G = s/2, B = s
    out dx,al
    mov al,ah
    out dx,al
    shl al,1
    out dx,al
.next:
    inc bl
    jnz .pal
frame:
    mov al,[t]                ; T = triangle wave -32..+31
    test al,64
    jz .up
    not al
.up:
    and al,63
    sub al,32
    cbw
    movsx ebp,ax
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
    lea ebx,[esi+ebp]
    imul ebx,ecx
    imul ebx,ebx,6
    sub eax,ebx               ; - 6X(Y+T)
    mov ebx,esi
    imul ebx,esi
    imul ebx,ebp
    sar ebx,4
    add eax,ebx               ; + Y*Y*T/16
    cdq                       ; edx = sign mask
    xor eax,edx
    sub eax,edx               ; |v|
    shr eax,8
    and al,63
    and dl,128                ; sign bit as bit 7 of the colour
    or al,dl
    mov ah,al                 ; root if the sign differs from the left or the upper neighbour
    xor ah,[es:di-1]
    js .root
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
t: db 0
