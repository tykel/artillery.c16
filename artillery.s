;-----------------------------------------------------------------------------
; artillery.s
;
; Clone of Scorched Earth for Chip16.
; Copyright (C) 2023-2024 Tim Kelsall.
;
;-----------------------------------------------------------------------------

importbin font.bin 0 3072 data.font
CHAR_OFFS         equ 32

SCORE_TO_WIN      equ 5

P1_TRAILS         equ 0x3000
P2_TRAILS         equ 0x3200

WIND_PARTS        equ 0x3400
WIND_NUM_PARTS    equ 64

P1_X              equ 32
P2_X              equ 288

DEFAULT_POW       equ 25
DEFAULT_P1_ANG    equ 135
DEFAULT_P2_ANG    equ 45

start:         call hard_reset
               jmp init

;--------------------------------------
; hard_reset --
;
; Reinitialize variables that need must be reset upon transition to/from menu.
;--------------------------------------
hard_reset:    call soft_reset
               ldi r0, 0
               stm r0, data.p1_score
               stm r0, data.p2_score
               ret

;--------------------------------------
; soft_reset --
;
; Reinitialize variables that need reseting between rounds. 
;--------------------------------------
soft_reset:    ldi r0, 0
               stm r0, data.start
               stm r0, data.win
               stm r0, data.cur_plyr
               stm r0, data.swap_plyr
               stm r0, data.msl_stat
               stm r0, data.drw_debris
               stm r0, data.p1_y
               stm r0, data.p2_y
               stm r0, data.p1_trls
               stm r0, data.p2_trls
               ldi r0, DEFAULT_POW
               stm r0, data.cpu_lmsp
               stm r0, data.p1_pow
               stm r0, data.p2_pow
               ldi r0, P1_X
               stm r0, data.p1_x
               stm r0, data.cpu_lmsx
               ldi r0, P2_X
               stm r0, data.p2_x
               ldi r0, DEFAULT_P1_ANG
               stm r0, data.p1_ang
               ldi r0, DEFAULT_P2_ANG
               stm r0, data.p2_ang
               ret

;---------------------------------------
; init / loop --
;
; Main game loop.
;---------------------------------------
init:          pal data.palette
               ;jmp game                        ; Uncomment to skip menu

menu:          cls
               call handle_menu
               call drw_title
               vblnk
               ldm r0, data.f_nb
               addi r0, 1
               stm r0, data.f_nb
               ldm r0, data.start
               cmpi r0, 1
               jnz menu

game:          call gen_columns
               call gen_spr
               ldi r0, 0
               call ld_plyr_cur
               call init_wind
               call init_wp
loop:          cls
               bgc 1
               call handle_plyr
               call handle_cpu
               call handle_inp
               call handle_msl
               call handle_debris
               call handle_wp
               
               call drw_hud
               call drw_columns
               call drw_cannons
               call drw_target
               call drw_msl
               call drw_debris
               call drw_trails
               call drw_wp

               call handle_win
               ldm r0, data.n_vblnk
               call wait
               ldm r0, data.f_nb
               addi r0, 1
               stm r0, data.f_nb
               jmp loop

;--------------------------------------
; wait --
;
; Wait for the number of frames passed in r0.
;--------------------------------------
wait:          vblnk
               subi r0, 1
               jnz wait
               ret

;--------------------------------------
; init_wind --
;
; Choose a random wind speed.
; Negative implies "West", positive "East".
;--------------------------------------
init_wind:     rnd r0, 128          ; [ 0 .. 8] in FP12.4
               subi r0, 64          ; [-4 .. 4] in FP12.4
               stm r0, data.wind_dx
               ret
               
;--------------------------------------
; make_wp --
;
; Generate a random wind particle (x,y,dx,dy) at offset given in r0.
;--------------------------------------
make_wp:       ; 3 cases:
               ; - 0: top edge (x = random(0,320), y = 0)
               ; - 1: left edge (x = 0, y = random(0, 192))
               ; - 2: right edge (x = 319, y = random(0, 192))
               push r2
               rnd r2, 2
.make_wp0:     cmpi r2, 0
               jnz .make_wp1
               rnd r1, 5120         ; 320 in FP12.4
               stm r1, r0           ; i.e. random 0 <= x < 320
               addi r0, 2
               ldi r1, 0
               stm r1, r0           ; i.e. y = 0
               jmp .make_wpD

.make_wp1:     cmpi r2, 1
               jnz .make_wp2
               ldi r1, 0
               stm r1, r0           ; i.e. x = 0
               addi r0, 2
               rnd r1, 3072         ; 192 in FP12.4
               stm r1, r0           ; i.e. random 0 <= y < 192
               jmp .make_wpD

.make_wp2:     ldi r1, 5104         ; 319 in FP12.4
               stm r1, r0           ; i.e. x = 319
               addi r0, 2
               rnd r1, 3072         ; 192 in FP12.4
               stm r1, r0           ; i.e. random y < 64

.make_wpD:     addi r0, 2
               rnd r1, 16           ; 1 in FP12.4
               subi r1, 8
               stm r1, r0           ; i.e random -.5 <= dx < .5
               addi r0, 2
               ldi r1, 10
               stm r1, r0           ; dy = a small number

               pop r2
               ret

;--------------------------------------
; init_wp --
;
; Generate an array of random wind particles.
;--------------------------------------
init_wp:       ldi r2, 0
               ldi r0, WIND_PARTS
