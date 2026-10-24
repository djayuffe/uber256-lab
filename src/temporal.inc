; Shared standalone 256-byte engine. BX=x, SI=y, BP=BIOS time, DI=screen.
; Palette and MIDI are computed; no external assets. FS is explicitly zeroed.
BITS 16
CPU 386
ORG 100h
%include "dos.inc"
%include "palettes.inc"
    mov ax,13h
    int 10h
    xor ax,ax
    mov fs,ax
%if PALETTE != 7
    mov dx,3C8h
    out dx,al
    inc dx
    xor bx,bx
.pal:
    ATLAS_COLOUR
    inc bl
    jnz .pal
%endif
    HOOK_TICK isr
    push word 0A000h
    pop es
frame:
    mov bp,[fs:46Ch]          ; snapshot once: no mid-frame time seams
    shl bp,1
%if PALETTE = 7
    mov dx,3C8h
    xor ax,ax
    out dx,al
    inc dx
    mov bx,bp
    shr bx,3                  ; slow colour phase, independent of render speed
    xor cx,cx
.cycle:
    ATLAS_COLOUR
    inc bl
    inc cl                    ; exactly 256 entries even when phase is nonzero
    jnz .cycle
%endif
    xor di,di
    mov si,-100
.row:
%ifdef CAUSAL
    mov cx,si
    imul cx,cx                ; y*y once per row instead of once per pixel
%endif
%ifdef HORIZON
    mov cx,si
    imul cx,cx
%endif
%ifdef SURGERY
    mov cx,si
    imul cx,cx
%endif
    mov bx,-160
.px:
%ifdef CAUSAL
    mov ax,bx
    imul ax,ax
    add ax,cx                 ; r2 <= 35600: unsigned, fits 16 bits
    shr ax,8
    mov dx,bp
    sub dx,ax                 ; local time = time - r2/256
    and ax,0FFF0h             ; shells use different discrete ages
    sub dx,ax                 ; add a discrete delay at each shell boundary
    mov ax,dx
    add ax,bx
    sub ax,si
    call triangle
%elifdef HORIZON
    mov ax,bx
    imul ax,ax
    add ax,cx
    shr ax,8
    inc ax                    ; radius weight 1..140
    mul bp                    ; unsigned 32-bit product
    mov al,ah                 ; floor(time * weight / 256), low byte
    add ax,bx
    sub ax,si
    call triangle
%elifdef COMMUTE
    mov ax,bx
    mov dx,si
    test bp,128
    jnz .ba
    add ax,dx                 ; A: x += y, then B: y += x
    add dx,ax
    jmp short .ordered
.ba:
    add dx,ax                 ; B then A: a different coordinate frame
    add ax,dx
.ordered:
    add ax,bp
    call triangle
    push ax
    mov ax,dx
    sub ax,bp
    call triangle
    pop dx
    xor al,dl
%elifdef LIFT
    mov ax,bx
    mov dx,si
    mov cx,bp
    shr cx,3
    and cx,31
    cmp cx,16
    jbe .depth
    neg cx
    add cx,32                 ; 0..16..0 exact retracing of lifting depth
.depth:
    jcxz .mixed
.lift:
    add al,dl                 ; reversible lifting on two byte channels
    xor dl,al
    loop .lift
.mixed:
    xor al,dl
%elifdef MIRROR
    mov ax,bx
    mov dx,si
    mov cx,bx
    add cx,si
    add cx,bp
    test cx,64
    jz .world
    xor ax,255                ; F(F(x,y)) = (x,y), exact bitwise involution
    xor dx,127
.world:
    imul ax,dx
    shr ax,3
    call triangle
%elifdef RESFIELD
    mov cx,bx
    add cx,si
    add cx,bp
    shr cx,5
    and cx,3                  ; spatially moving 1/2/4/8-pixel cells
    mov ax,bx
    sar ax,cl
    shl ax,cl
    mov dx,si
    sar dx,cl
    shl dx,cl
    imul ax,dx
    shr ax,4
    add ax,bp
    call triangle
