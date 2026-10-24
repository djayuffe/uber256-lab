; Compile-time VGA palettes. Every channel is bounded to the DAC's 0..63 range.
; Noncyclic ramps start at black; SPECTRUM is periodic for interference fields.
%macro CHANNEL 1
    mov al,bl
%ifidni %1,fast
    shr al,1
    cmp al,63
    jbe %%ready
    mov al,63
%%ready:
%elifidni %1,linear
    shr al,2
%elifidni %1,quarter
    shr al,4
%elifidni %1,square
    mul al
    shr ax,10
%elifidni %1,squarehalf
    mul al
    shr ax,11
%elifidni %1,squarequarter
    mul al
    shr ax,12
%else
    %error Unknown palette channel
%endif
    out dx,al
%endmacro
%macro WAVE 1
    mov al,bl
%if %1 != 0
    add al,%1
%endif
    cbw                       ; sign mask: fold 128..255 without a branch
    xor al,ah
    sub al,64                 ; half-wave clipping gives saturated RGB primaries
    jnc %%ready
    xor al,al
%%ready:
    out dx,al
%endmacro
%ifndef PALETTE
    %error Atlas wrapper must select a PALETTE
%endif
%macro ATLAS_COLOUR 0
%if PALETTE = 1                ; FIRE: red -> orange -> yellow
    CHANNEL fast
    CHANNEL square
    CHANNEL quarter
%elif PALETTE = 2              ; ICE: deep blue -> cyan
    CHANNEL squarehalf
    CHANNEL linear
    CHANNEL fast
%elif PALETTE = 3              ; ORCHID: violet -> lavender
    CHANNEL linear
    CHANNEL squarehalf
    CHANNEL fast
%elif PALETTE = 4              ; EMERALD: green -> mint
    CHANNEL squarehalf
    CHANNEL fast
    CHANNEL linear
%elif PALETTE = 5              ; GOLD: amber -> warm gold
    CHANNEL fast
    CHANNEL linear
    CHANNEL squarequarter
%elif PALETTE = 6              ; ROSE: crimson -> pink
    CHANNEL fast
    CHANNEL squarequarter
    CHANNEL linear
%elif PALETTE = 7              ; SPECTRUM: three phase-shifted triangular channels
    WAVE 0
    WAVE 85
    WAVE 170
%else
    %error Unknown PALETTE
%endif
%endmacro