.init_wpL:     call make_wp
               addi r2, 1
               cmpi r2, WIND_NUM_PARTS
               jl .init_wpL
.init_wpZ:     ret

;--------------------------------------
; handle_wp --
;
; Update the wind particles in the array.
;--------------------------------------
handle_wp:     ldi r2, 0
               ldi r0, WIND_PARTS
               ; Load particle state
.handle_wpL:   ldm r3, r0              ; x
               addi r0, 2
               ldm r4, r0              ; y
               addi r0, 2
               ldm r5, r0              ; dx
               addi r0, 2
               ldm r6, r0              ; dy
               addi r0, 2
               ldm r7, data.wind_dx    ; wind.dx
               ; Calculate new position
               add r3, r5
               add r3, r7
               rnd r7, 2               ; Use a small random portion
               subi r7, 1
               add r3, r7
               add r4, r6
               ; Save new particle state
               subi r0, 8
               cmpi r3, 5120           ; 320 in FP12.4
               jge .handle_wpN
               cmpi r3, 0
               jg .handle_wpS
.handle_wpN:   call make_wp
               jmp .handle_wpT
.handle_wpS:   stm r3, r0
               addi r0, 2
               stm r4, r0
               addi r0, 2
               stm r5, r0
               addi r0, 2
               stm r6, r0
.handle_wpT:   addi r0, 2
               addi r2, 1
               cmpi r2, WIND_NUM_PARTS
               jl .handle_wpL
.handle_wpZ:   ret

;--------------------------------------
; drw_wp --
;
; Draw the wind particles.
;--------------------------------------
drw_wp:        spr 0x0101
               ldi r0, 0
               ldi r1, WIND_PARTS
.drw_wpL:      ldm r2, r1
               sar r2, 4
               addi r1, 2
               ldm r3, r1
               sar r3, 4
               addi r1, 6
               drw r2, r3, data.spr_wp
               addi r0, 1
               cmpi r0, WIND_NUM_PARTS
               jl .drw_wpL
               ret

;--------------------------------------
; other_plyr_x --
;
; Utility function to get non-current player's x coordinate.
;--------------------------------------
other_plyr_x:  ldm r0, data.cur_plyr
               xori r0, 1
               shl r0, 1
               addi r0, data.p1_x
               ldm r0, r0
               ret

;--------------------------------------
; handle_menu --
;
; Handle input at menu screen.
;--------------------------------------
handle_menu:   ldm r0, 0xfff0
               ldm r1, data.need_rls
               cmpi r1, 1
               jnz .handle_men0
               cmpi r0, 0
               jnz .handle_menZ
               stm r0, data.need_rls
.handle_men0:  tsti r0, 16       ; Select
               jz .handle_menA
               ldm r1, data.cpu_plyr
               xori r1, 1
               stm r1, data.cpu_plyr
               ldi r1, 1
               stm r1, data.need_rls   ; Require button release
               jmp .handle_menZ
.handle_menA:  tsti r0, 32       ; Start
               jz .handle_menB
               ldi r1, 1
               stm r1, data.start
               jmp .handle_menZ
.handle_menB:  tsti r0, 64       ; A
               jz .handle_menZ
               ldm r1, data.n_vblnk
               xori r1, 3
               stm r1, data.n_vblnk
               ldi r1, 1
               stm r1, data.need_rls   ; Require button release
.handle_menZ:  ret

;--------------------------------------
; handle_plyr --
;
; If in "swap players" state, flush the current player state, swap the current
; player index, and cache the new current player state. Leave "swap players"
; state.
;--------------------------------------
handle_plyr:   ; Save current player [ang, x, y] to p1 or p2
               ldm r0, data.cur_plyr
               call st_plyr_cur
               ldm r0, data.swap_plyr
               ; Only proceed further if swap requested
               cmpi r0, 1
               jnz .handle_plZ
               ldi r0, 0
               stm r0, data.swap_plyr
               ; Save current state to last cpu state if applicable
               ldm r0, data.msl_x
               sar r0, 4
               ldm r1, data.cur_plyr
               cmpi r1, 1
               jnz .handle_plyA
               stm r0, data.cpu_lmsx
               ; Swap the current player index
.handle_plyA:  ldm r0, data.cur_plyr
               xori r0, 1
               stm r0, data.cur_plyr
               ; Load new current player [ang, x, y] from p1 or p2
               call ld_plyr_cur
               ldi r0, 60
               stm r0, data.cpu_wait
.handle_plZ:   ret

;--------------------------------------
; ld_plyr_cur --
;
; Load the currently-playing player state to the "current player" state.
; Called immediately after switching the current player index.
;--------------------------------------
ld_plyr_cur:   mov r1, r0
               shl r1, 1
               addi r1, data.p1_ang
               ldm r2, r1
               stm r2, data.cur_ang
               addi r1, 4 ; data.p1_x
               ldm r2, r1
               stm r2, data.cur_x
               addi r1, 4 ; data.p1_y
               ldm r2, r1
               stm r2, data.cur_y
               addi r1, 4 ; data.p1_pow
               ldm r2, r1
               stm r2, data.cur_pow
               ret

