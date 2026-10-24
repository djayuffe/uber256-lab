; Shared MEGA/ATLAS show host: each intro is introduced by a title card and closed by
; a fade, with its own live music, ending on WARP bending the credits.
;
; Each part is its own source assembled with -DMEGA (build.sh): the same program as the 256-byte release, except that
; the code every intro repeats is shared. Its frame check, its MIDI header and the groove are far calls through three
; vectors the megademo puts in the part's PSP (50h, 54h, 58h), so one copy of each serves all parts. The
; megademo runs a part the way DOS runs a .COM: it clears a 64 KB segment above itself, puts the part at offset 100h,
; a far jump back to itself at offset 0 (where the part's final RET lands), the vectors and the end tick in the PSP,
; gives it its own stack and the registers DOS gives a program, and jumps in. Each part fades in over its first 32
; frames (the frame check does it). Between parts the last frame drains to sepia (or fades, out of LATCH's and WARP's
; modes), and the next title, drawn off screen in the BIOS 8x8 font scaled up in a gold gradient with a band of light
; running down it, burns in through a shaped wipe with a glowing edge, rings a chime, and burns out through another.
; The cards sit on a slowly flowing bronze background (one x87 field, palette-cycled), the text has drop shadows, and
; each card shows the part count over a progress bar. Space skips to the next part (or past a card); Esc at any moment
; ends the show.
BITS 16
CPU 386
ORG 100h
%include "sizes.inc"          ; the byte counts of the 256-byte builds, written by build.sh
%ifdef ATLAS_SHOW
    %undef SZ_COUNT
    %undef SZ_TOTAL
    %define SZ_COUNT SZ_ATLAS_COUNT
    %define SZ_TOTAL SZ_ATLAS_TOTAL
    %define PROGRAM_FILE "mega/atlas_program.inc"
%else
    %define PROGRAM_FILE "mega/mega_program.inc"
%endif

    cld
    xor ax,ax
    mov fs,ax                 ; FS = 0: the BIOS tick count is [fs:46Ch], as every part assumes
    mov ax,cs
    add ax,1000h
    mov [pseg],ax             ; the parts run in the 64 KB segment above the megademo (FLOWTEX uses the next one)
    add ah,20h
    mov [mapseg],ax           ; then the wipe's map and the card, drawn off screen
    add ah,10h
    mov [cardseg],ax
    add ah,10h
    mov [bgseg],ax            ; and the cards' background, computed once
    xor ax,ax
    mov [afterpart],al        ; (the variables past the end of the file start as whatever memory held)
    mov [wipe_n],ax
    mov [xsh],ax
    mov [partno],al
    mov [lastkey],al
    mov [bgph],ax
    mov si,parts              ; count the parts
    xor bx,bx
.cnt:
    inc bx
    add si,5
    call skipz
    call skipz
    call skipz
    cmp si,parts_end
    jb .cnt
    mov [nparts],bl
    call gen_bg
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
    mov word [line4],hint     ; the intro: the keys, no progress bar
    mov word [bar],0
    mov si,intro
    mov cl,200                ; held longer
    call card
    jc quit
    mov bx,parts
.next:                        ; BX -> a part: dw code, dw length, db seconds, then the card's three lines
    push bx
    call progress             ; current part and the progress bar
    lea si,[bx+5]
    mov cl,80
    call card                 ; leaves SI at the next part
    pop bx
    jc quit
    push si
%ifndef ATLAS_SHOW
    cmp word [bx],warp_bin
    jne .run
    push bx
    call credits              ; WARP bends whatever is on the text screen: give it the credits
    pop bx
%endif
.run:
    call run_part
    mov byte [afterpart],1
    mov es,[pseg]
    cmp byte [es:5Eh],0
    pop bx
    jne quit                  ; Esc during the part
    cmp bx,parts_end
    jb .next
    mov word [line4],thanks
    mov word [bar],240
    mov si,outro
    mov cl,240
    call card                 ; the end
%ifdef ATLAS_SHOW
    jc quit
    call credits
    mov cx,180
.credits_hold:
    call vsync
    jc quit
    loop .credits_hold
%endif
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
    jne .k
    mov [5Eh],al              ; Esc: tell the megademo
    stc
    jmp short .x
.k: cmp al,[cs:lastkey]       ; Space, just pressed: on to the next part
    mov [cs:lastkey],al
    je .t
    cmp al,39h
    stc
    je .x
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
svc_midi:                     ; MIDI header; ATLAS also adds a clocked rhythm section
    mov dx,330h
    push ax
    mov ax,3FC0h
    out dx,ax
    pop ax
    out dx,al
%ifdef ATLAS_SHOW
    push bx
    mov bx,[fs:46Ch]
    mov al,99h                ; channel 10: a velocity-shaped closed hi-hat each tick
    out dx,al
    mov al,42
    out dx,al
    mov al,bl
    and al,15
    add al,32
    out dx,al
    test bl,3                 ; quarter-note kick/snare, bass and harmony
    jnz .atlas_lead
    mov al,bl
    and al,4
    shr al,1
    add al,36                 ; kick 36, snare 38, alternating every four ticks
    out dx,al
    mov al,100
    out dx,al
    mov al,0C1h               ; channel 2: acoustic bass
    out dx,al
    mov al,32
    out dx,al
    mov al,91h
    out dx,al
    mov al,bl
    shr al,2
    and al,14
    add al,30
    aam 5
    aad 6                    ; changing C-pentatonic bass root
    mov ah,al
    out dx,al
    mov al,72
    out dx,al
    mov al,0C2h               ; channel 3: short pizzicato root/fifth dyad
    out dx,al
    mov al,45
    out dx,al
    mov al,92h
    out dx,al
    mov al,ah
    add al,12
    out dx,al
    mov al,52
    out dx,al
    mov al,ah
    add al,19
    out dx,al
    mov al,44
    out dx,al
.atlas_lead:
    pop bx
%endif
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
    cmp al,[lastkey]          ; a key that has just gone down
    mov [lastkey],al
    je .k
    cmp al,39h                ; Space: skip (the card's hold reads it)
    jne .k
    mov [skip],al
.k: clc
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

; ---- a title card: SI -> the big title, a size line and a tagline (zero-terminated), CL = frames to hold.
;      Out of a mode-13h part the last frame drains to sepia; out of anything else it fades to black. The card then
;      arrives through a wipe, is held with a chime and a band of light running down its letters, and leaves through
;      another wipe to black. Each wipe has its own shape (see gen_map) and a burning edge. Returns SI after the third
;      line, CF = 1 on Esc.
card:
    push cx
    push si
    mov ah,0Fh
    int 10h                   ; the current video mode
    cmp al,13h
    jne .fade
    cmp byte [afterpart],0
    je .ready
    call desat                ; a mode-13h picture: drain it to sepia, into colours 128..191
    jc .esc2
    jmp short .ready
.fade:
    call fade_out             ; planar or text: fade it, then mode 13h
    jc .esc2
    mov ax,13h
    int 10h
.ready:
    call set_ramps            ; the sepia ramp, the burn ramp, black
    mov bl,32
    call card_pal
    push ds                   ; draw the card off screen, on the flowing background
    mov es,[cardseg]
    mov ds,[bgseg]
    xor si,si
    xor di,di
    mov cx,16000
    rep movsd
    pop ds
    pop si
    mov byte [solid],0
    mov ax,34 * 256 + 5       ; the name, 40 pixels high, in the gold gradient, with a shadow
    mov cl,2
    call text2
    mov byte [solid],200
    mov ax,92 * 256 + 2       ; the size (colour 200)
    mov cl,1
    call text2
    mov byte [solid],201
    mov ax,122 * 256 + 1      ; the tagline (201)
    mov cl,1
    call text2
    push si
    mov cx,[bar]              ; the progress bar: a dark track, filled in gold
    jcxz .nobar
    mov di,146 * 320 + 40
    mov bl,4
.bar:
    push di
    mov al,193
    mov cx,240
    rep stosb
    pop di
    push di
    mov al,100
    mov cx,[bar]
    rep stosb
    pop di
    add di,320
    dec bl
    jnz .bar
.nobar:
    mov si,[line4]            ; the fourth line: the keys, the part number, or thanks
    mov ax,160 * 256 + 1
    mov cl,1
    call text2
    mov byte [solid],0
    pop si
    push si
    mov al,[wipe_n]           ; in: the next shape
    call gen_map
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
    call wipe                 ; the card burns in
    jc .esc2
    mov es,[cardseg]          ; out: to black, through the next shape
    call clear_es
    mov al,[wipe_n]
    add al,3
    call gen_map
    pop si
    pop cx
    movzx cx,cl
    mov bl,32
    mov byte [skip],0
.h: call .frame               ; hold, until the time is up or Space is pressed
    jc .x
    cmp byte [skip],0
    jne .hx
    loop .h
.hx:
    push si
    call wipe                 ; the card burns away
    pop si
    inc byte [wipe_n]
    mov byte [afterpart],0
    ret
.esc2:
    pop si
.esc:
    pop cx
    stc
.x: ret
.frame:                       ; one frame of the card: CF = 1 on Esc
    call vsync
    jc .r
    call card_pal
    clc
.r: ret

; ---- drain the mode-13h picture on screen to sepia: the DAC crossfades from the part's palette to the luminance of
;      each colour (24 frames), then, racing the beam down from the top of a retrace, every pixel is moved to colour
;      128 + its luminance and colours 128..191 become the same sepia ramp, so nothing visible changes and the rest
;      of the palette is free for the card
desat:
    push ds
    pop es
    mov dx,3C7h
    xor al,al
    out dx,al
    mov dl,0C9h
    mov di,dac
    mov cx,768
    rep insb                  ; the part's palette
    mov si,dac
    mov di,lum
    mov cx,256
.l: lodsb                     ; luminance = (2R + 5G + B) / 8, 0..63
    movzx ax,al
    add ax,ax
    mov bx,ax
    lodsb
    mov ah,0
    imul ax,ax,5
    add bx,ax
    lodsb
    mov ah,0
    add ax,bx
    shr ax,3
    stosb
    loop .l
    mov bp,1
.f: call vsync                ; 24 frames: each channel moves from the part's colour to the sepia of its luminance
    jc .x
    mov dx,3C8h
    xor al,al
    out dx,al
    inc dx
    mov si,dac
    mov bx,lum
.c: mov al,[bx]
    call sepia                ; CL, CH, AH = the sepia of the luminance
    push ax
    mov al,cl
    call .mix
    mov al,ch
    call .mix
    pop ax
    mov al,ah
    call .mix
    inc bx
    cmp bx,lum + 256
    jb .c
    inc bp
    cmp bp,25
    jb .f
    call vsync                ; then, from the top of a retrace: the ramp at 128..191 and every pixel moved there
    jc .x
    call ramp_sepia
    push word 0A000h
    pop es
    xor di,di
    mov bx,remap
    mov cx,256                ; (the table: 128 + luminance)
    mov si,lum
.t: lodsb
    add al,128
    mov [bx],al
    inc bx
    loop .t
    mov bx,remap
    mov cx,64000
.p: mov al,[es:di]
    xlat
    stosb
    loop .p
    clc
.x: ret
.mix:                         ; out the part's channel + (the sepia channel - it) x frame / 24
    push ax
    lodsb
    mov ah,0
    mov di,ax
    pop ax
    mov ah,0
    sub ax,di
    imul ax,bp
    push dx
    cwd
    push bx
    mov bx,24
    idiv bx
    pop bx
    pop dx
    add ax,di
    out dx,al
    ret

sepia:                        ; AL = luminance 0..63 -> CL = R, CH = G = 13/16, AH = B = 9/16 of it
    movzx ax,al
    mov cl,al
    imul ax,ax,13
    shr ax,4
    mov ch,al
    movzx ax,cl
    imul ax,ax,9
    shr ax,4
    mov ah,al
    mov al,cl
    ret
ramp_sepia:                   ; colours 128..191: the sepia ramp
    mov dx,3C8h
    mov al,128
    out dx,al
    inc dx
    xor al,al
.r: push ax
    call sepia
    xchg ax,cx                ; AL = R, AH = G
    out dx,al
    mov al,ah
    out dx,al
    pop ax
    push ax
    call sepia
    mov al,ah
    out dx,al
    pop ax
    inc ax
    cmp al,64
    jb .r
    ret

; ---- the ramps the wipes use: black at 0, the sepia ramp at 128..191, and the burning edge at 224..255, deep orange
;      behind the front to white-gold on it
set_ramps:
    mov dx,3C8h
    xor al,al
    out dx,al
    inc dx
    out dx,al
    out dx,al
    out dx,al
    call ramp_sepia
    mov al,224
    dec dx
    out dx,al
    inc dx
    xor cx,cx
.b: mov al,cl                 ; R = 32 + k
    add al,32
    out dx,al
    mov al,cl                 ; G = 8 + 7k/4
    imul ax,ax,7
    shr ax,2
    add al,8
    out dx,al
    mov al,cl                 ; B = k^2 / 20
    mul al
    push dx
    xor dx,dx
    push bx
    mov bx,20
    div bx
    pop bx
    pop dx
    out dx,al
    inc cx
    cmp cl,32
    jb .b
    ret

clear_es:                     ; 64,000 zero bytes at ES:0
    xor di,di
    xor ax,ax
    mov cx,32000
    rep stosw
    ret

; ---- a wipe: the screen turns into the picture at [cardseg] where the map at [mapseg] is below a threshold that
;      rises 5 a frame; just ahead of it a 16-wide band burns (colours 224..255, brightest at the front)
wipe:
    mov ax,[mapseg]
    mov gs,ax
    mov fs,[cardseg]
    push word 0A000h
    pop es
    mov bp,-16
.f: mov bl,32
    call card.frame           ; the card's band of light keeps running
    jc .x
    xor di,di
.p: movzx ax,byte [gs:di]
    sub ax,bp
    jl .new                   ; behind the front: the new picture
    cmp ax,16
    jae .n                    ; ahead of the band: untouched
    shl al,1                  ; in the band: 255 at the front, 225 at its back
    not al
    jmp short .w
.new:
    mov al,[fs:di]
.w: mov [es:di],al
.n: inc di
    cmp di,64000
    jb .p
    add bp,5
    cmp bp,256 + 16
    jl .f
    clc
.x: push word 0
    pop fs                    ; FS = 0 again for the parts
    ret

; ---- the wipe shapes: a value 0..255 per pixel, the order in which pixels turn. X = x - 160, Y = 1.2 (y - 100)
;      (square pixels), r and a its polar form. AL = the shape number (mod 7); [wipe_n] also turns the patterns.
;        0 star     r (1 + 0.2 sin(5a + p)) 1.25            an iris opening in a five-pointed star
;        1 burn     sums of sines of x, y, x + y and r     the picture burns away in blobs, like paper
;        2 spiral   (a + pi) 25.5 + r / 2                  a sweep that turns outwards
;        3 close    255 - r (1.25 + 0.1 sin(8a + p))       a petalled iris closing on the centre
;        4 drip     1.15 y + 20 + 22 sin(0.37 x + p) + ...  a curtain falling in drips
;        5 diamond  0.95 (|X| + |Y|) + 10 sin(r / 5)       a rippled diamond opening
;        6 fizzle   a random byte                           a dissolve that sparkles
gen_map:
    push si
    fninit                    ; (a part may have left values on the FPU stack)
    movzx ax,al
    mov bl,7
    div bl
    movzx bx,ah
    add bx,bx
    mov si,[mapfn + bx]
    fild word [wipe_n]
    fmul dword [f13]
    fstp dword [phase_f]
    mov es,[mapseg]
    xor di,di
    mov word [gy],0
.y: mov word [gx],0
.x: call si                   ; -> AX
    test ah,ah
    jz .ok
    sar ax,15                 ; below 0: 0, above 255: 255
    not al
.ok: stosb
    inc word [gx]
    cmp word [gx],320
    jb .x
    inc word [gy]
    cmp word [gy],200
    jb .y
    pop si
    ret
mapfn: dw m_star, m_burn, m_spiral, m_close, m_drip, m_diamond, m_fizzle

polar:                        ; -> st0 = a, st1 = r (and X, Y gone)
    fild word [gx]
    fisub word [c160]
    fild word [gy]
    fisub word [c100]
    fmul dword [f_aspect]     ; Y, X
    fld st1
    fmul st0,st0
    fld st1
    fmul st0,st0
    faddp st1,st0
    fsqrt                     ; r, Y, X
    fxch st2                  ; X, Y, r
    fpatan                    ; a = atan2(Y, X), r
    ret
m_star:
    call polar
    fimul word [c5]
    fadd dword [phase_f]
    fsin
    fmul dword [f02]
    fld1
    faddp st1,st0
    fmulp st1,st0
    fmul dword [f125]
    jmp m_out
m_close:
    call polar
    fimul word [c8]
    fadd dword [phase_f]
    fsin
    fmul dword [f01]
    fadd dword [f125]
    fmulp st1,st0
    fisubr word [c255]
    jmp m_out
m_spiral:
    call polar
    fldpi
    faddp st1,st0
    fmul dword [f255]
    fxch st1
    fmul dword [f05]
    faddp st1,st0
    jmp m_out
m_out:
    fistp word [val]
    mov ax,[val]
    ret
m_burn:
    fild word [gx]            ; sin(x/17 + p)
    fmul dword [f_17]
    fadd dword [phase_f]
    fsin
    fild word [gy]            ; + sin(y/13 + x/29)
    fmul dword [f_13]
    fild word [gx]
    fmul dword [f_29]
    faddp st1,st0
    fsin
    faddp st1,st0
    fild word [gx]            ; + sin((x + y)/23 - p)
    fiadd word [gy]
    fmul dword [f_23]
    fsub dword [phase_f]
    fsin
    faddp st1,st0
    fmul dword [f34]          ; x 34
    call polar                ; + 20 sin(r/9)
    fstp st0
    fmul dword [f_9]
    fsin
    fmul dword [f20]
    faddp st1,st0
    fiadd word [c128]
    jmp m_out
m_drip:
    fild word [gy]
    fmul dword [f115]
    fild word [gx]
    fmul dword [f037]
    fadd dword [phase_f]
    fsin
    fmul dword [f22]
    faddp st1,st0
    fild word [gx]
    fmul dword [f113]
    fsin
    fmul dword [f14]
    faddp st1,st0
    fiadd word [c20]
    jmp m_out
m_diamond:
    fild word [gx]
    fisub word [c160]
    fabs
    fild word [gy]
    fisub word [c100]
    fmul dword [f_aspect]
    fabs
    faddp st1,st0
    fmul dword [f095]
    call polar
    fstp st0
    fmul dword [f_5]
    fsin
    fmul dword [f10]
    faddp st1,st0
    jmp m_out
m_fizzle:
    imul ax,[seed],25173
    add ax,13849
    mov [seed],ax
    shr ax,8
    ret
c5:   dw 5
c8:   dw 8
c20:  dw 20
c100: dw 100
c128: dw 128
c160: dw 160
c255: dw 255
f_aspect: dd 1.2
f02:  dd 0.2
f01:  dd 0.1
f05:  dd 0.5
f13:  dd 1.3
f125: dd 1.25
f255: dd 25.5
f_17: dd 0.0588
f_13: dd 0.0769
f_29: dd 0.0345
f_23: dd 0.0435
f_9:  dd 0.111
f_5:  dd 0.2
f34:  dd 34.0
f20:  dd 20.0
f115: dd 1.15
f037: dd 0.37
f22:  dd 22.0
f113: dd 1.13
f14:  dd 14.0
f095: dd 0.95
f10:  dd 10.0
seed: dw 1234

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
    mov cl,12
.g: lodsb                     ; 200, 201 the warm greys; 202..203 unused, 204.. not written
    call .out
    loop .g
    mov al,192                ; 192 the shadow (black), 193 the progress bar's track
    dec dx
    out dx,al
    inc dx
    xor al,al
    out dx,al
    out dx,al
    out dx,al
    mov al,14
    call .out
    mov al,10
    call .out
    mov al,6
    call .out
    mov al,1                  ; 1..63 the background: dark bronze bands that flow, one step a frame
    dec dx
    out dx,al
    inc dx
    inc byte [bgph]
    cmp byte [bgph],63
    jb .ph
    mov byte [bgph],0
.ph:
    mov cl,1
.bgc:
    movzx si,cl
    add si,[bgph]             ; (bgph and the byte after it, 0, as a word)
    cmp si,63
    jb .w
    sub si,63
.w: mov al,[bgsin + si]       ; b = 3..15
    mov ah,al
    shr ah,2
    add al,ah
    call .out                 ; R = 5b/4
    mov al,[bgsin + si]
    mov ah,al
    shr ah,2
    sub al,ah
    call .out                 ; G = 3b/4
    mov al,[bgsin + si]
    shr al,1
    call .out                 ; B = b/2
    inc cx
    cmp cl,64
    jb .bgc
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
greys: db 58, 54, 46, 34, 30, 24, 0, 0, 0, 0, 0, 0

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
    add ax,[xsh]              ; (shifted for a shadow)
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

; the same, twice: first in colour 192 (black) CL pixels right and down, the shadow, then itself
text2:
    push si
    mov bl,[solid]
    push bx
    mov byte [solid],192
    movzx bx,cl
    mov [xsh],bx
    push ax
    add ah,cl
    call text
    pop ax
    mov word [xsh],0
    pop bx
    mov [solid],bl
    pop si
    jmp text

; "PART n OF 11" into [line4] and the progress bar's length into [bar], for the part about to be shown
progress:
    push bx
    inc byte [partno]
    mov dword [partline],'PART'
    mov byte [partline + 4],' '
    mov di,partline + 5
    push ds
    pop es
    movzx ax,byte [partno]
    aam                       ; AH = tens, AL = units
    test ah,ah
    jz .one
    xchg al,ah
    add al,'0'
    stosb
    xchg al,ah
.one:
    add al,'0'
    stosb
    mov si,of_n
.c: lodsb
    stosb
    test al,al
    jnz .c
    mov word [line4],partline
    movzx ax,byte [partno]
    imul ax,ax,240
    div byte [nparts]
    movzx ax,al
    mov [bar],ax
    pop bx
    ret

; the cards' background, once: bands of a smooth field, colours 1..63, which the palette cycles so they flow
gen_bg:
    fninit
    mov es,[bgseg]
    xor di,di
    mov word [gy],0
.y: mov word [gx],0
.x: fild word [gx]            ; f = sin(0.031 x) + sin(0.043 y + 0.019 x) + sin(0.024 (x - y)) + sin(0.06 r)
    fmul dword [b1]
    fsin
    fild word [gy]
    fmul dword [b2]
    fild word [gx]
    fmul dword [b3]
    faddp st1,st0
    fsin
    faddp st1,st0
    fild word [gx]
    fisub word [gy]
    fmul dword [b4]
    fsin
    faddp st1,st0
    call polar
    fstp st0
    fmul dword [b5]
    fsin
    faddp st1,st0
    fiadd word [c4]           ; 0..8
    fmul dword [f20]          ; 0..160
    fistp word [val]
    mov ax,[val]
    xor dx,dx
    mov cx,63
    div cx
    mov al,dl                 ; 1 + (that mod 63)
    inc ax
    stosb
    inc word [gx]
    cmp word [gx],320
    jb .x
    inc word [gy]
    cmp word [gy],200
    jb .y
    fninit                    ; the sine table for the background's palette: 9 + 6 sin(2 pi k / 63)
    mov di,bgsin
    push ds
    pop es
    xor cx,cx
.s: mov [val],cx
    fild word [val]
    fmul dword [b6]
    fsin
    fmul dword [f6]
    fiadd word [c9]
    fistp word [val]
    mov al,[val]
    stosb
    inc cx
    cmp cx,63
    jb .s
    ret
b1: dd 0.031
b2: dd 0.043
b3: dd 0.019
b4: dd 0.024
b5: dd 0.06
b6: dd 0.09973             ; 2 pi / 63
f6: dd 6.0
c4: dw 4
c9: dw 9

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
    mov bp,di                 ; start of the current credits row
    mov bx,parts
.pl:
    lea si,[bx+5]
    push si
    call skipz
    mov ax,si
    sub ax,bx
    sub ax,6                  ; next name's length, excluding its terminator
    add ax,di
    sub ax,bp
    cmp ax,70
    jbe .fits
    mov byte [di-1],0          ; wrap at a name boundary, never split a name
    mov bp,di
.fits:
    pop si
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
    mov byte [di],0            ; double zero terminates the list of rows
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
.names:
    call putline
    cmp byte [si],0
    je .names_done
    add di,2 * 160
    jmp .names
.names_done:
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
%macro PART 6                 ; label, size, seconds, title, tagline, binary path
    %strlen %%title_length %4
    %assign CREDITS_BYTES CREDITS_BYTES + %%title_length + 1
    %if %%title_length > 70
        %error Part title exceeds the credits row width
    %endif
    dw %1_bin, %1_end - %1_bin
    db %3, %4, 0, %2, " BYTES", 0, %5, 0
%endmacro
%define ENTRY PART

intro:
%ifdef ATLAS_SHOW
    db "UBER256", 0, "ATLAS SHOW", 0, SZ_COUNT, " INTROS, 256 BYTES EACH, MUSIC LIVE", 0
%else
    db "UBER256", 0, "LAB  MEGADEMO", 0, SZ_COUNT, " INTROS, 256 BYTES EACH, MUSIC LIVE", 0
%endif
outro:
    db "THE END", 0, SZ_COUNT, " INTROS", 0, "ALL OF THEM TOGETHER: ", SZ_TOTAL, " BYTES", 0
parts:
%assign CREDITS_BYTES 1
%include PROGRAM_FILE
parts_end:
%if CREDITS_BYTES > 256
    %error Playlist exceeds the credits buffer
%endif

credit_lines:
%ifdef ATLAS_SHOW
    db "U B E R 2 5 6 - L A B   A T L A S   S H O W", 0
%else
    db "U B E R 2 5 6 - L A B   M E G A D E M O", 0
%endif
    db SZ_COUNT, " intros of 256 bytes or less, each playing its own music", 0
    db 1                      ; the parts, read from the programme above
    db "code and music: djayuffe & Claude", 0
    db "NASM - 16-bit real mode - VGA - x87 - MPU-401 General MIDI", 0
    db "github.com/djayuffe/uber256-lab", 0
    db "thanks for watching", 0
    db 0FFh
hint:   db "SPACE: NEXT PART     ESC: QUIT", 0
thanks: db "THANKS FOR WATCHING", 0
of_n:   db " OF ", SZ_COUNT, 0
bye:
%ifdef ATLAS_SHOW
    db "uber256-lab atlas show. Thanks for watching.", 13, 10, "$"
%else
    db "uber256-lab megademo. Thanks for watching.", 13, 10, "$"
%endif

%macro BIN 2
%1_bin:
    incbin %2
%1_end:
%endmacro
%undef ENTRY
%macro ENTRY 6
    BIN %1, %6
%endmacro
%include PROGRAM_FILE
%unmacro ENTRY 6

section .bss
pseg:    resw 1
bgseg:   resw 1
xsh:     resw 1
bar:     resw 1
line4:   resw 1
partno:  resb 1
nparts:  resb 1
lastkey: resb 1
skip:    resb 1
bgph:    resb 1
bgph_hi: resb 1               ; (always 0: bgph is read as a word)
bgsin:   resb 64
partline: resb 24
mapseg:  resw 1
cardseg: resw 1
afterpart: resb 1
wipe_n:  resb 1
wipe_nh: resb 1               ; (wipe_n as a word, for the FPU)
gx:      resw 1
gy:      resw 1
val:     resw 1
phase_f: resd 1
lum:     resb 256
remap:   resb 256
fadein:  resb 1
orig:    resb 768
last:    resb 768
font:    resw 2
save_sp: resw 1
scale:   resb 1
solid:   resb 1
phase:   resb 1
linebuf: resb 256             ; room for the full atlas playlist and wrapped rows
dac:     resb 768
