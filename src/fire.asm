; FIRE - framebuffer feedback: every pixel becomes the average of the four pixels below it, minus a
; little. Two random rows of heat at the bottom keep the energy up (the thing NEBULA lacked).
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
    push word 0A000h
    pop es
    mov dx,3C9h
.pal:                         ; fire palette: R = min(63, i/2), G = i/4, B = i/8
    mov al,bl
    shr al,1
    cmp al,63
    jbe .r
    mov al,63
.r:
    out dx,al
    mov al,bl
    shr al,2
    out dx,al
    shr al,1
    out dx,al
    inc bl
    jnz .pal
frame:
    mov di,63680              ; the last two rows get fresh random heat
    mov cx,640
.seed:
    imul bx,bx,25173          ; 16-bit LCG: the high byte is the noise
    add bx,13849
    cmp bh,110                ; about 40% of the pixels are white-hot, the rest cold
    sbb al,al
    stosb
    loop .seed
    xor di,di
.p:
    movzx ax,byte [es:di+319]
    movzx cx,byte [es:di+320]
    add ax,cx
    movzx cx,byte [es:di+321]
    add ax,cx
    movzx cx,byte [es:di+640]
    add ax,cx
    shr ax,2
    sub al,1                  ; cool by one, but never below zero
    adc al,0
    stosb
    cmp di,63680
    jb .p
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