;--------------------------------------
; st_plyr_cur --
;
; Store "current player" state to the currently-playing player state.
; This will be called to flush state before switching the current player.
;--------------------------------------
st_plyr_cur:   mov r1, r0
               shl r1, 1
               addi r1, data.p1_ang
               ldm r2, data.cur_ang
               stm r2, r1
               addi r1, 4 ; data.p1_x
               ldm r2, data.cur_x
               stm r2, r1
               addi r1, 4 ; data.p1_y
               ldm r2, data.cur_y
               stm r2, r1
               addi r1, 4 ; data.p1_pow
               ldm r2, data.cur_pow
               stm r2, r1
               ret

;--------------------------------------
; handle_cpu --
;
; Play for the computer ("CPU") player.
; Strategy is as follows:
; - Delay for 1 second as turn begins.
; - Record last: missile hit X, power.
; - Check whether missile overshot (msl.x < p1.x), or undershot (msl.x > p1.x).
; - If missile overshot, decrease power.
; - If missile undershot, increase power.
; - Then fire missile.
;--------------------------------------
handle_cpu:    ldm r0, data.cpu_plyr
               cmpi r0, 1
               jnz .handle_cpZ
               ldm r0, data.cur_plyr
               cmpi r0, 1
               jnz .handle_cpZ
               ldm r0, data.msl_stat
               cmpi r0, 0
               jnz .handle_cpZ
               ldm r0, data.cpu_wait
               subi r0, 1
               stm r0, data.cpu_wait
               jnn .handle_cpZ
       
.hc_load:      ldi r3, 3
               ldm r1, data.cpu_lmsp
               ldm r0, data.cpu_lmsx
               subi r0, P1_X
               jge .hc_dec

.hc_inc:       cmpi r0, -32
               jl .hc_inc1
               shr r3, 1
.hc_inc1:      sub r1, r3              ; Missile undershot -> decrease power
               stm r1, data.cur_pow
               jmp .handle_cpF

.hc_dec:       cmpi r0, 32
               jge .hc_dec1
               shr r3, 1
.hc_dec1:      add r1, r3              ; Missile overshot -> increase power
               stm r1, data.cur_pow

.handle_cpF:   ldi r0, 1
               stm r0, data.msl_stat   ; Fire!
               ldm r0, data.cur_pow
               stm r0, data.cpu_lmsp
.handle_cpZ:   ret

;--------------------------------------
; handle_win --
;
; Perform screen flashes over 2.5 seconds if we are in a "win" state, then
; reset.
;--------------------------------------
handle_win:    ldm r0, data.win
               cmpi r0, 1
               jnz .handle_wiZ
               ldi r0, 0
               stm r0, data.win
               bgc 9
               ldi r0, 30
               call wait
               bgc 1
               ldi r0, 30
               call wait
               bgc 9
               ldi r0, 90
               call wait
.sp_reset:     ldi sp, 0xfdf0       ; Reset stack pointer as we restart
               ldm r0, data.p1_score
               cmpi r0, SCORE_TO_WIN
               jz .handle_wiR       ; Equivalent to soft-reset
               ldm r0, data.p2_score
               cmpi r0, SCORE_TO_WIN
               jz .handle_wiR       ; Ditto
               pop r0
               call soft_reset
               jmp game             ; Start a new round
.handle_wiR:   cls
               ldi r0, data.str_win
               ldi r1, 96
               ldi r2, 120
               call drw_str
               ldm r0, data.cur_plyr
               addi r0, 1
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 152
               ldi r2, 120
               call drw_str
               ldi r0, data.str_win2
               ldi r1, 184
               ldi r2, 120
               call drw_str
               ldi r0, 120
               call wait
bp:            pop r0
               jmp start
.handle_wiZ:   ret
               

;--------------------------------------
; handle_inp --
;
; Update angle, and missile fire status, from controller input.
;--------------------------------------
handle_inp:    ldm r0, 0xfff0
               ldm r1, data.need_rls
               cmpi r1, 0
               jz .handle_in0
               cmpi r0, 0
               jnz .handle_inZ
               stm r0, data.need_rls
.handle_in0:   ldm r1, data.cpu_plyr ; If mode is "vs. CPU", and p2's turn...
               cmpi r1, 0            ; ... then only check for reset
               jz .handle_inU
               ldm r1, data.cur_plyr
               cmpi r1, 1
               jz .handle_inE
.handle_inU:   tsti r0, 1           ; Up button
               jz .handle_inA
               ldm r1, data.cur_pow
               cmpi r1, 100
               jz .handle_inZ
               addi r1, 1
               stm r1, data.cur_pow ; Up -> increment power, ceiling to 100
               jmp .handle_inZ
.handle_inA:   tsti r0, 2           ; Down button
               jz .handle_inB
               ldm r1, data.cur_pow
               cmpi r1, 1
               jz .handle_inZ
               subi r1, 1
               stm r1, data.cur_pow ; Down -> decrement angle, floored to 1
               jmp .handle_inZ
.handle_inB:   tsti r0, 4           ; Left button
               jz .handle_inC
               ldm r1, data.cur_ang
               cmpi r1, 0
               jz .handle_inZ
               subi r1, 1
               stm r1, data.cur_ang ; Left -> decrement angle, floored to 0
               jmp .handle_inZ
.handle_inC:   tsti r0, 8           ; Right button
               jz .handle_inD
               ldm r1, data.cur_ang
               cmpi r1, 179
               jz .handle_inZ
               addi r1, 1
               stm r1, data.cur_ang ; Right -> increment angle, ceiling to 179
               jmp .handle_inZ
