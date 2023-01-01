; Small tribute to game developer Archer Maclean
; Rest In Peace, 2022-12-17

; Should work on PAL and NTSC

; Sprites are taken from the game Dropzone by Archer Maclean
; F#READY, 2022-12-29

screen_height   = 192-8
pm_area         = $4000
star_xpos       = pm_area
star_lum        = pm_area+$200
msl_area        = pm_area+$300
p0_area         = pm_area+$400
p1_area         = pm_area+$500
       
wave_index      = $f0
speed           = $f1
current_p0      = $f2 ; and $f3
current_p1      = $f4 ; and $f5
delay           = $f6
move            = $f7
delay_count     = $f8
timer           = $f9
speed_index     = $fa
shape_x         = $fb
color_index     = $fc
text_time       = $fd
init_delay      = $fe

        org $2000
                    
main
        ldx #0
        stx speed
        stx delay_count
        stx speed_index
        stx shape_x
        stx color_index
        stx text_time
        stx init_delay
        
        jsr movement
        
        lda #200
        sta timer

        lda $d014
        and #%00001110
        cmp #%00001110
        bne is_pal
        
        lda #<display_ntsc
        jmp set_dl
is_pal        
        lda #<display_pal
set_dl
        sta $230
        lda #>display_list
        sta $231

        lda #<dli
        sta $200
        lda #>dli
        sta $201
                
        ldx #0
        stx wave_index
wipe
        lda #0
        sta p0_area+$400,x
        sta p1_area+$500,x        
        lda $d20a
        sta star_xpos,x
        lda $d20a
        and #$0f
        sta star_lum,x
        inx
        bne wipe 

        lda #%00111110  ; enable P/M DMA
        sta $022f       ; SDMCTL

        lda #32+16+1
        sta $26f        ; GPRIOR

        lda #>pm_area
        sta $d407       ; PMBASE

        lda #$0e        ; white
        sta $02c0       ; PCOLR0
        lda #$38
        sta $02c1       ; PCOLR1
        
        lda #$b6
        sta 711

        lda #3          ; P/M both on
        sta $d01d       ; GRACTL        

        ldx #0
fill_msl
        lda #$aa
        sta msl_area,x
        inx
        bne fill_msl

        lda #7          ; sets VVBLKI
        ldy #<vbi
        ldx #>vbi
        jsr $e45c       ; SETVBV

        lda #$c0
        sta $d40e   ; NMIEN
        lda #0
        sta $d20e
        
loop    jmp loop

; X = 0..3
movement
        ldx speed
        lda shape_offsets_p0,x
        sta current_p0
        lda #>sprites
        sta current_p0+1
        
        lda shape_offsets_p1,x
        sta current_p1
        lda #>sprites
        sta current_p1+1
        
        lda delay_table,x
        sta delay
        lda move_table,x
        sta move
        rts
        
; A, X, Y are already saved by the OS
vbi
;        lda #$34
;        sta $d01a
        
        lda #0
        sta 77

        lda init_delay
        cmp #255
        beq init_done
        inc init_delay
        jmp skip_for_init

init_done
        lda shape_x
        cmp #$78
        beq stay_here
        inc shape_x
stay_here
        sta $d000       ; HPOSP0      
        sec
        sbc #3
        sta $d001       ; HPOS01

        dec timer
        bne no_change

; change speed?
        inc speed_index
        ldx speed_index
        cpx #8
        bne no_loop
        ldx #0
        stx speed_index
no_loop
        lda speed_table,x
        sta speed
        lda timer_table,x
        sta timer
        
no_change
        lda speed_index
        cmp #1
        bne text_done
        
        lda text_time
        cmp #128
        bne text_intro
        lda #8
        sta color_index
        bne text_done

text_intro
        inc text_time
        lda text_time
        lsr
        lsr
        lsr
        lsr
        sta color_index

skip_for_init
text_done
        jsr movement

        jsr show_sprites

        inc delay_count
        lda delay_count
        cmp delay
        bcc skip_it
        lda #0
        sta delay_count
        
        ldx #0
move_stars
        lda star_xpos,x
        sec
        sbc move
        sta star_xpos,x

        inx
        cpx #screen_height
        bne move_stars

skip_it   
        inc wave_index
        lda wave_index
        cmp #10*8
        bne no_end
        lda #0
        sta wave_index
no_end

        lda #0
        sta $d01a
        
        jmp $e462     ; XITVBV exit vblank routine

