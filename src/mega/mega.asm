; MEGA - the uber256-lab megademo: eleven of the intros in one program, each introduced by a title card and closed by
; a fade, with its own live music, ending on WARP bending the credits.
;
; Each part is its own source assembled with -DMEGA (build.sh): the same program as the 256-byte release, except that
; the code every intro repeats is shared. Its frame check, its MIDI header and the groove are far calls through three
; vectors the megademo puts in the part's PSP (50h, 54h, 58h), so one copy of each serves all eleven parts. The
; megademo runs a part the way DOS runs a .COM: it clears a 64 KB segment above itself, puts the part at offset 100h,
; a far jump back to itself at offset 0 (where the part's final RET lands), the vectors and the end tick in the PSP,
; gives it its own stack and the registers DOS gives a program, and jumps in. Each part fades in over its first 32
; frames (the frame check does it). Between parts it reads the DAC and fades the picture to black, then shows the
; next title: the BIOS 8x8 font scaled up in a gold gradient with a band of light running down it, a chime, a fade in
; and out. Esc at any moment ends the show.
BITS 16
CPU 386
ORG 100h
%include "sizes.inc"          ; the byte counts of the 256-byte builds, written by build.sh

    cld
    xor ax,ax
    mov fs,ax                 ; FS = 0: the BIOS tick count is [fs:46Ch], as every part assumes
    mov ax,cs
    add ax,1000h
    mov [pseg],ax             ; the parts run in the 64 KB segment above the megademo
    mov ax,1130h              ; the BIOS 8x8 font (characters 0..127) -> [font]
    mov bh,3
    push es
    int 10h
    mov [font],bp
    mov [font+2],es
    pop es
    mov dx,331h               ; the MPU-401 into UART mode before the first note (the parts' own header sends its
    mov al,3Fh                ; 3Fh after the program change, so the very first one would be lost)
    out dx,al
    mov ax,13h
    int 10h
    mov cx,90                 ; a moment of black before the show
.dark:
    call vsync
    jc quit
    loop .dark
    mov si,intro
    mov cl,200                ; held longer
    call card
    jc quit
    mov bx,parts
.next:                        ; BX -> a part: dw code, dw length, db seconds, then the card's three lines
    push bx
    lea si,[bx+5]
    mov cl,80
    call card                 ; leaves SI at the next part
    pop bx
    jc quit
    push si
    cmp word [bx],warp_bin
    jne .run
    push bx
    call credits              ; WARP bends whatever is on the text screen: give it the credits
    pop bx
.run:
    call run_part
    mov es,[pseg]
    cmp byte [es:5Eh],0
    jne quit                  ; Esc during the part
    call fade_out
    pop bx
    jc quit
    cmp bx,parts_end
    jb .next
    mov si,outro
    mov cl,240
    call card                 ; the end
quit:
    mov ax,3
    int 10h
    mov dx,bye
    mov ah,9
    int 21h
    int 20h

; ---- one part: a fresh segment, DOS's entry conditions, a far jump home at PSP:0, the shared routines' vectors at
;      PSP:50h, 54h, 58h, the end tick at PSP:5Ch (and PSP:5Eh, set to 1 on Esc)
run_part:
    mov es,[pseg]
    xor di,di
    xor ax,ax
    mov cx,8000h
    rep stosw                 ; a clean 64 KB
    mov al,0EAh               ; jmp far back
    stosb
    mov si,psp_far
    movsw
    mov [es:3],cs
    mov di,50h
    mov cl,3
.vec:
    movsw                     ; the three vectors: offset, then this segment
    mov ax,cs
    stosw
    loop .vec
    movzx ax,byte [bx+4]      ; seconds -> the end tick: 18.2 ticks a second
    imul ax,ax,182
    cwd
    mov cx,10
    div cx
    add ax,[fs:46Ch]
    stosw
    mov si,[bx]
    mov cx,[bx+2]
    mov di,100h
    rep movsb
    push es                   ; the part fades in over its first 32 frames (svc_check does it): nothing written yet
    push ds
    pop es
    mov di,fadein
    mov cx,1 + 768 * 2
    xor al,al
    rep stosb                 ; fadein, orig, last = 0
    pop es
    mov dx,3C6h               ; and until its first frame is done, every pixel shows colour 0: the PEL mask
    out dx,al
    mov [save_sp],sp
    mov ax,es
    cli
    mov ss,ax
    mov sp,0FFFEh
    sti
    push word 0               ; the part's RET goes to PSP:0
    push ax
    push word 100h
    mov ds,ax
    xor ax,ax                 ; the registers DOS starts a .COM with
    xor bx,bx
    mov cx,00FFh
    mov dx,ds
    mov si,100h
    mov di,0FFFEh
    mov bp,091Ch
    retf
back:
    cli
    mov ax,cs
    mov ss,ax
    mov sp,[cs:save_sp]
    sti
    mov ds,ax
    cld
    ret
psp_far:
    dw back, svc_check, svc_midi, svc_groove

; ---- the routines the parts share (far calls through their PSP; only AX and the flags change, as in the originals)
svc_check:                    ; once per frame: CF = 1 when the part's time is up or Esc is down
    cmp byte [cs:fadein],32
    jae .go
    call fade_in
.go:
    push ds
    mov ds,[cs:pseg]
    in al,60h
    cmp al,1
    jne .t
    mov [5Eh],al              ; Esc: tell the megademo
    stc
    jmp short .x
.t: mov ax,[fs:46Ch]
    sub ax,[5Ch]
    cmp ax,8000h              ; CF = 1 once the tick count has reached the end (the difference is not negative)
.x: pop ds
    retf
; one step of a part's fade-in, at the end of its frame: read the DAC; if the part has written a new palette since
; the last step (anything but what this wrote), that is the palette to fade to; write it at brightness k/32, k = 1..32.
; The first step also opens the PEL mask again. Works whether a part sets its palette once or every frame.
fade_in:
    pusha
    push ds
    push es
    push cs
    pop ds
    push cs
    pop es
    mov dx,3C7h
    xor al,al
    out dx,al
    mov dl,0C9h
    mov di,dac
    mov cx,768
    rep insb                  ; what is in the DAC now
    mov si,dac
    mov di,last
    mov cx,768
    repe cmpsb
    je .same
    mov si,dac                ; the part wrote a palette: fade to that
    mov di,orig
    mov cx,768
    rep movsb
.same:
    inc byte [fadein]
    mov bl,[fadein]
    mov dl,0C8h
    xor al,al
    out dx,al
    inc dx
    mov si,orig
    mov di,last
    mov cx,768
.w: lodsb
    mul bl
    shr ax,5
    out dx,al
    stosb
    loop .w
    mov dl,0C6h               ; the PEL mask open again (from the first step on)
    mov al,0FFh
    out dx,al
    pop es
    pop ds
    popa
    ret
svc_midi:                     ; the MIDI header: UART mode, program AL on channel 1, note on (DX = 330h, AX = 3F90h)
    mov dx,330h
    push ax
    mov ax,3FC0h
    out dx,ax
    pop ax
    out dx,al
    mov ax,3F90h
    out dx,al
    retf
svc_groove:                   ; the rhythm section, one copy for FIRE, GOLDTEX, LATCH, ORDER and WARP
%include "groove.inc"
    retf

; ---- the frame clock: wait for the end of one retrace and the start of the next; CF = 1 if Esc is down
vsync:
    push ax
    push dx
    mov dx,3DAh
.a: in al,dx
    test al,8
    jnz .a
.b: in al,dx
    test al,8
    jz .b
    in al,60h
    cmp al,1                  ; Esc down: CF = 1
    stc
    je .c
    clc
.c: pop dx
    pop ax
    ret

; ---- fade the current picture to black over 32 frames (any mode: it is the DAC that fades)
fade_out:
    push ds
    pop es
    mov dx,3C7h
    xor al,al
    out dx,al
    mov dl,0C9h
    mov di,dac
    mov cx,768
    rep insb
    mov bl,31
.f: call vsync
    jc .x
    mov dl,0C8h
    xor al,al
    out dx,al
    inc dx
    mov si,dac
    mov cx,768
.v: lodsb
    mul bl
    shr ax,5
    out dx,al
    loop .v
    dec bl
    jns .f
    clc
.x: ret

; ---- a title card: SI -> the big title, a size line and a tagline (zero-terminated), CL = frames to hold. A chime,
;      then it fades in over 32 frames, holds, and fades out; a band of white light runs down the letters all along.
;      Returns SI after the third line, CF = 1 on Esc.
card:
    push cx
    mov ax,13h
    int 10h
    xor bl,bl
    call card_pal             ; everything black while drawing
    push word 0A000h
    pop es
    mov ax,44 * 256 + 5       ; the name, 40 pixels high, in the gold gradient
    call text
    mov ax,108 * 256 + 2      ; the size, solid (colour 200)
    mov byte [solid],200
    call text
    mov ax,140 * 256 + 1      ; the tagline (201)
    inc byte [solid]
    call text
    mov byte [solid],0
    mov al,14                 ; the chime: tubular bells, a fifth (C6 and G6)
    push cs
    call svc_midi
    mov al,84
    out dx,al
    mov al,70
    out dx,al
    mov al,91
    out dx,al
    mov al,60
    out dx,al
    pop cx
    xor bl,bl
.in:
    call .frame
    jc .x
    inc bx
    cmp bl,33
    jb .in
    movzx cx,cl
    dec bx
.h: call .frame
    jc .x
    loop .h
.out:
    call .frame
    jc .x
    dec bl
    jns .out
    clc
.x: ret
.frame:                       ; one frame of the card: CF = 1 on Esc
    call vsync
    jc .r
    call card_pal
    clc
.r: ret

; card palette at brightness BL/32: colours 64..127 a gradient from ivory (top of the letters) to deep gold (bottom)
; with a band of white light at row [phase] that moves one step a call; 200 and 201 two warm greys
card_pal:
    pusha
    inc byte [phase]
    mov dx,3C8h
    mov al,64
    out dx,al
    inc dx
    xor cx,cx
.p: mov al,cl                 ; the band: 5 (6 - d), d = (k - phase) mod 64, where d < 6
    sub al,[phase]
    and al,63
    sub al,6
    neg al
    jg .band
    xor al,al
.band:
    mov ah,5
    mul ah
    mov bh,al                 ; BH = the boost
    mov al,cl                 ; R = 63 - k/4
    shr al,2
    neg al
    add al,63
    call .out
    mov al,cl                 ; G = 60 - k/2
    shr al,1
    neg al
    add al,60
    call .out
    mov al,cl                 ; B = 50 - 3k/4
    mov ah,al
    shr ah,2
    sub al,ah
    neg al
    add al,50
    call .out
    inc cx
    cmp cl,64
    jb .p
    dec dx
    mov al,200
    out dx,al
    inc dx
    mov bh,0
    mov si,greys
    mov cl,6
.g: lodsb
    call .out
    loop .g
    popa
    ret
.out:                         ; out (AL + BH, at most 63) * BL / 32
    add al,bh
    cmp al,63
    jbe .o
    mov al,63
.o: mul bl
    shr ax,5
    out dx,al
    ret
greys: db 58, 54, 46, 34, 30, 24

; draw the zero-terminated string at SI, centred, in the BIOS font scaled by AL, top row AH; [solid] = 0 for the gold
; gradient (colour 64 + 8 x line / scale), else that colour. Returns SI after the terminator.
text:
    mov [scale],al
    movzx bp,ah
    imul bp,bp,320            ; BP -> the start of the top row
    mov bx,si                 ; the length
    call skipz
    xchg si,bx                ; SI = the string, BX = past it
    mov ax,bx
    sub ax,si
    dec ax
    movzx cx,byte [scale]
    shl cx,3
    mul cx                    ; the width in pixels
    neg ax
    add ax,320
    shr ax,1
    add bp,ax                 ; BP -> the first glyph's top left corner
.ch:
    lodsb
    test al,al
    jz .done
    pusha
    movzx si,al
    shl si,3
    add si,[font]             ; SI -> the glyph in the BIOS font
    xor dx,dx                 ; DX = the line, 0 .. 8 x scale - 1
.line:
    mov al,[solid]
    test al,al
    jnz .c
    mov ax,dx                 ; the gradient: 64 + 8 x line / scale
    shl ax,3
    div byte [scale]
    add al,64
.c: push ax
    mov ax,dx                 ; glyph row = line / scale
    div byte [scale]
    movzx bx,al
    push ds
    mov ds,[cs:font+2]
    mov ah,[si+bx]            ; its eight pixels
    pop ds
    pop bx
    mov al,bl                 ; AL = colour, AH = pixels
    mov di,bp
    mov bh,8
.col:
    movzx cx,byte [scale]
    shl ah,1
    jnc .skip
    rep stosb
    db 3Dh                    ; (cmp ax,imm16: swallows the add)
.skip:
    add di,cx
    dec bh
    jnz .col
    add bp,320
    inc dx
    movzx ax,byte [scale]
    shl ax,3
    cmp dx,ax
    jb .line
    popa
    movzx ax,byte [scale]
    shl ax,3
    add bp,ax                 ; the next glyph
    jmp .ch
.done:
    ret

; ---- the credits that WARP bends: text mode 3, centred lines in colours 9..15; a 1 stands for the list of parts,
;      which is read from the programme itself
credits:
    mov ax,3
    int 10h
    mov ah,1
    mov cx,2000h
    int 10h                   ; no cursor
    push ds
    pop es
    mov di,linebuf
    mov bx,parts
.pl:
    lea si,[bx+5]
.pc:
    lodsb
    stosb
    test al,al
    jnz .pc
    mov byte [di-1],' '
    call skipz                ; past the size line and the tagline
    call skipz
    mov bx,si
    cmp bx,parts_end
    jb .pl
    mov byte [di-1],0
    push word 0B800h
    pop es
    mov si,credit_lines
    mov di,3 * 160
    mov bl,9                  ; colour
.line:
    lodsb
    cmp al,0FFh
    je .done
    cmp al,1
    jne .own
    push si
    mov si,linebuf
    call putline
    pop si
    jmp short .adv
.own:
    dec si
    call putline
.adv:
    add di,2 * 160
    inc bx
    cmp bl,16
    jb .line
    mov bl,9
    jmp .line
.done:
    ret
putline:                      ; SI -> a line, centred on the row at DI in colour BL; SI is left past it
    push di
    mov dx,si
    call skipz
    mov ax,si
    sub ax,dx                 ; length + 1
    neg ax
    add ax,81
    and ax,-2                 ; (80 - length) / 2 characters, two bytes each
    add di,ax
    mov si,dx
.p: lodsb
    test al,al
    jz .e
    mov ah,bl
    stosw
    jmp .p
.e: pop di
    ret
skipz:                        ; SI past the next zero byte
    lodsb
    test al,al
    jnz skipz
    ret

; ---- the programme: dw code, dw length, db seconds, the title, its size, a tagline
%macro PART 5                 ; label, size, seconds, title, tagline
    dw %1_bin, %1_end - %1_bin
    db %3, %4, 0, %2, " BYTES", 0, %5, 0
%endmacro
%define ENTRY PART

intro:
    db "UBER256", 0, "LAB  MEGADEMO", 0, SZ_COUNT, " INTROS, 256 BYTES EACH, MUSIC LIVE", 0
outro:
    db "THE END", 0, SZ_COUNT, " INTROS", 0, "ALL OF THEM TOGETHER: ", SZ_TOTAL, " BYTES", 0
parts:
    ENTRY flowtex, SZ_FLOWTEX, 16, "FLOWTEX", "ITS OWN MACHINE CODE, AS SATIN - HARP"
    ENTRY selftex, SZ_SELFTEX, 16, "SELFTEX", "A RIVER OF MACHINE CODE - KALIMBA"
    ENTRY goldtex, SZ_GOLDTEX, 16, "GOLDTEX", "POLISHED GOLD ON CODE - GLOCKENSPIEL"
    ENTRY order,   SZ_ORDER,   16, "ORDER",   "SHAPES FROM ORDERINGS - PIZZICATO"
    ENTRY galaxy,  SZ_GALAXY,  20, "GALAXY",  "A DE JONG ATTRACTOR - VIBRAPHONE"
    ENTRY cliff,   SZ_CLIFF,   16, "CLIFF",   "A CLIFFORD ATTRACTOR - MARIMBA"
    ENTRY fire,    SZ_FIRE,    16, "FIRE",    "FEEDBACK AND HEAT - GUITAR"
    ENTRY roots,   SZ_ROOTS,   16, "ROOTS",   "A CUBIC'S MIGRATING ROOTS - STEEL DRUMS"
    ENTRY julia,   SZ_JULIA,   20, "JULIA",   "A JULIA SET, IN SLOW MOTION - CELESTA"
    ENTRY latch,   SZ_LATCH,   16, "LATCH",   "COMPUTED BY THE VGA ITSELF - MUSIC BOX"
    ENTRY warp,    SZ_WARP,    24, "WARP",    "THE CREDITS, BENT - ELECTRIC PIANO"
parts_end:

credit_lines:
    db "U B E R 2 5 6 - L A B   M E G A D E M O", 0
    db SZ_COUNT, " intros of 256 bytes or less, each playing its own music", 0
    db 1                      ; the parts, read from the programme above
    db "code and music: djayuffe & Claude", 0
    db "NASM - 16-bit real mode - VGA - x87 - MPU-401 General MIDI", 0
    db "github.com/djayuffe/uber256-lab", 0
    db "thanks for watching", 0
    db 0FFh
bye:
    db "uber256-lab megademo. Thanks for watching.", 13, 10, "$"

%macro BIN 2
%1_bin:
    incbin %2
%1_end:
%endmacro
    BIN flowtex, "build/FLOWTEX.MEG"
    BIN selftex, "build/SELFTEX.MEG"
    BIN goldtex, "build/GOLDTEX.MEG"
    BIN order,   "build/ORDER.MEG"
    BIN galaxy,  "build/GALAXY.MEG"
    BIN cliff,   "build/CLIFF.MEG"
    BIN fire,    "build/FIRE.MEG"
    BIN roots,   "build/ROOTS.MEG"
    BIN julia,   "build/JULIA.MEG"
    BIN latch,   "build/LATCH.MEG"
    BIN warp,    "build/WARP.MEG"

section .bss
pseg:    resw 1
fadein:  resb 1
orig:    resb 768
last:    resb 768
font:    resw 2
save_sp: resw 1
scale:   resb 1
solid:   resb 1
phase:   resb 1
linebuf: resb 100
dac:     resb 768