.handle_inD:   tsti r0, 64          ; "A" button
               jz .handle_inE
               ldm r1, data.msl_stat
               cmpi r1, 0
               jnz .handle_inZ
               addi r1, 1
               stm r1, data.msl_stat ; A -> if missile status was ready, change to fire
               stm r1, data.need_rls
               jmp .handle_inZ
.handle_inE:   tsti r0, 16          ; Select button
               jz .handle_inF
               pop r0
               jmp start            ; Select -> reset the game
.handle_inF:   tsti r0, 32          ; Start button
               jz .handle_inZ
               ldi r1, 1
               stm r1, data.need_rls   ; Require button release
.handle_inZ:   ret

;--------------------------------------
; handle_msl --
;
; If missile status changed to fire, launch missile.
; If missile status is launched, update its velocity and
; position until its height dips at/below current column height.
;
; msl_stat: 0 = missile_ready, 1 == missile_fire, 2 == missile_launched
;--------------------------------------
handle_msl:    ldm r0, data.msl_stat

               ; Fire missile
               ;-------------
               cmpi r0, 1              ; 1 == fire the missile
               jnz .handle_msA
               ldi r0, 2
               stm r0, data.msl_stat   ; 2 == missile launched
               ;bgc 0x2                 ; background flashes gray 
               sng 0x02, 0xc3a1
               ldi r0, 1000
               snp r0, 100             ; play firing noise
               ;;; Load player cannon x, y
               ldm r0, data.cur_x
               shl r0, 4
               stm r0, data.msl_x      ; FP12.4
               ldm r0, data.cur_y
               shl r0, 4               ; FP12.4
               stm r0, data.msl_y
               ;;; Compute initial dx, dy from angle and power
               ldm r2, data.cur_ang
               shl r2, 2               ; angle -> word pair (2*2B) array offset
               addi r2, data.lut_sincos
               mov r3, r2
               ldm r2, r2
               sar r2, 1
               addi r3, 2
               ldm r3, r3
               ;;; Scale dx, dy by power ratio. Divide first to avoid overflow
               ldm r4, data.cur_pow
               divi r2, 50
               mul r2, r4
               divi r3, 50
               mul r3, r4
               stm r2, data.msl_dx     ; stored in FP8.8 format
               stm r3, data.msl_dy     ; stored in FP8.8 format
               ;;; Reset the trail counter for current player
               ldi r0, 0
               ldm r1, data.cur_plyr
               shl r1, 1
               addi r1, data.p1_trls
               stm r0, r1

               ldi r0, 2
               ; Update missile, launched
               ;-------------------------
.handle_msA:   cmpi r0, 2
               jnz .handle_msZ
               ldm r0, data.msl_x
               sar r0, 4
               cmpi r0, 0
               jge .handle_msB
               ldi r0, 0
               stm r0, data.msl_stat
               ldi r0, 1
               stm r0, data.swap_plyr
               jmp .handle_msZ
.handle_msB:   cmpi r0, 320
               jl .handle_msC
               ldi r0, 0
               stm r0, data.msl_stat
               ldi r0, 1
               stm r0, data.swap_plyr
               jmp .handle_msZ
.handle_msC:   ldi r0, 0               ; 32 steps to more accurately find hit
               ldm r1, data.msl_dx
               sar r1, 9               ; dx/16 in FP12.4, so shift.r (4+4)
               ldm r2, data.msl_dy
               sar r2, 9               ; dy/16 in FP12.4, so shift.r (4+4)
               ldm r3, data.msl_x
               ldm r4, data.msl_y
.handle_msCL:  cmpi r0, 32
               jz .handle_msD
               addi r0, 1
               add r3, r1
               add r4, r2
               ;;; Check for collision with terrain
.handle_msX:   mov r5, r4
               sar r5, 4            ; y
               ldm r6, data.msl_x
               sar r6, 4
               andi r6, 0xfffe      ; 2px/col, 2B/col -> clear LSB
               addi r6, data.terrain
               ldm r8, r6
               ldi r7, 240
               sub r7, r8
               cmp r5, r7           ; data.msl_y > (240 - col[data.msl_x]) ?
               jl .handle_msCL
.handle_msXS:  call other_plyr_x
               ldm r9, data.msl_x
               sar r9, 4
               sub r9, r0, r0
               cmpi r0, -4
               jl .handle_msXT
               cmpi r0, 4
               jge .handle_msXT
               ldm ra, data.cur_plyr   ; increase current player's...
               shl ra, 1               ; ... score count
               addi ra, data.p1_score
               ldm r9, ra
               addi r9, 1
               stm r9, ra
               ldi ra, 1
               stm ra, data.win
.handle_msXT:  subi r8, 3
               stm r8, r6           ; blow top 3px off column
               addi r6, 2
               ldm r9, r6
               cmp r8, r9
               jge .handle_mR
               stm r8, r6           ; blow top 1px off right neighbor column
.handle_mR:    subi r6, 4
               ldm r9, r6
               cmp r8, r9
               jge .handle_mDeb
               stm r8, r6           ; blow top 1px off left neighbor column
.handle_mDeb:  call init_debris     ; create some impact particles
               bgc 0x7              ; background flashes orange
               sng 0x04, 0xf3c6
               ldi r0, 500
               snp r0, 300          ; play impact noise
               call drw_flash
               vblnk
               vblnk
               vblnk
               ldi r0, 0
               stm r0, data.msl_stat ; reset missile status
               ldi r0, 1
               stm r0, data.swap_plyr
               jmp .handle_msZ
