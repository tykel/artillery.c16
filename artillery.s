;-----------------------------------------------------------------------------
; artillery.s
;
; Clone of Scorched Earth for Chip16.
; Copyright (C) 2023, Tim Kelsall.
;
;-----------------------------------------------------------------------------

init:          call gen_columns
loop:          cls
               bgc 1
               call drw_columns
               call drw_cannons
               vblnk
               jmp loop

;--------------------------------------
; gen_columns --
;
; Generate terrain, settling with 128 2px columns.
; - First column randomly selected within a middle interval
; - Select each subsequent column as a function of the previous one.
;
;--------------------------------------
gen_columns:
             ; Generate column 0
             ldi r0, 16             ; col[0] height in [16..160]
             ldi r1, 160
             call gen_x_ranged
.aaa:        ldi r8, data.terrain
.gen_col0:   stm r0, r8

             ; Generate next columns iteratively
.gen_colLL0: ldi r9, 2              ; for (x = 2;
.gen_colLL:  cmpi r9, 256           ;      x < 256;
             jz .gen_colZ           ;      x+=2) {

; col[x] = gen_x_ranged(max(1, col[x - 1] - 2), min(col[x - 1] + 3, 239));
;
; col[x] here stored as a dword array, but addresses are byte-level, hence cast
; to (u8*) with offset
             add r9, r8, r7         ; (u8*)col + x
             subi r7, 2             ; (u8*)col + x - 2
             ldm r7, r7             ; *((u8*)col + x - 2)
             mov r0, r7
             subi r0, 2
             cmpi r0, 1
             jge .gen_colLLa
             ldi r0, 1              ; r0 = max(1, col[x - 1] - 2)
.gen_colLLa: mov r1, r7
             addi r1, 2
             cmpi r1, 239
             jle .gen_colLLb
             ldi r1, 239            ; r1 = min(239, col[x - 1] + 2)
.gen_colLLb: call gen_x_ranged      ; gen_x_ranged(r0, r1)
.zzz:        mov r1, r9
             addi r1, data.terrain
.gen_colLT:  stm r0, r1             ; write col[x]
             ;cmpi r9, 32
             ;jnz .zzzB
.zzzA:       ;nop
.zzzB:       addi r9, 2
             jmp .gen_colLL

.gen_colZ:   ret

;--------------------------------------
; gen_x_ranged --
;
;
; Generate 1 random value between r0 and r1, into r0.
;--------------------------------------
gen_x_ranged:  mov r2, r0           ; E.g. RND[X,Y] into ...
               sub r1, r0           ; ... RND[0,Y-X] -> rx, rx + X -> rx 
               sub r0, r0
               stm r1, .gen_x_rHHLL
.gen_x_rnd:    dw 0x0107            ; RND r1, ...
.gen_x_rHHLL:  dw 0x0000            ; ... HHLL
               add r1, r2, r0
               ret

;--------------------------------------
; drw_columns --
;
; Draw terrain, one 2px wide column at a time.
;--------------------------------------
drw_columns:   ldi r1, 254
.drw_colLp0:   mov r0, r1
               addi r0, data.terrain
               ldm r4, r0
               ;cmpi r1, 32
               ;jnz .xyz
.zzzC:         ;nop
.xyz:          mov r2, r4
               shl r4, 8               ; move HH to high byte of word
               ori r4, 0x01            ; low byte of word = 1 for width of 2px
               stm r4, .drw_colsprB    ; store word in HHLL word of SPR instr.
.drw_colsprA:  dw 0x0004               ; spr HHLL, bytes 0-1 [opcode]
.drw_colsprB:  dw 0x0101               ; spr HHLL, bytes 2-3 [LL HH]
               ldi r3, 240
               sub r3, r2
.drw_columnD:  drw r1, r3, data.spr
               subi r1, 2
               jnn .drw_colLp0
.drw_colZ:     ret

;--------------------------------------
; drw_cannons --
;
; Draw cannons, one at column 16 and the other at column 224.
; Cannons are 2x4 rectangle sprites.
;--------------------------------------
drw_cannons:   spr 0x0401              ; cannons are 2x4 pixels
               ldi r0, 32
               mov r1, r0
               addi r1, data.terrain
               ldm r1, r1
.zzzD:         ldi r2, 240
               sub r2, r1, r1
               subi r1, 4
               drw r0, r1, data.spr_cnn ; draw at (x, 240 - col[x] - 4)
               ldi r0, 224
               mov r1, r0
               addi r1, data.terrain
               ldm r1, r1
.zzzE:         ldi r2, 240
               sub r2, r1, r1
               subi r1, 4
               drw r0, r1, data.spr_cnn ; draw at (x, 240 - col[x] - 4)
               ret

;--------------------------------------
; Data declarations
;--------------------------------------
data.p0_ang:   dw 0
data.p1_ang:   dw 0

data.terrain:  dw 0, 0, 0, 0, 0, 0, 0, 0  ; 2B x 8 x 16 rows = 256 B
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0

data.spr:      dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 16
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 32 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 48 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 64 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 80 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 96 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 112
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 128
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 16
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 32 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 48 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 64 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 80 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 96 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 112
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 128
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 16
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 32 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 48 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 64 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 80 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 96 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 112
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 128
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 16
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 32 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 48 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 64 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 80 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 96 
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 112
               dw 0x5555, 0x5555, 0x5555, 0x5555,  ; 128

data.spr_cnn:  db 0xff, 0xff, 0xff, 0xff
