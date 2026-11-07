BITS 16
ORG 100h
    push ds                   ; copy the text screen first
    push word 0B800h
    pop ds
    xor si,si
    push cs
    pop es
    mov di,scr
    mov cx,2000
    rep movsw
    pop ds
    mov ax,1130h              ; ES:BP -> ROM 8x16 font
    mov bh,6
    int 10h
    mov [foff],bp
    mov [fseg],es
    mov ah,3Ch                ; FONT.BIN
    xor cx,cx
    mov dx,fname1
    int 21h
    xchg bx,ax
    mov ah,40h
    mov cx,4096
    push ds
    lds dx,[foff]
    int 21h
    pop ds
    mov ah,3Eh
    int 21h
    mov ah,3Ch                ; SCREEN.BIN
    xor cx,cx
    mov dx,fname2
    int 21h
    xchg bx,ax
    mov ah,40h
    mov cx,4000
    mov dx,scr
    int 21h
    mov ah,3Eh
    int 21h
    ret
fname1 db 'FONT.BIN',0
fname2 db 'SCREEN.BIN',0
foff dw 0
fseg dw 0
scr:
