;****************************************************************************************************************************************************
;*	DeltaruneBattle Source File
;*
;****************************************************************************************************************************************************
;*
;*
;****************************************************************************************************************************************************

;****************************************************************************************************************************************************
;*	Includes
;****************************************************************************************************************************************************
	;Program includes
	INCLUDE	"Includes/Hardware.inc"
	INCLUDE "Includes/Subroutines.inc"
	INCLUDE "Includes/Wram.inc"
	
	;Asset includes
	INCLUDE "Assets/Tiles.z80"
	INCLUDE "Assets/BackgroundTileset.z80"
	INCLUDE "Assets/Window.z80"
	INCLUDE "Assets/Background.z80"

;****************************************************************************************************************************************************
;*	Constants
;****************************************************************************************************************************************************
TILE_SIZE EQU 16
PALETTE_SIZE EQU 8

;****************************************************************************************************************************************************
;*	cartridge header
;****************************************************************************************************************************************************

	SECTION	"Org $00",ROM0[$00]
RST_00:	
	jp	$100

	SECTION	"Org $08",ROM0[$08]
RST_08:	
	jp	$100

	SECTION	"Org $10",ROM0[$10]
RST_10:
	jp	$100

	SECTION	"Org $18",ROM0[$18]
RST_18:
	jp	$100

	SECTION	"Org $20",ROM0[$20]
RST_20:
	jp	$100

	SECTION	"Org $28",ROM0[$28]
RST_28:
	jp	$100

	SECTION	"Org $30",ROM0[$30]
RST_30:
	jp	$100

	SECTION	"Org $38",ROM0[$38]
RST_38:
	jp	$100

	SECTION	"V-Blank IRQ Vector",ROM0[$40]
VBL_VECT:
	reti
	
	SECTION	"LCD IRQ Vector",ROM0[$48]
LCD_VECT:
	reti

	SECTION	"Timer IRQ Vector",ROM0[$50]
TIMER_VECT:
	reti

	SECTION	"Serial IRQ Vector",ROM0[$58]
SERIAL_VECT:
	reti

	SECTION	"Joypad IRQ Vector",ROM0[$60]
JOYPAD_VECT:
	reti
	
	SECTION	"Start",ROM0[$100]
	nop
	jp	Start

	; $0104-$0133 (Nintendo logo - do _not_ modify the logo data here or the GB will not run the program)
	DB	$CE,$ED,$66,$66,$CC,$0D,$00,$0B,$03,$73,$00,$83,$00,$0C,$00,$0D
	DB	$00,$08,$11,$1F,$88,$89,$00,$0E,$DC,$CC,$6E,$E6,$DD,$DD,$D9,$99
	DB	$BB,$BB,$67,$63,$6E,$0E,$EC,$CC,$DD,$DC,$99,$9F,$BB,$B9,$33,$3E

	; $0134-$013E (Game title - up to 11 upper case ASCII characters; pad with $00)
	DB	"DELTARUNE",0,0
		;0123456789A

	; $013F-$0142 (Product code - 4 ASCII characters, assigned by Nintendo, just leave blank)
	DB	"    "
		;0123

	; $0143 (Color GameBoy compatibility code)
	DB	$C0	; $00 - DMG 
			; $80 - DMG/GBC
			; $C0 - GBC Only cartridge

	; $0144 (High-nibble of license code - normally $00 if $014B != $33)
	DB	$00

	; $0145 (Low-nibble of license code - normally $00 if $014B != $33)
	DB	$00

	; $0146 (GameBoy/Super GameBoy indicator)
	DB	$00	; $00 - GameBoy

	; $0147 (Cartridge type - all Color GameBoy cartridges are at least $19)
	DB	$19	; $19 - ROM + MBC5

	; $0148 (ROM size)
	DB	$01	; $01 - 512Kbit = 64Kbyte = 4 banks

	; $0149 (RAM size)
	DB	$00	; $00 - None

	; $014A (Destination code)
	DB	$00	; $01 - All others
			; $00 - Japan

	; $014B (Licensee code - this _must_ be $33)
	DB	$33	; $33 - Check $0144/$0145 for Licensee code.

	; $014C (Mask ROM version - handled by RGBFIX)
	DB	$00

	; $014D (Complement check - handled by RGBFIX)
	DB	$00

	; $014E-$014F (Cartridge checksum - handled by RGBFIX)
	DW	$00


;****************************************************************************************************************************************************
;*	Program Start
;****************************************************************************************************************************************************

	SECTION "Program Start",ROM0[$0150]
Start::
	di
	ld sp, $FFFE	;set up stack pointer
	
	xor a
	ldh [rLCDC], a		;turn off the screen
	
	ld de, _RAM
	ld bc, 8192
	ld h, 0
	call Memset		;clear ram
	
	xor a
	ld hl, TilesCGB
	ld b, 2 * PALETTE_SIZE
	call LoadPalettes
	
	ld hl, Tiles
	ld de, _VRAM + TILE_SIZE
	ld bc, TILE_SIZE * 2
	call Memcpy		;Load tiles used for window
	
	ld hl, BackgroundTileset
	ld bc, TILE_SIZE * 1
	call Memcpy		;Load the background tile into slot 3
	
	ld hl, Window
	ld de, _SCRN1
	ld c, 4
	call LoadMap
	
	ld hl, Background
	ld de, _SCRN0
	ld c, 18
	call LoadMap
	
	ld a, WX_OFS
	ld [rWX], a
	
	ld a, 14*8
	ld [rWY], a		;Move window to bottom of screen
	
	ld a, IEF_VBLANK
	ld [rIE], a
	ei
	
	ld a, LCDCF_ON | LCDCF_WINON | LCDCF_WIN9C00 | LCDCF_BG8000 | LCDCF_BG9800 | LCDCF_OBJOFF | LCDCF_BGON
	ld [rLCDC], a
	
Main::
	halt

.scrolling:
	ld a, [scrolling_delay]
	inc a
	ld [scrolling_delay], a
	cp 6					;For 6 frames, don't scroll
	jr nz, Main
	
	xor a
	ld [scrolling_delay], a
	
	ld a, [scrolling_tile_index]
	inc a
	cp 8					;Make sure scrolling_tile_index is in range
	jr nz, .write_back
	xor a
	
.write_back:
	ld [scrolling_tile_index], a
	
	ld hl, BackgroundTileset	;hl = BackgroundTileset + scrolling_tile_index * TILE_SIZE, or hl = BackgroundTileset[scrolling_tile_index]
	ld b, a
	ld e, TILE_SIZE
	call Multiply
	
	ld de, _VRAM + TILE_SIZE * 3
	ld bc, TILE_SIZE * 1
	call Memcpy				;Rewrite current tile
	jr Main

;*** End Of File ***