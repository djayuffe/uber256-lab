; ROOTS - polynomial root migration. For each pixel (X, Y centred) the program evaluates a cubic,
;   v = X^3/4 + X(16K - 96Y) + Y^2 T      (16 times X^3/64 + X(K - 6Y) + Y^2 T/16),   K = 16S - 6T,
; with T and S two triangle waves of the BIOS clock, S four times slower. The picture is v's SIGN: where it
; changes against the pixel to the left or above, the pixel is a root and is drawn at full brightness (orange on
; the positive side, blue on the negative); elsewhere |v| draws faint contour bands, warm where v > 0 and cool
; where v < 0. As T sweeps, the roots migrate, pinch together and split. T is patched into the code each frame.
; The music is T: steel drums play it as a pentatonic line that climbs and falls with the sweep.
BITS 16
CPU 386
ORG 100h
    mov al,13h
    int 10h
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
    xchg ax,cx
    out dx,al                 ; G
    mov al,ch
    out dx,al                 ; B
    inc bl
    jnz .pal
    mov ax,351Ch              ; hook the timer tick (INT 1Ch), keeping the old vector on the stack
    int 21h
    push es
    push bx
    mov ah,25h
    mov dx,isr
    int 21h
    push ax
    push word 0A000h
    pop es
frame:
    mov al,[fs:46Ch]          ; t = the BIOS tick count: the animation runs on the clock, not the frame rate
    push ax
    call tri                  ; T
    mov [.T-1],al             ; patched into  imul ebx,esi,T  below
    imul ebp,eax,-96
    pop ax
    shr al,2
    call tri                  ; S
    shl eax,8                 ; 256 S
    add ebp,eax               ; EBP = 16K = 256S - 96T
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
    sar eax,2
    add eax,ebp
    imul ebx,esi,-96
    add eax,ebx
    imul eax,ecx              ; X (X^2/4 + 16K - 96Y)
    imul ebx,esi,0
.T:
    imul ebx,esi
    add eax,ebx               ; + Y^2 T
    cdq                       ; edx = sign mask
    xor eax,edx               ; |v| (to within one)
    shr eax,12
    and al,62                 ; the field uses the dim half of each ramp: (|v| >> 13) & 31
    add dl,dl
    rcr al,1                  ; sign bit as bit 7 of the colour
    cmp cl,60h                ; column 0 (X = -160) has no left neighbour (X = 96 also matches: harmless)
    je .above
    mov ah,al                 ; root if the sign differs from the left or the upper neighbour
    xor ah,[es:di-1]
    js .root
.above:
    cmp si,-100               ; row 0 has no row above
    je .put
    mov ah,al
    xor ah,[es:di-320]
    jns .put
.root:
    or al,127
.put:
    stosb
    test di,di                ; to the 64 KB wrap: the last 1536 pixels are off screen
    jnz .px
    in al,60h
    cbw
    dec ax
    jnz frame                 ; Esc (scan code 1): AX = 0
    mov al,3
    int 10h
    pop ax                    ; unhook INT 1Ch: AX = 251Ch, DS:DX = the old vector
    pop dx
    pop ds
    int 21h
    ret
tri:                          ; al -> eax = a triangle wave of period 128, -32..+31
    add al,al
    cbw
    xor al,ah
    sub al,64
    sar al,1
    cbw
    cwde
    ret
isr:                          ; INT 1Ch, 18.2 Hz
    pusha
    mov dx,330h
    mov ax,3FC0h              ; C0h (program change) to the MPU-401 data port, then 3Fh (UART mode) to its command port
    out dx,ax
    mov al,114                ; program 114: steel drums
    out dx,al
    mov al,90h                ; note on
    out dx,al
    mov al,[cs:frame.T-1]     ; T, as patched by the main loop
    and al,30
    add al,44
    aam 5                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    aad 6
    out dx,al                 ; note
    out dx,al                 ; velocity = note
    popa
    iret