%elifdef SHUFFLE
    mov ax,bx
    add ax,160
    mov dx,ax
    and ax,31                 ; virtual lane within a 32-pixel row group
    mov cx,bp
    shr cx,2
    and cx,31
    xor ax,cx                 ; bijective lane permutation
    and dx,0FFE0h
    or ax,dx
    add ax,si
    call triangle
    mov dl,al
    mov ax,bx
    sub ax,si
    add ax,bp
    call triangle
    xor al,dl                 ; original and transported fields interfere
    add al,bl                 ; carrier gradient avoids collapsed XOR palettes
%elifdef HYSTER
    mov ax,bx
    add ax,si
    add ax,bp
    call triangle
    cmp al,160
    jae .on
    cmp al,96
    jbe .off
    mov al,[es:di]            ; retain the actual previous pixel in the dead band
    jmp short .state
.on:
    mov al,255
    jmp short .state
.off:
    xor al,al
.state:
%elifdef RESIDUAL
    mov ax,bx
    imul ax,si
    shr ax,4
    add ax,bp
    mov cx,ax
    call triangle
    mov dl,al
    mov ax,cx
    sub ax,8
    call triangle
    sub dl,al
    sub dl,al
    mov ax,cx
    sub ax,16
    call triangle
    add al,dl                 ; current - linear prediction from two past samples
%elifdef SIGNED
    mov ax,bx
    add ax,bp
    mov dx,si
    add dx,128
    push ax
    mul dl                    ; unsigned interpretation of the same two bytes
    mov cl,ah
    pop ax
    imul dl                   ; signed interpretation
    mov al,ah
    xor al,cl                 ; expose disagreement in product high bytes
%elifdef RUNS
    mov ax,bx
    imul ax,ax,321
    xor ax,si
    add ax,bp
    mov dx,ax
    shr dx,1
    xor ax,dx
    and ax,7FFFh              ; adjacent bit changes, no fictitious top boundary
    mov dx,ax                 ; SWAR popcount: sum pairs, nibbles, then bytes
    shr dx,1
    and dx,05555h
    sub ax,dx
    mov dx,ax
    and ax,03333h
    shr dx,2
    and dx,03333h
    add ax,dx
    mov dx,ax
    shr dx,4
    add ax,dx
    and ax,00F0Fh
    add al,ah
    inc al                    ; runs = changes + 1
    shl al,4                  ; 16 runs wraps to black, deliberately
%elifdef BYTEVM
    mov ax,bx
    mov dx,0B39Ch             ; eight 2-bit opcodes, same tape for every pixel
    mov cx,8
.opcode:
    push dx
    and dl,3
    cmp dl,1
    je .vx
    cmp dl,2
    je .vr
    cmp dl,3
    je .vn
    add ax,si
    jmp short .nextop
.vx:
    xor ax,bp
    jmp short .nextop
.vr:
    rol ax,3
    jmp short .nextop
.vn:
    neg ax
.nextop:
    pop dx
    shr dx,2
    loop .opcode
    xor al,ah
%elifdef REVERSO
    mov ax,bx
    imul ax,ax,257
    xor ax,si
    mov cx,bp
    shr cx,3
    and cx,15
    cmp cx,8
    jbe .revdepth
    neg cx
    add cx,16
.revdepth:
    jcxz .revdone
.revmix:
    add ax,1973
    rol ax,5
    xor ax,0A53Ch             ; all operations have exact 16-bit inverses
    loop .revmix
.revdone:
    xor al,ah
%elifdef BIFURC
    mov dx,bx
    add dx,160
    mov cx,bp
    shr cx,3
    and cx,255
    add dx,cx
    cmp dx,320
    jb .parameter
    sub dx,320
.parameter:
    shr dx,1
    add dl,96                 ; logistic parameter r=1.5..3.984375
    mov ax,si
    add ax,128
    mov cx,16
.logistic:
    mov dh,al
    mov ah,al
    neg ah
    mul ah
    mov al,ah                 ; floor(a*(256-a)/256)
    mul dl
    shr ax,6
    loop .logistic
    sub al,dh                 ; period-one residual, not a proof of chaos
%elifdef TERRACE
    mov ax,bx
    add ax,bp
    call triangle
    mov dl,al
    mov ax,si
    sub ax,bp
    call triangle
    cmp al,dl
    jae .max1
    mov al,dl
