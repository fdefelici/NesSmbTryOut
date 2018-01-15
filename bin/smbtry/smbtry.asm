                                ; #####################################################
                                ; ############ Impostazione HEADER iNES ###############
                                ; #####################################################
                                ; Header costituito da 16 byte di istruzioni di inizializzazione
                                ; The format of the header is as follows:
                                ;    BYTE  DESCRIPTION
                                ;    0-3   Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
                                ;      4   Size of PRG ROM in 16 KB units
                                ;      5   Size of CHR ROM in 8 KB units (Value 0 means the board uses CHR RAM)
                                ;      6   Flags 6
                                ;      7   Flags 7
                                ;      8   Size of PRG RAM in 8 KB units (Value 0 infers 8 KB for compatibility; see PRG RAM circuit)
                                ;      9   Flags 9
                                ;     10   Flags 10 (unofficial)
                                ;  11-15   Zero filled
                                ; #####################################################
      4E 45 53 1A               .db $4E,$45,$53,$1A         ; "NES\n"
      02                        .db 2                       ; PRG Settato a 2 poichè il programma e' grosso 32784 byte (32K). Ogni PRG rappresenta un blocco di 16KB di memoria.
      01                        .db 1                       ; Imposto CHR a 1 poichè includo 1 chr alla fine del programma
      00 00 00 00 00 00 00 00.. .dsb 10, 0                  ; Genera 10 byte con valore 0 (invece di scrivere 10 volte .db 0), per popolare il resto dell'header che per questo programma non uso
                                ; #####################################################
                                
                                
                                ; #####################################################
                                ; ############ VARIABILI                ###############
                                ; #####################################################
                                ; Le variabili non occupano aree di memoria. Pertanto guardando il file .asm, 
                                ; nella colonna a sinistra l'indirizzo di memoria non aumenta
                                ; #####################################################
                                PPU_CTRL_REG1           = $2000    ; Registro per abilitare/disablitare NMI
                                PPU_CTRL_REG2           = $2001    ; Registro per abilitare/disabilitare il rendering di Sprite e Background
                                PPU_STATUS_REG          = $2002
                                PPU_SCROLL_REG          = $2005
                                PPU_ADDRESS_REG         = $2006
                                PPU_DATA_REG            = $2007
                                
                                PPU_SPRITE_ADDR_REG     = $2003    ; Registri per abilitare il trasferimento DMA degli Sprite
                                DMA_SPRITE_COPY_REG     = $4014    ; dalla Cartuccia alla PPU con una sola istruzione
                                
                                JOYPAD_STATUS           = $4016    ; La porta per resettare lo stato dei 2 joypad
                                JOYPAD_PORT1            = $4016    ; coincide con la porta da cui leggere gli input dal Joypad1 (Il Joypad2 si legge alla $4017. Non usato in questo programmma)
                                
                                ; Canali PPU che puntano al primo SPRITE. Ogni Sprite occupa 4 Canali.
                                ; La PPU può gestire canali da  $0200-02FF (256 = 4canali x 64sprite)
                                ; Gli altri canali (per le 8 sprite di Mario) sono calcolati come offset da questo.
                                Sprite_Channel_YPos     = $0200    ; Canale PPU per imputare la posizione Y dello sprite
                                Sprite_Channel_TileNum  = $0201    ; Canale PPU per imputare il tile da visualizzare 
                                Sprite_Channel_Attribs  = $0202    ; Canale PPU per imputare gli attributi dello sprite (es. il flipping)
                                Sprite_Channel_XPos     = $0203    ; Canale PPU per imputare la posizione X dello sprite
                                
                                ; Mario è costituito da 8 Sprite (disposte 4righe x 2colonne). Ogni sprite è 8x8 pixel. 
                                ; Pertanto ogni sprite dista dall'altro 8 pixel in altezza (dall'altro verso il basso) e in larghezza (da destra verso sinistra)
                                Mario_Pixel_YPos      = $0700      ; Variabile per settare la Y di Mario (pixel più in alto di mario da cui far partire le sprite)
                                Mario_Pixel_XLeftPos  = $0701      ; Variabile per settare il punto di ancoraggio su asse X della Sprite Sinitra
                                Mario_Pixel_XRightPos = $0702      ; Variabile per settare il punto di ancoraggio su asse X della Sprite Destra
                                
                                Loop_Index            = $0001      ; Variabile dedicata a gestire indice per i loop (per poter usare i registri X e Y per fare altro durante il loop)
                                Tile_Table_Offset     = $0002      ; {0=riga1, 8=riga2, 16=riga3, 24=riga4} Offset rispetto a Mario_TileNum_Table e Mario_TileAttribs_Table
                                Player_Status         = $0003      ; {0=Standing, 1=Walking} Stato del player  
                                Player_Direction      = $0005      ; {#$00=Right, #$40=Left} Uso questi valori per poter fare XOR sugli Attribs cosi da invertire il flipping facilmente al cambio di direzione
                                
                                Frame_Counter         = $0000      ; Contatore dei frame. Usato per temporizzare il Walking Frame
                                Controller_Arrow_Pressed = $0004   ; {0=No, 1=Si} Per memorizzare se sono stati premuti i pulsanti LEFT o RIGHT
                                
                                L_Byte = $0009                     ; Usati per contenere valori superiori a 256 (8bit)
                                H_Byte = $000A                     ; L_Byte contiene il byte meno significativo e H_Byte contiene il byte piu significativo
                                                                   ; Devono puntare indirizzi contigui (prima L_Byte e poi H_Byte)
                                ; #####################################################
                                
                                ; #####################################################
                                ; ###### Logica PROGRAMMA iNES ########################
                                ; #####################################################
                                ; Il programma della cartuccia deve partire dall'indirizzo 8000 e finire a FFFF, quindi essere grande 32KB (32KB richiedono 2 PRG come settato nell'header).
                                ; In questo programma non raggiungo i 32KB quindi si fa un padding. (Se fosse più grande sarebbe necessario gestire PRG SWITCH usando i MAPPER)
                                
                                .base $8000                                         ; Per settare l'indirizzo di memoria da cui il programma partirà, cosi da matchare l'area di memoria della CPU dedicata alla CARTUCCIA