.handle_msD:   stm r3, data.msl_x
               stm r4, data.msl_y
               ;;; Store missile position as next trail dot
               sar r3, 4
               sar r4, 4
               ldm r5, data.cur_plyr
               mov r8, r5
               shl r5, 1
               addi r5, data.p1_trls
               ldm r6, r5           ; pN_trails
               mov r7, r6
               shl r7, 2
               shl r8, 9            ; (p1) 0 -> 0, (p2) 1 -> 0x200
               addi r8, P1_TRAILS   ; (p1) 0 -> 0x3000, (p2) 1 -> 0x3200
               add r7, r8           ; offset into trails array (2x2B per entry)
               stm r3, r7           ; pN_trail[i].x
               addi r7, 2
               stm r4, r7           ; pN_trail[i].y
               addi r6, 1
               stm r6, r5           ; pN_trails++
               ;;; Update dy to account for gravity
               ldm r1, data.msl_dy
               cmpi r1, 2000        ; 6 in FP8.8
               jge .handle_msE
               addi r1, 150         ; FP8.8 representation i.e. 1.13 or so
               stm r1, data.msl_dy
               ;;; Update dx to account for wind
.handle_msE:   ldm r1, data.msl_dx
               ldm r2, data.wind_dx
               add r1, r2
               stm r1, data.msl_dx
.handle_msZ:   ret

;--------------------------------------
; init_debris --
;
; Initialize a debris array and switch to "draw debris" state.
;--------------------------------------
init_debris:   ldi r1, 0
               ldi r3, data.debris
.init_debriL:  cmpi r1, 7
               jz .init_debriZ
               ldm r0, data.msl_dx
               sar r0, 4
               divi r0, 75
               stm r0, r3
               addi r3, 2           ; debris[i].dx = msl.dx / 75
               rnd r2, 5
               subi r2, 3
               ldm r0, data.msl_x
               sar r0, 4
               add r2, r0
               stm r2, r3           ; debris[i].x = rand(-3, 2) + msl.x
               addi r3, 2
               rnd r2, 512
               subi r2, 1024
               stm r2, r3           ; debris[i].dy = rand(-4, -2) IN FP8.8
               addi r3, 2
               ldm r0, data.msl_y
               sar r0, 4
               stm r0, r3           ; debris[i].y = msl.y
               addi r3, 2
               addi r1, 1
               jmp .init_debriL
.init_debriZ:  ldi r0, 1
               stm r0, data.drw_debris
               ret

;--------------------------------------
; handle_debris --
;
; Update the debris' position and velocity, if in a "draw debris" state.
;--------------------------------------
handle_debris: ldm r0, data.drw_debris
               cmpi r0, 1
               jnz .handle_debrZ
               ldi r0, 0
               ldi r1, data.debris
.handle_debrL: cmpi r0, 7
               jz .handle_debrZ
               ldm r2, r1
               addi r1, 2
               ldm r3, r1
               add r3, r2
               stm r3, r1
               addi r1, 2
               ldm r2, r1
               addi r1, 2
               ldm r3, r1
               mov r4, r2
               sar r4, 8
               add r3, r4
               stm r3, r1
               subi r1, 2
               cmpi r4, 5
               jz .handle_debrA
               addi r2, 32
               stm r2, r1
.handle_debrA: addi r1, 4
               addi r0, 1
               jmp .handle_debrL
.handle_debrZ: ret

;--------------------------------------
; drw_debris --
;
; Draw the 8 debris particles, if we are in a "draw debris" state.
;--------------------------------------
drw_debris:    ldm r0, data.drw_debris
               cmpi r0, 1
               jnz .drw_debrZ
               ldi r0, 0
               ldi r1, data.debris
.drw_debrL:    cmpi r0, 7
               jz .drw_debrZ
               addi r1, 2
               ldm r2, r1
               addi r1, 4
               ldm r3, r1
               spr 0x0101
               tsti r0, 2
               jz .drw_debrD
               spr 0x0301
.drw_debrD:    drw r2, r3, data.spr
               addi r1, 2
               addi r0, 1
               jmp .drw_debrL
.drw_debrZ:    ret

;--------------------------------------
; gen_spr --
;
; Generate a random terrain column sprite.
;--------------------------------------
gen_spr:       ldi r3, data.spr
               ldi r0, 0
.gen_sprL:     cmpi r0, 256
               jz .gen_sprZ
               rnd r1, 255
               cmpi r1, 160
               jl .gen_spr1
               ldi r2, 0x4465
               jmp .gen_sprY
.gen_spr1:     cmpi r1, 100
               jl .gen_spr2
               ldi r2, 0x6476
               jmp .gen_sprY
.gen_spr2:     cmpi r1, 64
               jl .gen_spr3
               ldi r2, 0x7645
               jmp .gen_sprY
.gen_spr3:     ldi r2, 0x6576
.gen_sprY:     stm r2, r3
               addi r3, 4
               addi r0, 4
               jmp .gen_sprL
.gen_sprZ:     ret

;--------------------------------------
; gen_columns --
;
; Generate terrain, settling with 160 2px columns.
; - First column randomly selected within a middle interval
; - Select each subsequent column as a function of the previous one.
;
;--------------------------------------
gen_columns:
             ; Generate column 0
             ldi r0, 16             ; col[0] height in [16..64]
             ldi r1, 64
             call gen_x_ranged
             ldi r8, data.terrain
.gen_col0:   stm r0, r8

             ; Generate next columns iteratively