.max1:
    mov dl,al
    mov ax,bx
    add ax,si
    call triangle
    cmp al,dl
    jae .max2
    mov al,dl
.max2:
    and al,0F0h               ; winning extrema become height terraces
%elifdef LOOM
    mov al,[es:di]            ; persistent per-pixel state, ordered on the CPU
    mov dx,bx
    add dx,bp
    test dl,16
    jz .strand2
    add al,17                 ; strand A: add
.strand2:
    mov dx,si
    sub dx,bp
    test dl,16
    jz .woven
    rol al,1                  ; strand B: rotate; A then B differs from B then A
.woven:
%elifdef RING
    mov ax,bx
    sar ax,4
    imul ax,ax,1973
    xor ax,035A7h             ; one 16-cell ring per horizontal group
    mov cx,bp
    shr cx,3
    add cx,si
    and cx,15                 ; bounded generation depth
    jcxz .ringdone
    test cl,8                 ; on a 16-cell rule-90 ring F^8 is identically zero
    jz .ringstep
    xor ax,ax
    jmp short .ringdone
.ringstep:
    mov dx,ax
    rol ax,1
    ror dx,1
    xor ax,dx                 ; rule 90 with periodic, not zero, boundaries
    loop .ringstep
.ringdone:
    mov cx,bx
    and cx,15
    shr ax,cl
    and al,1
    neg al
%elifdef PREFIX
    mov cx,bx
    and cx,15
    inc cx                    ; inclusive scan of lanes 0 through selected lane
    mov dx,si
    add dx,bp
    push bx
    xor bx,bx
.scan:
    mov ax,dx
    call triangle
    shr al,4
    sub al,8
    add bl,al
    add dx,13
    loop .scan
    mov al,bl
    pop bx
    add ax,si
%elifdef RANK
    mov ax,bx
    and ax,7
    imul ax,ax,37
    mov dx,si
    add dx,bp
    xor al,dl                 ; selected lane's value
    mov dh,al
    xor cx,cx
    push bx
    xor bx,bx
.rankloop:
    mov ax,cx
    xor al,dl
    cmp al,dh
    adc bl,0                  ; count strictly lower values = exact sorted rank
    add cx,37                 ; successive lane values, no inner-loop multiply
    cmp cx,8*37
    jb .rankloop
    mov al,bl
    shl al,5
    pop bx
%elifdef BALLOT
    mov dx,bx
    and dx,0FFF0h
    add dx,si
    add dx,bp
    push bx
    xor bx,bx
    mov cx,16
.vote:
    mov ax,dx
    call triangle
    cmp al,128
    cmc                        ; carry = predicate tri >= 128
    rcl bx,1                  ; lane 0 becomes the high mask bit
    add dx,13
    loop .vote
    mov ax,bx
    pop bx
    mov cx,bx
    and cx,15
    rol ax,cl                 ; expose the selected lane's neighbourhood mask
%elifdef TIMELENS
    mov ax,bx
    imul ax,si
    shr ax,7
    mov dx,bp
    sub dx,ax                 ; local time from a saddle-shaped time field
    mov ax,si
    sar ax,3                  ; x displacement follows dT/dx = y
    add ax,bx
    add ax,dx
    call triangle
    push ax
    mov ax,bx
    sar ax,3                  ; y displacement follows dT/dy = x
    add ax,si
    add ax,dx
    sub ax,32                 ; second chronological sample
    call triangle
    pop dx
    xor al,dl
%elifdef EMBOSS
    mov ax,bx
    imul ax,si
    shr ax,4
    add ax,bp
    mov cx,ax
    call triangle
    mov dl,al
    mov ax,cx
    sub ax,8
    call triangle
    sub dl,al                 ; temporal derivative at x
    mov ax,bx
    inc ax
    imul ax,si
    shr ax,4
    add ax,bp
    mov cx,ax
    call triangle
    mov dh,al
    mov ax,cx
    sub ax,8
    call triangle
    sub dh,al                 ; temporal derivative at x+1
    sub dh,dl                 ; spatial derivative of temporal change
    mov al,dh
    shl al,3                  ; amplify relief before adding the neutral shade
    add al,96
