; SELFTEX - a river made of the program's own machine code. Below the horizon every row is a floor seen in
; perspective (depth z = 8192 / (y - horizon)); a river winds across it, its centre a triangle wave of the
; distance along it, so it bends left and right into the distance. The water is code bytes stretched into long
; streaks that flow towards you, sixteen times faster than the slow drift over the fields; the fields on both
; banks are code bytes too, blocks that recede to the horizon; the sky is a ramp. Every texel on the screen is a
; byte of this program, and so is the music: every other timer tick the next code byte is a kalimba note.
; Time is the BIOS clock, so the river flows at the same speed on any machine.
BITS 16
CPU 386
ORG 100h
H   equ 60                    ; horizon row
fv  equ 0FF00h                ; per-row scratch, high in the program's own segment
gv  equ 0FF01h
mv  equ 0FF02h
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:                         ; 0..127: sky and water, (s/4, s/2, s); 128..255: fields, (s/4, s/2, s/8); s = i & 63
    mov al,bl
    and al,63
    mov ah,al
    shr al,2
    out dx,al
    mov al,ah
    shr al,1
    out dx,al
    mov al,ah
    test bl,bl
    jns .blue
    shr al,3
.blue:
    out dx,al
    inc bl
    jnz .pal
    mov ax,351Ch              ; hook the timer tick (INT 1Ch), keeping the old vector on the stack
    int 21h
    push es
    push bx
    mov ah,25h
    mov dx,isr
    int 21h
    push ax                   ; AX = 251Ch, for the unhook
    push word 0A000h
    pop es
    mov bx,100h               ; XLAT table = the program itself
frame:
    mov bp,[fs:46Ch]          ; t = the BIOS tick count
    xor di,di
.row:
    mov ax,di
    xor dx,dx
    mov cx,320
    div cx                    ; ax = y
    sub ax,H
    jg .ground
    add al,H                  ; the sky: colour y, a ramp from black to pale blue at the horizon
    rep stosb
    jmp short .next
.ground:
    xchg ax,si                ; d = y - horizon
    mov ax,8192
    cwd
    div si
    movzx esi,ax              ; ESI = z, the depth of this row: the world step per pixel, times 256
    shr ax,2
    add ax,bp                 ; F = z/4 + t: distance along the river (the camera drifts forward)
    mov dl,al
    shr ax,4
    mov [fv],al               ; the fields' coordinate along the river
    add ax,bp
    mov [gv],al               ; the water's: t more, so it flows towards you
    mov al,dl                 ; the river's centre: a triangle wave of F, -32..+31
    cbw
    xor al,ah
    shr al,1
    sub al,32
    cbw
    mov [mv],ax
    imul edx,esi,-160         ; EDX = 256 * u at x = 0 (u: the world coordinate across the view)
.px:
    mov eax,edx
    sar eax,8                 ; u
    sub ax,[mv]
    jns .abs
    neg ax                    ; |u - centre|
.abs:
    cmp ax,24
    jae .bank
    shr al,1                  ; water: code bytes in streaks along the flow
    add al,[gv]
    xlat
    and al,63
    or al,64
    jmp short .put
.shore:
    mov al,136                ; a dark shore just outside the water
    jmp short .put
.bank:
    cmp ax,30
    jb .shore
    shr ax,4                  ; fields: code-byte blocks, mirrored about the river
    xor al,[fv]
    xlat
    or al,128
.put:
    stosb
    add edx,esi               ; next pixel: u += z/256
    loop .px
.next:
    cmp di,64000
    jb .row
    in al,60h
    cbw
    dec ax
    jnz frame                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h                   ; text mode
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
isr:                          ; INT 1Ch, 18.2 Hz; BX = 100h in the main loop
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h to the MPU data port, then 3Fh (UART mode) to its command port
    out dx,ax
    mov al,108                ; program 108: kalimba
    out dx,al
    mov al,90h                ; note on
    out dx,al
    mov ax,[fs:46Ch]
    shr ax,1
    jc .q
    cs xlat                   ; the code byte at the step number
    and al,30
    add al,46
    aam 5                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    aad 6
    out dx,al                 ; note
    out dx,al                 ; velocity = note
.q:
    popa
    iret