dli
        pha
        txa
        pha
        tya
        pha
        
        ldx #0
stars
        lda star_xpos,x
        sta $d40a
        sta $d004
        lda star_lum,x
        sta $d019
        inx
        cpx #screen_height
        bne stars
        
        lda #0
        sta $d004
        sta $d005
        sta $d006
        sta $d007
        sta $d018
   
        ldy color_index
        ldx #7
do_raster1
        lda colors1,y
        sta $d40a
        sta $d016
        iny
        dex
        bpl do_raster1

        sta $d40a
        sta $d40a

        ldy color_index
        ldx #7
do_raster2
        lda colors2,y
        sta $d40a
        sta $d017
        iny
        dex
        bpl do_raster2
        
        pla
        tay
        pla
        tax
        pla
        rti
        
show_sprites
        ldx wave_index
        lda #100
        clc
        adc wave_data,x
        tax
        clc
        adc #7
        sta sprite2_ypos
        
        ldy #0
show_sprite1
        lda (current_p0),y
;        lda #255
        sta p0_area,x
        inx
        iny
        cpy #22+6
        bne show_sprite1        

sprite2_ypos = *+1
        ldx #0

        ldy #0
show_sprite2
        lda (current_p1),y
        sta p1_area,x
        inx
        iny
        cpy #9+6
        bne show_sprite2
        
        rts
        
        .align $100
display_list
display_pal        
        dta $70,$70
display_ntsc
        dta $70,128
        dta $70,$70,$70,$70
        dta $70,$70,$70,$70
        dta $70,$70,$70,$70
        dta $70,$70,$70,$70        
        dta $70,$70,$70,$70        
        dta $70,$70,$70
        dta $46
        dta a(screen_text)
        dta 16
        dta 2
        dta $41
        dta a(display_list)

screen_text
        dta d'   ARCHER MACLEAN   '
        dta d'             rest in'
        dta d' peace              ' 

colors1
        dta $00,$00,$00,$00
        dta $00,$00,$00,$00
        dta $74,$76,$78,$7a
        dta $ec,$ec,$ee,$ee

colors2
        dta $00,$00,$00,$00
        dta $00,$00,$00,$00
        dta $00,$06,$06,$08
        dta $0a,$0c,$0e,$0e

wave_data
        dta 0,0,2,2,2,2,3,3
        dta 3,3,3,3,3,4,4,4
        dta 4,4,4,4,4,5,5,5
        dta 5,5,6,6,6,6,6,6
        dta 6,6,6,6,6,6,7,7
        dta 7,7,7,7,6,6,6,6
        dta 6,6,5,5,5,5,4,4
        dta 4,4,4,4,4,3,3,3
        dta 3,3,2,2,2,0,0,0
        dta 0,0,0,0,0,0,0,0

delay_table
        dta 3,2,1,1
move_table
        dta 1,1,1,2
speed_table
        dta 0,0,1,2
        dta 3,3,2,1
timer_table
        dta 50,200,20,10
        dta 250,250,20,10

shape_offsets_p0
        dta <sprite1d
        dta <sprite1c
        dta <sprite1b
        dta <sprite1a

shape_offsets_p1
        dta <sprite2a
        dta <sprite2a
        dta <sprite2b
        dta <sprite2c
        
        .align $100
sprites        
; dropzone sprite 1
sprite1a
        .he 00 00 00 18 34 34 34 18 60 70 54 5c 50 4e 58 58 58 5c 6e 36 0c 18 10 10 00 00 00 00
sprite1b
        .he 00 00 00 18 34 34 34 18 60 70 5a 5e 40 5e 58 58 58 5c 6e 36 06 0c 08 0c 04 00 00 00
sprite1c
        .he 00 00 00 18 34 34 34 18 60 70 5a 4f 40 5e 58 58 58 5c 6e 36 02 02 04 06 02 00 00 00
sprite1d
        .he 00 00 00 18 34 34 34 18 60 70 59 4f 50 5e 58 58 58 5c 6e 36 02 02 02 02 03 00 00 00

; dropzone sprite 2
sprite2a
        .he 00 00 00 04 06 07 07 07 07 07 07 02 00 00 00
sprite2b
        .he 00 00 00 04 06 27 67 27 07 07 07 02 00 00 00
sprite2c        
        .he 00 00 00 04 06 67 a7 67 07 07 07 02 00 00 00

        run main