08000                           
08000                           Mario_TileNum_Table:
08000 00 01 4C 4D 4A 4A 4B 4B     .db $00, $01, $4C, $4D, $4A, $4A, $4B, $4B        ; Standing Tiles
08008 00 01 02 03 04 05 06 07     .db $00, $01, $02, $03, $04, $05, $06, $07        ; Walking Tiles Frame 1
08010 08 09 0A 0B 0C 0D 0E 0F     .db $08, $09, $0A, $0B, $0C, $0D, $0E, $0F        ;               Frame 2
08018 10 11 12 13 14 15 16 17     .db $10, $11, $12, $13, $14, $15, $16, $17        ;               Frame 3
08020                           Mario_TileAttribs_Table:
08020 00 00 00 00 00 40 00 40     .db $00, $00, $00, $00, $00, $40, $00, $40        ; Standing Attribs ( 01000000 flipping abilitato = HEX $40)
08028 00 00 00 00 00 00 00 00     .db $00, $00, $00, $00, $00, $00, $00, $00        ; Walking Attribs Frame 1
08030 00 00 00 00 00 00 00 00     .db $00, $00, $00, $00, $00, $00, $00, $00        ;                 Frame 2
08038 00 00 00 00 00 00 00 00     .db $00, $00, $00, $00, $00, $00, $00, $00        ;                 Frame 3
08040                           
08040                           ; Tavola Background        + Attributi (1024 Byte)
08040                           ;  960 Byte (32 x 30 tile) + 64 Byte 
08040                           ; Nota: La Name Table 0 va dall'indirizzo $2000 a $23FF. In particolare: 
08040                           ;       - da $2000 fino a $23BF (960 byte): Background
08040                           ;       - da $23C0 fino a 23FF  (64 byte): Attributi
08040                           ; Nota2: Ho messo sia il Background che gli attributi nella stessa table cosi da poter caricare tutto in memoria con un solo loop
08040                           Background_TileNum_Table:
08040                            ; Riferimenti ai tile del background
08040 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 01
08060 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 02
08080 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 03
080A0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 04
080C0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 05
080E0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 06
08100 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 07
08120 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 08
08140 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 09
08160 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 10
08180 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 11
081A0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 12
081C0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 13
081E0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 14
08200 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 15
08220 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 16
08240 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 17
08260 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 18
08280 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 19
082A0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 20
082C0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 21
082E0 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 22
08300 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 23
08320 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 24
08340 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 25
08360 24 24 24 24 24 24 24 24..  .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 26
08380 B5 B4 B5 B4 B5 B4 B5 B4..  .db $B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4 ; 27
083A0 B7 B6 B7 B6 B7 B6 B7 B6..  .db $B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6 ; 28
083C0 B5 B4 B5 B4 B5 B4 B5 B4..  .db $B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4 ; 29
083E0 B7 B6 B7 B6 B7 B6 B7 B6..  .db $B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6 ; 30
08400                            ; Configurazione attributi dei tile. Indicano per gruppi di 4x4 tile a quale dei 4 slot della palette background riferirsi per prendere il colore in base ai bit dei pixel
08400                            ; I bit di ogni attributo incidono in questo modo sui quattro slot: 44332211
08400                            ; Con ogni coppia di bit rappresento un valore da 0 a 3 che punta allo slot palette
08400 00 00 00 00 00 00 00 00    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
08408 00 00 00 00 00 00 00 00    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
08410 00 00 00 00 00 00 00 00    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
08418 00 00 00 00 00 00 00 00    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
08420 00 00 00 00 00 00 00 00    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
08428 00 00 00 00 00 00 00 00    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
08430 FF FF FF FF FF FF FF FF    .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
08438 FF FF FF FF FF FF FF FF    .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
08440                           
08440                           Mario_Palette_Table:
08440 22 29 1A 0F 22 36 17 0F..   .db $22,$29,$1A,$0F,$22,$36,$17,$0F,$22,$30,$21,$0F,$22,$27,$17,$0F    ; Background
08450 22 16 27 18 22 1A 30 27..   .db $22,$16,$27,$18,$22,$1A,$30,$27,$22,$16,$30,$27,$00,$0F,$36,$17    ; Sprite
08460                           
08460                           RESET:
08460 78                          SEI                   ; disable IRQs
08461 D8                          CLD                   ; disable decimal mode
08462 A2 40                       LDX #$40
08464 8E 17 40                    STX $4017             ; disable APU frame IRQ
08467 A2 FF                       LDX #$FF
08469 9A                          TXS                   ; Set up stack
0846A E8                          INX                   ; now X = 0
0846B 8E 00 20                    STX PPU_CTRL_REG1     ; disable NMI
0846E 8E 01 20                    STX PPU_CTRL_REG2     ; disable rendering
08471 8E 10 40                    STX $4010             ; disable DMC IRQs
08474                           
08474                           ; PPU Warm-Up
08474                           vblankwait1:       ; First wait for vblank to make sure PPU is ready
08474 2C 02 20                    BIT PPU_STATUS_REG
08477 10 FB                       BPL vblankwait1
08479                           vblankwait2:      ; Second wait for vblank, PPU is ready after this
08479 2C 02 20                    BIT PPU_STATUS_REG
0847C 10 FB                       BPL vblankwait2
0847E                           
0847E                           ClearMemory:
0847E A9 00                       LDA #$00
08480 95 00                       STA $0000, x
08482 9D 00 01                    STA $0100, x
08485 9D 00 03                    STA $0300, x
08488 9D 00 04                    STA $0400, x
0848B 9D 00 05                    STA $0500, x
0848E 9D 00 06                    STA $0600, x
08491 9D 00 07                    STA $0700, x
08494 A9 FE                       LDA #$FE
08496 9D 00 02                    STA $0200, x    ; move all sprites off screen
08499 E8                          INX
0849A D0 E2                       BNE ClearMemory
0849C                              
0849C                           LoadPalettes:
0849C AD 02 20                    LDA PPU_STATUS_REG              ; read PPU status to reset the high/low latch
0849F A9 3F                       LDA #$3F
084A1 8D 06 20                    STA PPU_ADDRESS_REG             ; write the high byte of $3F00 address
084A4 A9 00                       LDA #$00
084A6 8D 06 20                    STA PPU_ADDRESS_REG             ; write the low byte of $3F00 address
084A9                             
084A9 A2 00                       LDX #$00
084AB                           LoadPalettesLoop:
084AB BD 40 84                    LDA Mario_Palette_Table, X      ; load palette byte
084AE 8D 07 20                    STA PPU_DATA_REG                ; write to PPU
084B1 E8                          INX                             ; set index to next byte
084B2 E0 20                       CPX #$20            
084B4 D0 F5                       BNE LoadPalettesLoop            ; Se X = $20 (Significa che ho ciclato su tutti e 32 gli elementi della Mario_Palette_Table)
084B6                           
084B6                           InitPlayer:  
084B6                             ; Posizione iniziale di Mario.
084B6                             ; Settato al centro dello schermo in orizzante e sopra il pavimento in verticale
084B6 A9 B0                       LDA #$B0
084B8 8D 00 07                    STA Mario_Pixel_YPos
084BB A9 70                       LDA #$70
084BD 8D 01 07                    STA Mario_Pixel_XLeftPos
084C0 18                          CLC
084C1 69 08                       ADC #$08
084C3 8D 02 07                    STA Mario_Pixel_XRightPos
084C6                           
084C6                           LoadBackground:
084C6 AD 02 20                    LDA PPU_STATUS_REG      ; read PPU status to reset the high/low latch
084C9 A9 20                       LDA #$20
084CB 8D 06 20                    STA PPU_ADDRESS_REG     ; write the high byte of $2000 address
084CE A9 00                       LDA #$00
084D0 8D 06 20                    STA PPU_ADDRESS_REG     ; write the low byte of $2000 address
084D3                           
084D3                             ; Uso strataggemma di caricare l'indirizzo in L_Byte e H_Byte
084D3                             ; e quindi usare questi ultimi con indirizzamento indiretto,
084D3                             ; cosi da superare il limite di poter iterare fino a un masssimo di 256 elementi (8 bit) dovuti ai registri.
084D3 A9 40                       LDA #<Background_TileNum_Table    ; Carica il byte di memoria meno significativo
084D5 85 09                       STA L_Byte                        
084D7 A9 80                       LDA #>Background_TileNum_Table    ; Carica il byte di memoria piu significativo
084D9 85 0A                       STA H_Byte
084DB A2 00                       LDX #$00                         
084DD A0 00                       LDY #$00
084DF                           LoadBackgroundLoop:
084DF B1 09                       LDA ($09), Y                 ; Carica dati con l'indirizzo ottenuto da (L_Byte + H_Byte) load data from address (background + the value in x)
084E1 8D 07 20                    STA PPU_DATA_REG                    ; write to PPU
084E4 C8                          INY
084E5 C0 00                       CPY #$00
084E7 D0 F6                       BNE LoadBackgroundLoop
084E9 E6 0A                       INC H_Byte
084EB E8                          INX
084EC E0 04                       CPX #$04
084EE D0 EF                       BNE LoadBackgroundLoop
084F0                           
084F0                           TurnOnNmiAndRendering:
084F0 A9 90                       LDA #%10010000        ; Abilita:NMI, Sprite su Pattern Table 0 e Background da Pattern Table 1 
084F2 8D 00 20                    STA PPU_CTRL_REG1
084F5 A9 1E                       LDA #%00011110        ; rende visibili: Sprite e Background 
084F7 8D 01 20                    STA PPU_CTRL_REG2  
084FA                             
084FA A9 00                       LDA #$00              ; disabilita Background Scrolling 
084FC 8D 05 20                    STA PPU_SCROLL_REG
084FF 8D 05 20                    STA PPU_SCROLL_REG
08502                           
08502                           Forever:
08502 4C 02 85                    JMP Forever           ; game loop infinito per non far terminare il programma
08505                           
08505                           
08505                           DrawPlayer:
08505 A0 00                       LDY #$00               ; Reg Y usato come Offset per l'indirizzamento degli SPRITE. Ogni sprite ha 4 indirizzi.
08507 A6 02                       LDX Tile_Table_Offset  ; Reg X usato come OFfset per l'indirizzamento delle Table.
08509                           
08509 A9 08                       LDA #$08
0850B 85 01                       STA Loop_Index          ; Indice del loop. Settato al max del numero di sprite Sprite da disegnare (8 Sprite) e viene descrementato di 2 a ogni ciclo (poichè lavoro su 2 sprite alla volta)
0850D                           
0850D A9 B0                       LDA #$B0
0850F 8D 00 07                    STA Mario_Pixel_YPos    ; Resetta la y del pixel al valore originale, poichè viene incrementato a ogni riga di sprite che disegno
08512                           
08512                           DrawPlayerLoop:
08512                             ;; Disegna SPRITE a Sinistra
08512 AD 00 07                    LDA Mario_Pixel_YPos
08515 99 00 02                    STA Sprite_Channel_YPos,Y       
08518 AD 01 07                    LDA Mario_Pixel_XLeftPos
0851B 99 03 02                    STA Sprite_Channel_XPos,Y        
0851E BD 00 80                    LDA Mario_TileNum_Table+0,X
08521 99 01 02                    STA Sprite_Channel_TileNum,Y      
08524 BD 20 80                    LDA Mario_TileAttribs_Table+0,X
08527 45 05                       EOR Player_Direction                  ; Lo XOR con la direzione del player permette di invertire il flipping di base previsto nella Mario_TileAttribs_Table
08529 99 02 02                    STA Sprite_Channel_Attribs,Y  
0852C                           
0852C                             ;; Disegna SPRITE a Destra
0852C AD 00 07                    LDA Mario_Pixel_YPos
0852F 99 04 02                    STA Sprite_Channel_YPos + 4, Y           
08532 AD 02 07                    LDA Mario_Pixel_XRightPos
08535 99 07 02                    STA Sprite_Channel_XPos + 4, Y       
08538 BD 01 80                    LDA Mario_TileNum_Table+1,X
0853B 99 05 02                    STA Sprite_Channel_TileNum + 4, Y    
0853E BD 21 80                    LDA Mario_TileAttribs_Table+1,X
08541 45 05                       EOR Player_Direction
08543 99 06 02                    STA Sprite_Channel_Attribs + 4, Y  
08546                           
08546                             ; Incrementa Offset delle SPRITE
08546 98                          TYA        ; Porta Y in A
08547 18                          CLC        ; Azzera il Carry
08548 69 08                       ADC #$08   ; Incrementa offset di A + 8 (8 = 4addr x 2sprite)
0854A A8                          TAY        ; Riporta il risultato in Y
0854B                           
0854B                             ; Incrementa la posizione y dei pixel per passare alla prossima riga degli sprite.
0854B AD 00 07                    LDA Mario_Pixel_YPos
0854E 18                          CLC
0854F 69 08                       ADC #$08                        ; Ogni sprite è 8x8 per cui incremento la riga di 8
08551 8D 00 07                    STA Mario_Pixel_YPos
08554                             
08554                             ; Incremento Offset delle TABLE (2 volte poichè disegno 2 sprite ogni ciclo)
08554 E8                          INX
08555 E8                          INX
08556                           
08556                             ; Decremento l'indice del loop (2 volte poichè disegno 2 sprite ogni ciclo)
08556 C6 01                       DEC Loop_Index
08558 C6 01                       DEC Loop_Index
0855A D0 B6                       BNE DrawPlayerLoop 
0855C 60                        RTS  
0855D                           
0855D                           HandleInput:
0855D A9 00                       LDA #$00
0855F 85 04                       STA Controller_Arrow_Pressed
08561                           
08561                             ; Reset Controller
08561                             ; Ogni volta va resettato il controller (In realtà l'istruzione resetta entrambi i controller)
08561                             ; Siccome la PPU è a 8bit per scrivere 16bit devo scrivere 2 volte
08561 A9 01                       LDA #$01
08563 8D 16 40                    STA JOYPAD_STATUS
08566 A9 00                       LDA #$00
08568 8D 16 40                    STA JOYPAD_STATUS       
0856B                           
0856B                             ; Lettura input dal Joypad 1. Gli input vanno letti in ordine.
0856B                             ; In questo caso gestisco solo Left e Right
0856B AD 16 40                    LDA JOYPAD_PORT1    ; player 1 - A
0856E AD 16 40                    LDA JOYPAD_PORT1    ; player 1 - B
08571 AD 16 40                    LDA JOYPAD_PORT1    ; player 1 - Select
08574 AD 16 40                    LDA JOYPAD_PORT1    ; player 1 - Start
08577 AD 16 40                    LDA JOYPAD_PORT1    ; player 1 - Up
0857A AD 16 40                    LDA JOYPAD_PORT1    ; player 1 - Down
0857D                           
0857D AD 16 40                    LDA JOYPAD_PORT1    ; player 1 - Left
08580 29 01                       AND #%00000001      ; only look at bit 0
08582 D0 15                       BNE LeftBtnPressed
08584                           
08584 AD 16 40                    LDA JOYPAD_PORT1     ; player 1 - Right
08587 29 01                       AND #%00000001       ; only look at bit 0
08589 D0 3E                       BNE RightBtnPressed
0858B                           
0858B                             ; Se non sono state premute Left o Right
0858B A5 04                       LDA Controller_Arrow_Pressed
0858D 29 01                       AND #%00000001
0858F F0 01                       BEQ NoArrowBtnPressed 
08591                           
08591 60                          RTS
08592                           
08592                           NoArrowBtnPressed:      ; Se nessuna freccia è stata premuta allora riporto Mario in Standing 
08592 A9 00                       LDA #$00
08594 85 03                       STA Player_Status     ; 0=Standing
08596 85 02                       STA Tile_Table_Offset ; Riporta il table offset a 0 in cui ci sono i tile e attribs per lo Standing
08598 60                        RTS
08599                           
08599                           LeftBtnPressed:
08599 A9 01                       LDA #$01
0859B 85 04                       STA Controller_Arrow_Pressed
0859D                           
0859D A5 05                       LDA Player_Direction
0859F 29 40                       AND #$40
085A1 D0 10                       BNE DecrementPosition      ; Se Player_Direction è gia LEFT allora aggiorna solo la posizione
085A3                           
085A3 A9 40                       LDA #$40
085A5 85 05                       STA Player_Direction   ; LEFT
085A7                           
085A7                             ;INVERTO POS X PER INVERTIRE GLI SPRITE
085A7 AE 01 07                    LDX Mario_Pixel_XLeftPos       
085AA AC 02 07                    LDY Mario_Pixel_XRightPos      
085AD 8C 01 07                    STY Mario_Pixel_XLeftPos       
085B0 8E 02 07                    STX Mario_Pixel_XRightPos
085B3                           
085B3                           DecrementPosition:
085B3 AE 01 07                    LDX Mario_Pixel_XLeftPos
085B6 38                          SEC
085B7 CA                          DEX
085B8 CA                          DEX
085B9 8E 01 07                    STX Mario_Pixel_XLeftPos
085BC                           
085BC AE 02 07                    LDX Mario_Pixel_XRightPos
085BF 38                          SEC
085C0 CA                          DEX
085C1 CA                          DEX
085C2 8E 02 07                    STX Mario_Pixel_XRightPos
085C5                           
085C5 20 F9 85                    JSR WalkingRoutine
085C8 60                        RTS
085C9                           
085C9                           RightBtnPressed:
085C9 A9 01                       LDA #$01
085CB 85 04                       STA Controller_Arrow_Pressed
085CD                           
085CD A5 05                       LDA Player_Direction
085CF 29 40                       AND #$40
085D1 F0 10                       BEQ IncrementPosition      ; Se Player_Direction NON E' LEFT (Quindi è RIGHT) allora aggiorna solo la posizione
085D3                           
085D3 A9 00                       LDA #$00
085D5 85 05                       STA Player_Direction   ; RIGHT
085D7                           
085D7                             ;INVERTO POS X PER INVERTIRE GLI SPRITE (Inverto poiche venivo dalla direzione left)
085D7 AE 01 07                    LDX Mario_Pixel_XLeftPos       
085DA AC 02 07                    LDY Mario_Pixel_XRightPos      
085DD 8C 01 07                    STY Mario_Pixel_XLeftPos       
085E0 8E 02 07                    STX Mario_Pixel_XRightPos
085E3                           
085E3                           IncrementPosition:
085E3 AE 01 07                    LDX Mario_Pixel_XLeftPos
085E6 18                          CLC
085E7 E8                          INX
085E8 E8                          INX
085E9 8E 01 07                    STX Mario_Pixel_XLeftPos
085EC                           
085EC AE 02 07                    LDX Mario_Pixel_XRightPos
085EF 18                          CLC
085F0 E8                          INX
085F1 E8                          INX
085F2 8E 02 07                    STX Mario_Pixel_XRightPos
085F5                             
085F5 20 F9 85                    JSR WalkingRoutine
085F8 60                        RTS
085F9                           
085F9                           WalkingRoutine:
085F9 A6 03                       LDX Player_Status
085FB E0 01                       CPX #$01  ;Walking
085FD D0 15                       BNE SetWalkingStatus ; if NO WALKING: Setta Stato WALKING
085FF A6 02                       LDX Tile_Table_Offset   ; else se Sono Al frame 3 di walking
08601 E0 18                       CPX #$18             ;   24 = Frame3 Walking
08603 F0 0F                       BEQ SetWalkingStatus ;   Resetta a Frame1 Walking Status     
08605                             
08605                             ; Per regolare la velocità con cui passare tra un Frame dei Tile e l'altro (e quindi l'animazione)
08605 A5 00                       LDA Frame_Counter
08607 29 07                       AND #%00000111
08609 F0 01                       BEQ NextWalkingStatus
0860B 60                          RTS
0860C                             
0860C                             NextWalkingStatus:
0860C 18                            CLC
0860D A5 02                         LDA Tile_Table_Offset
0860F 69 08                         ADC #$08             ; else Passa al frame successivo di walking (8 per passare alla tabella successiva)
08611 85 02                         STA Tile_Table_Offset
08613 60                          RTS
08614                           
08614                             SetWalkingStatus:
08614 A9 01                         LDA #$01
08616 85 03                         STA Player_Status
08618 A9 08                         LDA #$08
0861A 85 02                         STA Tile_Table_Offset
0861C 60                          RTS
0861D                           
0861D                           NMI:
0861D                             ; Abilita il trasferimento DMA per gli Sprite (dalla Cartuccia alla PPU)
0861D A9 00                       LDA #$00
0861F 8D 03 20                    STA PPU_SPRITE_ADDR_REG       ; set the low byte (00) of the RAM address
08622 A9 02                       LDA #$02
08624 8D 14 40                    STA DMA_SPRITE_COPY_REG       ; set the high byte (02) of the RAM address, start the transfer
08627                             
08627 E6 00                       INC Frame_Counter             ; Aggiorna il contatore dei frame
08629 20 5D 85                    JSR HandleInput               ; Gestione del controller
0862C 20 05 85                    JSR DrawPlayer                ; Disegno di Mario
0862F 40                          RTI        ; return from interrupt
08630                           
08630 00 00 00 00 00 00 00 00.. .org $FFFA                  ; Imposta il programma all'indirizzo di memoria 65530. Contestualmente riempe tutti i precedenti con 0. (partendo dalla memoria dell'ultima istruzione di programma) 
0FFFA                                                       ; Cosi raggiungo la dimensione di programma standard della CARTUCCIA (32KB), poichè deve avere dimensione fissa.
0FFFA                           ; #####################################################
0FFFA                           
0FFFA                           
0FFFA                           ; #####################################################
0FFFA                           ; ############ Impostazione INTERRUPT iNES ############
0FFFA                           ; #####################################################
0FFFA                           ; Da $FFFA (65530) a $FFFF(65536), ci sono 6 byte per configurare la gestione degli interrupt
0FFFA                           ; Ci sono 3 tipi di interrupt ognuno dei quali è accessible su 2 Byte
0FFFA                           ; #####################################################
0FFFA 1D 86                     .dw NMI                     ; [$FFFA, $FFFB] gestione interrupt "vblank" => vai all'indirizzo NMI
0FFFC 60 84                     .dw RESET                   ; [$FFFC, $FFFD] gestione interrupt "reset" => vai alla label "RESET". Invece che dirgli di ricominciare dall'indirizzo 8000 con [.dw $8000]
0FFFE 00 00                     .dw 0                       ; [$FFFE, $FFFF] gestione interrupt "break" => vai all'indirizzo 0 (al momento per non gestirlo)
10000                           ; #####################################################
10000                           
10000 03 0F 1F 1F 1C 24 26 66.. .incbin "src/mario.chr"   ;includes 8KB graphics file from SMB1