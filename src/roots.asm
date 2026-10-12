; ROOTS - polynomial root migration. For each pixel (X, Y centred) the program evaluates a cubic,
;   v = X^3/4 + X(16K - 96Y) + Y^2 T      (16 times X^3/64 + X(K - 6Y) + Y^2 T/16),   K = 16S - 6T,
; with T and S two triangle waves of the BIOS clock, S four times slower. The picture is v's SIGN: where it
; changes against the pixel to the left or above, the pixel is a root and is drawn at full brightness (orange on
; the positive side, blue on the negative); elsewhere |v| draws faint contour bands, warm where v > 0 and cool
; where v < 0. As T sweeps, the roots migrate, pinch together and split. T is patched into the code each frame. Rows
; and columns are nested loops, with what depends only on Y worked out once per row; the row above the screen is drawn
; too, into the 320 bytes past its end, so that the top row has an upper neighbour.
; The music is T: steel drums play it as a pentatonic line that climbs and falls with the sweep.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
    mov al,13h
    int 10h
    mov dx,3C9h
.pal:                         ; index = sign*128 + shade; shade 63 (index 127/255) is a root: the brightest of its ramp
    mov al,bl
    and al,63                 ; s = 0..63
    mov cl,al
    shr cl,1                  ; G = s/2
    mov ah,cl
    shr ah,1                  ; s/4
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
    HOOK_TICK isr                 ; the timer tick drives the music
    push word 0A000h
    pop es
frame:
    mov al,[fs:46Ch]          ; t = the BIOS tick count: the animation runs on the clock, not the frame rate
    push ax
    call tri                  ; T
    mov [.T-1],al             ; patched into  imul ebp,esi,T  below
    sub eax,102
    imul ebx,eax,-96          ; -96T + 9792
    pop ax
    shr al,2
    call tri                  ; S
    shl eax,8                 ; 256 S
    add ebx,eax               ; EBX = 16K + 9792, K = 16S - 6T
    mov di,-320               ; from row -1, drawn into the 320 bytes past the screen, so that row 0 has a row
    push dword -101           ; above it to compare with
    pop esi                   ; Y
.row:                         ; per row: EBX = 16K - 96Y, EBP = Y^2 T
    sub ebx,96
    imul ebp,esi,0
.T:
    imul ebp,esi
    push dword -160
    pop ecx                   ; X
.px:
    mov eax,ecx
    imul eax,ecx
    sar eax,2
    add eax,ebx
    imul eax,ecx              ; X (X^2/4 + 16K - 96Y)
    add eax,ebp               ; + Y^2 T
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
    mov ah,al
    xor ah,[es:di-320]
    jns .put
.root:
    or al,127
.put:
    stosb
    inc ecx
    cmp cx,160
    jl .px
    inc esi
    cmp si,100
    jl .row
    ESC_OR_LOOP frame
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
    MIDI_START 114            ; program 114: steel drums
    mov al,[cs:frame.T-1]     ; T, as patched by the main loop
    and al,30
    add al,44
    PENTA                     ; AL = 2d -> floor(12d/5): degree d of C major pentatonic
    out dx,al                 ; note
    out dx,al                 ; velocity = note
    popa
    iret