.gen_colLL0: ldi r9, 2              ; for (x = 2;
.gen_colLL:  cmpi r9, 320           ;      x < 320;
             jz .gen_colZ           ;      x+=2) {

; col[x] = gen_x_ranged(max(1, col[x - 1] - 2), min(col[x - 1] + 3, 239));
;
; col[x] here stored as a dword array, but addresses are byte-level, hence cast
; to (u8*) with offset
             add r9, r8, r7         ; (u8*)col + x
             subi r7, 2             ; (u8*)col + x - 2
             ldm r7, r7             ; *((u8*)col + x - 2)
             mov r0, r7
             subi r0, 3
             cmpi r0, 1
             jge .gen_colLLa
             ldi r0, 1              ; r0 = max(1, col[x - 1] - 2)
.gen_colLLa: mov r1, r7
             addi r1, 3
             cmpi r1, 239
             jle .gen_colLLb
             ldi r1, 239            ; r1 = min(239, col[x - 1] + 2)
.gen_colLLb: call gen_x_ranged      ; gen_x_ranged(r0, r1)
             mov r1, r9
             addi r1, data.terrain
.gen_colLT:  stm r0, r1             ; write col[x]
             cmpi r9, P1_X
             jnz .zzzB
             ldi r2, 240
             sub r2, r0, r0
             stm r0, data.p1_y      ; store p1.y
.zzzB:       cmpi r9, P2_X
             jnz .zzzC
             ldi r2, 240
             sub r2, r0, r0
             stm r0, data.p2_y      ; store p2.y
.zzzC:       addi r9, 2
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
drw_columns:   ldi r1, 318
.drw_colLp0:   mov r0, r1
               addi r0, data.terrain
               ldm r4, r0
               mov r2, r4
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
; Draw cannons, one at column 16 and the other at column 112.
; Cannons are 2x4 rectangle sprites.
;--------------------------------------
drw_cannons:   spr 0x0401              ; cannons are 2x4 pixels
               ldm r0, data.p1_x
               ldm r1, data.p1_y
               subi r1, 4
               drw r0, r1, data.spr_cnn ; draw at (x, 240 - col[x] - 4)
               ldm r0, data.p2_x
               ldm r1, data.p2_y
               subi r1, 4
               drw r0, r1, data.spr_cnn ; draw at (x, 240 - col[x] - 4)
               ret

;--------------------------------------
; drw_target --
;
; Draw the visual target used to aim the cannon.
; Use a lookup table to map angle to x/y offsets.
;--------------------------------------
drw_target:    spr 0x0402              ; target is 4x4 pixels
               ldm r0, data.cur_ang
               shl r0, 2               ; angle -> word pair (2*2B) array offset
               mov r1, r0
               addi r1, data.lut_sincos
               mov r2, r1
               addi r2, 2
               ldm r1, r1
               sar r1, 8
               ldm r3, data.cur_x
               add r1, r3
               ldm r2, r2
               sar r2, 4
               ldm r3, data.cur_y
               shl r3, 4
               add r2, r3
               sar r2, 4
               subi r1, 2
               subi r2, 10             ; center the sprite
               drw r1, r2, data.spr_tgt
               ret

;--------------------------------------
; drw_msl --
;
; Draw the missile that the cannon launched.
;--------------------------------------
drw_msl:       ldm r0, data.msl_stat
               cmpi r0, 0
               jz .drw_msZ
               spr 0x0101
               ldm r0, data.msl_x
               sar r0, 4
               ldm r1, data.msl_y
               sar r1, 4
               drw r0, r1, data.spr_msl
.drw_msZ:      ret

;--------------------------------------
; drw_trails --
;--------------------------------------
drw_trails:    spr 0x0101
               ; Player 1 trails
               ldm r0, data.p1_trls
               ldi r1, P1_TRAILS
.drw_trailL1:  cmpi r0, 0
               jz .drw_trailP2
               ldm r3, r1
               addi r1, 2
               ldm r4, r1
               addi r1, 2
               drw r3, r4, data.spr_msl
               subi r0, 1
               jmp .drw_trailL1
               ; Player 2 trails
.drw_trailP2:  ldm r0, data.p2_trls
               ldi r1, P2_TRAILS
.drw_trailL2:  cmpi r0, 0
               jz .drw_trailZ
               ldm r3, r1
               addi r1, 2
               ldm r4, r1
               addi r1, 2
               drw r3, r4, data.spr_msl
               subi r0, 1
               jmp .drw_trailL2
.drw_trailZ:   ret

;--------------------------------------
; drw_title --
;
; Draw the title/menu screen.
;--------------------------------------
drw_title:     ; Draw Title text
               ldi r0, data.str_title
               ldi r1, 72
               ldi r2, 40
               call drw_str

               ; Draw Start game text
               ldm r0, data.f_nb
               tsti r0, 32
               jz .drw_titl0
               ldi r0, data.str_start
               ldi r1, 64
               ldi r2, 96
               call drw_str

               ; Draw Game mode text
.drw_titl0:    ldi r0, data.str_gmode
               ldi r1, 64
               ldi r2, 144
               call drw_str
               ldi r0, data.str_p1vp2
               ldm r1, data.cpu_plyr
               cmpi r1, 1
               jnz .drw_titlA
               ldi r0, data.str_p1vcp
.drw_titlA:    ldi r1, 160
               ldi r2, 144
               call drw_str
               ldi r0, data.str_togSel
               ldi r1, 64
               ldi r2, 156
               call drw_str
               
               ; Draw game speed text
               ldi r0, data.str_gspd
               ldi r1, 64
               ldi r2, 184
               call drw_str
               ldi r0, data.str_normal
               ldm r1, data.n_vblnk
               cmpi r1, 2
               jz .drw_titlB
               ldi r0, data.str_fast
.drw_titlB:    ldi r1, 160
               ldi r2, 184
               call drw_str
               ldi r0, data.str_togA
               ldi r1, 64
               ldi r2, 196
               call drw_str

               ; Draw copyright text
               ldi r0, data.str_copyr
               ldi r1, 16
               ldi r2, 224
               call drw_str
               
               ret

;--------------------------------------
; drw_flash --
;
; Draw a bright "flash" column if a hit occurred.
;--------------------------------------
drw_flash:      spr 0xf002                  ; 4 x 240
                ldm r0, data.msl_x
                shr r0, 4
                ldi r1, 0
                drw r0, r1, data.spr_fls
                ret

;--------------------------------------
; drw_hud --
;
; Display the user interface sprites.
;--------------------------------------
drw_hud:       ; Draw "Wind:"
               ldi r0, data.str_wind
               ldi r1, 128
               ldi r2, 16
               call drw_str
               ; Draw wind value below
               ldi r3, data.str_e
               ldm r0, data.wind_dx
               cmpi r0, 0
               jge .drw_huA
               ldi r3, data.str_w
               neg r0
.drw_huA:      ;sar r0, 4
               push r3
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 128
               ldi r2, 28
               call drw_str
               pop r0
               ldi r1, 154
               ldi r2, 28
               call drw_str
               ldi r0, data.str_wind2
               ldi r1, 170
               ldi r2, 28
               call drw_str

               ; Draw "Angle:"
               ldi r0, data.str_angle
               ldi r1, 16
               ldi r2, 16
               call drw_str
               ; Draw angle value below
               ldm r0, data.p1_ang
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 16
               ldi r2, 28
               call drw_str
               ldi r0, data.str_angle2
               ldi r1, 48
               ldi r2, 28
               call drw_str
               
               ; Draw "Power:"
               ldi r0, data.str_power
               ldi r1, 16
               ldi r2, 48
               call drw_str
               ; Draw power value below
               ldm r0, data.p1_pow
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 16
               ldi r2, 60
               call drw_str
               ldi r0, data.str_power2
               ldi r1, 48
               ldi r2, 60
               call drw_str

               ; Draw "Score:"
               ldi r0, data.str_score
               ldi r1, 16
               ldi r2, 80
               call drw_str
               ; Draw P1 score value below
               ldm r0, data.p1_score
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 16
               ldi r2, 92
               call drw_str
               ldi r0, data.str_score2
               ldi r1, 48
               ldi r2, 92
               call drw_str

               ; Draw "Angle:"
               ldi r0, data.str_angle
               ldi r1, 256
               ldi r2, 16
               call drw_str
               ; Draw angle value below
               ldm r0, data.p2_ang
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 256
               ldi r2, 28
               call drw_str
               ldi r0, data.str_angle2
               ldi r1, 288
               ldi r2, 28
               call drw_str
               
               ; Draw "Power:"
               ldi r0, data.str_power
               ldi r1, 256
               ldi r2, 48
               call drw_str
               ; Draw power value below
               ldm r0, data.p2_pow
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 256
               ldi r2, 60
               call drw_str
               ldi r0, data.str_power2
               ldi r1, 288
               ldi r2, 60
               call drw_str

               ; Draw "Score:"
               ldi r0, data.str_score
               ldi r1, 256
               ldi r2, 80
               call drw_str
               ; Draw P2 score value below
               ldm r0, data.p2_score
               ldi r1, data.str_bcd3
               call tobcd3
               ldi r0, data.str_bcd3
               ldi r1, 256
               ldi r2, 92
               call drw_str
               ldi r0, data.str_score2
               ldi r1, 288
               ldi r2, 92
               call drw_str

               ret

;-------------------------------------
; tobcd3 --
;
; Output the contents of r0 to given BCD string - up to 999 supported.
;-------------------------------------
tobcd3:        mov r2, r0
               divi r2, 100
               muli r2, 100               ; r2 contains the 100's digit, x100
               mov r3, r0
               sub r3, r2
               divi r3, 10
               muli r3, 10                ; r3 contains the 10's digit, x10
               mov r4, r3
               divi r4, 10
               cmpi r3, 0
               jnz .tobcd3A
               cmpi r2, 0
               jz .tobcd3B
.tobcd3A:      addi r4, 0x10
.tobcd3B:      addi r4, CHAR_OFFS
               shl r4, 8
               mov r5, r2
               divi r5, 100
               cmpi r2, 0
               jz .tobcd3C
               addi r5, 0x10
.tobcd3C:      add r4, r5
               addi r4, CHAR_OFFS         ; Shift and combine 100's & 10's
               stm r4, r1                 ; Store to string's first 2 bytes
               addi r1, 2
               sub r0, r2                 ; Subtract 100's from original
               sub r0, r3                 ; Then subtract 10's
               addi r0, 0x10
               addi r0, CHAR_OFFS
               stm r0, r1                 ; Store to string's last 2 bytes
               ret

;--------------------------------------
; drw_str --
;
; Display a string.
;--------------------------------------
drw_str:       spr 0x0804                 ; Font sprite size is 8x8
               ldm r3, r0
               andi r3, 0xff
               cmpi r3, 0
               jz .drw_strZ
               cmpi r1, 320
               jl .drw_strA
               ldi r1, 0
               addi r2, 12
.drw_strA:     subi r3, CHAR_OFFS
               muli r3, 32
               addi r3, data.font
               drw r1, r2, r3
               addi r0, 1
               addi r1, 8
               jmp drw_str
.drw_strZ:     ret

;--------------------------------------
; Data declarations
;--------------------------------------
data.start:    dw 0
data.need_rls: dw 0
data.swap_plyr: dw 0
data.win:      dw 0
data.cur_plyr: dw 0
data.cur_ang:  dw 0
data.cur_x:    dw 0
data.cur_y:    dw 0
data.cur_pow:  dw 0
data.p1_ang:   dw 135
data.p2_ang:   dw 45
data.p1_x:     dw P1_X
data.p2_x:     dw P2_X
data.p1_y:     dw 0
data.p2_y:     dw 0
data.p1_pow:   dw DEFAULT_POW
data.p2_pow:   dw DEFAULT_POW
data.p1_trls:  dw 0
data.p2_trls:  dw 0
data.msl_stat: dw 0
data.msl_x:    dw 0  ; FP12.4
data.msl_y:    dw 0  ; FP12.4
data.msl_dx:   dw 0  ; FP12.4
data.msl_dy:   dw 0  ; FP12.4
data.wind_dx:  dw 0  ; FP8.8

data.p1_score:  dw 0
data.p2_score:  dw 0

data.n_vblnk:  dw 2
data.f_nb:     dw 0

data.cpu_plyr: dw 0
data.cpu_wait: dw 0
data.cpu_lmsx: dw 0  ; Last impact msl.x fired by CPU
data.cpu_lmsp: dw 0  ; Last power fired by CPU

data.drw_debris: dw 0
data.debris:   dw 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 ; FP8.8

data.str_score: db "Score:"
                db 0
data.str_score2: db "/ 5"
                 db 0

data.str_angle: db "Angle:"
                db 0
data.str_angle2: db "deg"
                 db 0
data.str_power: db "Power:"
                db 0
data.str_power2: db "%"
                 db 0
data.str_wind: db "Wind:"
               db 0
data.str_wind2: db " / 64"
                db 0
data.str_w:    db " W"
               db 0
data.str_e:    db " E"
               db 0
data.str_title: db "C___A___N___N___O___N"
                db 0
data.str_p1vp2: db "vs. Player 2"
                db 0
data.str_p1vcp: db "vs. CPU"
                db 0
data.str_copyr: db "Copyright (C) 2023-2024 Tim Kelsall."
                db 0
data.str_gmode: db "Game mode:"
                db 0
data.str_gspd: db "Game speed:"
               db 0
data.str_normal: db "NORMAL"
                 db 0
data.str_fast: db "FAST"
               db 0
data.str_togA: db "[Press A to toggle]"
               db 0
data.str_togSel: db "[Press SELECT to toggle]"
                 db 0
data.str_start: db "Press START to begin game"
                db 0
data.str_win: db "Player "
              db 0
data.str_win2: db "wins!"
               db 0
data.str_bcd3: db 0,0,0,0

data.palette:  db 0,0,0
               db 0,0,0
               db 0x7a,0x51,0x1f ;30% 		 #7a511f
               db 0x65,0x44,0x1a ;25% 		 #65441a
               db 0x51,0x36,0x15 ;20% 		 #513615
               db 0x3d,0x29,0x10 ;15% 		 #3d2910
               db 0x29,0x1b,0x0a ;10% 		 #291b0a
               db 0x14,0x0e,0x05 ;5% 		 #140e05
               db 0xea,0xd9,0x79
               db 0x53,0x7a,0x3b
               db 0xab,0xd5,0x4a
               db 0x25,0x2e,0x38
               db 0x00,0x46,0x7f
               db 0x68,0xab,0xcc
               db 0xbc,0xde,0xe4
               db 0xff,0xff,0xff

data.terrain:  dw 0, 0, 0, 0, 0, 0, 0, 0  ; 2B x 8 x 20 rows = 320 B
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
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0
               dw 0, 0, 0, 0, 0, 0, 0, 0

data.spr_fls:  dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 4
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 8
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 12 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 16 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 20 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 24 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 28
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 32
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 36
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 40 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 44 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 48 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 52 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 56 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 60
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 64
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 68
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 72 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 76 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 80 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 84 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 88 
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 92
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 96
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 100
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 104
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 108
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 112
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 116
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 120
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 124
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 128
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 132
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 136
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 140
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 144
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 148
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 152
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 156
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 160
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 164
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 168
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 172
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 176
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 180
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 184
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 188
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 192
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 196
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 200
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 204
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 208
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 212
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 216
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 220
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 224
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 228
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 232
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 236
               dw 0x8888, 0x8888, 0x8888, 0x8888,  ; 240

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

data.spr_msl:  db 0x80
data.spr_wp:   db 0x50

data.spr_cnn:  db 0xff, 0xff, 0xff, 0xff

data.spr_tgt:  db 0xcc, 0xcc 0xc0, 0x0c, 0xc0, 0x0c, 0xcc, 0xcc

; FP8.8 LUT of R * sin and R * cos for angles [0..180] degrees
include lut.s