%elifdef SURGERY
    mov ax,si
    sar ax,2
    neg ax
    add ax,bp                 ; local chronology varies down the object
    call triangle
    shr al,2
    movzx dx,al               ; distance of the two disc centres, 0..63
    mov ax,bx
    add ax,dx
    imul ax,ax
    add ax,cx
    push ax
    mov ax,bx
    sub ax,dx
    imul ax,ax
    add ax,cx
    pop dx
    cmp ax,dx
    jbe .nearest
    mov ax,dx
.nearest:
    cmp ax,1024               ; union of radius-32 discs splits and reconnects
    ja .outside
    shr ax,3
    not al
    jmp short .topology
.outside:
    xor al,al
.topology:
%elifdef BRACKET
    mov ax,bx
    mov dx,si
    mov cx,bp
    shr cx,4
    and cx,3
    add ax,dx                 ; A
    jcxz .transported
    add dx,ax                 ; B
    cmp cx,1
    je .transported
    sub ax,dx                 ; inverse A
    cmp cx,2
    je .transported
    sub dx,ax                 ; inverse B: a nontrivial commutator
.transported:
    add ax,bp
    call triangle
    push ax
    mov ax,dx
    call triangle
    pop dx
    xor al,dl
%elifdef ORBIT
    mov dx,bx
    sar dx,2                  ; readable four-by-two-pixel period cells
    add dx,bp
    mov ax,si
    sar ax,1
    add ax,128
    mov dh,al                 ; initial byte state
    mov cx,16                 ; F^16 is identity for every XOR mask
.orbit:
    rol al,1
    xor al,dl
    cmp al,dh
    je .returned
    loop .orbit
.returned:
    mov al,17
    sub al,cl                 ; exact return period, 1/2/4/8/16
    mov ah,15
    mul ah
%elifdef CRITICAL
    mov dx,bx
    add dx,160
    shr dx,1
    add dl,96                 ; quantized logistic parameter
    mov ax,si
    add ax,bp
    add al,128
    push bx
    mov bx,ax
    xor bl,1                  ; neighbouring initial condition
    mov cl,16
.nearby:
    mov ah,al
    neg ah
    mul ah
    mov al,ah
    mul dl
    shr ax,6
    mov bh,al
    mov al,bl
    mov ah,al
    neg ah
    mul ah
    mov al,ah
    mul dl
    shr ax,6
    mov bl,al
    mov al,bh
    dec cl
    jnz .nearby
    sub al,bl
    jnc .distance
    neg al
.distance:
    cmp al,8
    jb .quiet
    cmp al,96
    jae .quiet
    shl al,1                  ; show intermediate divergence only
    jmp short .density
.quiet:
    xor al,al
.density:
    pop bx
%elifdef PHASE
    mov ax,bx
    add ax,bp
    call triangle
    mov dl,al
    mov ax,si
    sub ax,bp
    call triangle
    add dl,al
    mov ax,bx
    add ax,si
    mov cx,bp
    shr cx,1                  ; third wave runs at half speed
    add ax,cx
    call triangle
    sub dl,al
    mov al,dl
%else
    %error Atlas wrapper must select a known effect
%endif
    stosb
    inc bx
    cmp bx,160
    jl .px
    inc si
    cmp si,100
    jl .row
    mov dx,3DAh
.vs:
    in al,dx
    test al,8
    jz .vs
    ESC_OR_LOOP frame
triangle:                     ; signed-byte absolute value, 0..128, then double
    cbw
    xor al,ah
    sub al,ah
    add al,al                 ; deliberate modulo-256 peak at -128
    ret
isr:
    pusha
    MIDI_START INSTRUMENT     ; every effect gets its own decaying GM voice
    mov bx,[fs:46Ch]
    imul bx,bx,321
    mov al,[es:bx]            ; sound follows the phase field at a moving probe
    and al,30
    add al,50
    PENTA
    out dx,al                 ; image-derived lead: pitch also supplies velocity
    out dx,al
    sub al,24                 ; a two-octave-low response, still in the same scale
    out dx,al
    out dx,al
    popa
    iret
