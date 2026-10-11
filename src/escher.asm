; ESCHER - the picture is drawn once. After that only the CRTC moves: the display start address drifts,
; and the line-compare register restarts the scan-out from address 0 part-way down the screen, so the top
; slides while the bottom is a second copy of the same texture. Nothing is redrawn.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:                         ; R = i, G = 2i, B = 4i
    mov al,bl
    out dx,al
    add al,al
    out dx,al
    add al,al
    out dx,al
    inc bl
    jnz .pal
    xor di,di
.tex:                         ; texture: (x-160)*(y-100) / 64 - hyperbolic bands, drawn once
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; ax = y, dx = x
    sub dx,160
    sub ax,100
    imul ax,dx
    sar ax,6
    stosb
    cmp di,64000
    jb .tex
    mov bx,3000               ; a Minsky oscillator (bx, bp) drives the display start address
    xor bp,bp
    xor si,si                 ; line compare
frame:
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    mov ax,bp
    sar ax,6
    imul ax,ax,80             ; vertical: whole rows
    mov cx,bx
    sar cx,5
    add ax,cx                 ; horizontal: units of 4 pixels
    and ax,3FFFh
    mov dx,3D4h
    mov cl,al                 ; start address: AH already holds the high byte
    mov al,0Ch
    out dx,ax
    mov ah,cl
    inc ax                    ; 0Dh: the low byte
    out dx,ax
    mov ax,si                 ; line compare (CR18): a split that sweeps down the screen
    mov ah,al
    mov al,18h
    out dx,ax
    mov ax,bp                 ; the oscillator: bx += bp>>5, bp -= bx>>5
    sar ax,5
    add bx,ax
    mov ax,bx
    sar ax,5
    sub bp,ax
    inc si
    in al,60h
    dec al
    jnz frame
    mov ax,3
    int 10h
    ret
