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
.db $4E,$45,$53,$1A         ; "NES\n"
.db 2                       ; PRG Settato a 2 poichè il programma e' grosso 32784 byte (32K). Ogni PRG rappresenta un blocco di 16KB di memoria.
.db 1                       ; Imposto CHR a 1 poichè includo 1 chr alla fine del programma
.dsb 10, 0                  ; Genera 10 byte con valore 0 (invece di scrivere 10 volte .db 0), per popolare il resto dell'header che per questo programma non uso
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

Mario_TileNum_Table:
  .db $00, $01, $4C, $4D, $4A, $4A, $4B, $4B        ; Standing Tiles
  .db $00, $01, $02, $03, $04, $05, $06, $07        ; Walking Tiles Frame 1
  .db $08, $09, $0A, $0B, $0C, $0D, $0E, $0F        ;               Frame 2
  .db $10, $11, $12, $13, $14, $15, $16, $17        ;               Frame 3
Mario_TileAttribs_Table:
  .db $00, $00, $00, $00, $00, $40, $00, $40        ; Standing Attribs ( 01000000 flipping abilitato = HEX $40)
  .db $00, $00, $00, $00, $00, $00, $00, $00        ; Walking Attribs Frame 1
  .db $00, $00, $00, $00, $00, $00, $00, $00        ;                 Frame 2
  .db $00, $00, $00, $00, $00, $00, $00, $00        ;                 Frame 3

; Tavola Background        + Attributi (1024 Byte)
;  960 Byte (32 x 30 tile) + 64 Byte 
; Nota: La Name Table 0 va dall'indirizzo $2000 a $23FF. In particolare: 
;       - da $2000 fino a $23BF (960 byte): Background
;       - da $23C0 fino a 23FF  (64 byte): Attributi
; Nota2: Ho messo sia il Background che gli attributi nella stessa table cosi da poter caricare tutto in memoria con un solo loop
Background_TileNum_Table:
 ; Riferimenti ai tile del background
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 01
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 02
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 03
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 04
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 05
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 06
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 07
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 08
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 09
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 10
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 11
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 12
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 13
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 14
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 15
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 16
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 17
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 18
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 19
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 20
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 21
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 22
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 23
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 24
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 25
 .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24 ; 26
 .db $B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4 ; 27
 .db $B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6 ; 28
 .db $B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4,$B5,$B4 ; 29
 .db $B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6,$B7,$B6 ; 30
 ; Configurazione attributi dei tile. Indicano per gruppi di 4x4 tile a quale dei 4 slot della palette background riferirsi per prendere il colore in base ai bit dei pixel
 ; I bit di ogni attributo incidono in questo modo sui quattro slot: 44332211
 ; Con ogni coppia di bit rappresento un valore da 0 a 3 che punta allo slot palette
 .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
 .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
 .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
 .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
 .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
 .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000
 .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111
 .db %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111, %11111111

Mario_Palette_Table:
  .db $22,$29,$1A,$0F,$22,$36,$17,$0F,$22,$30,$21,$0F,$22,$27,$17,$0F    ; Background
  .db $22,$16,$27,$18,$22,$1A,$30,$27,$22,$16,$30,$27,$00,$0F,$36,$17    ; Sprite

RESET:
  SEI                   ; disable IRQs
  CLD                   ; disable decimal mode
  LDX #$40
  STX $4017             ; disable APU frame IRQ
  LDX #$FF
  TXS                   ; Set up stack
  INX                   ; now X = 0
  STX PPU_CTRL_REG1     ; disable NMI
  STX PPU_CTRL_REG2     ; disable rendering
  STX $4010             ; disable DMC IRQs

; PPU Warm-Up
vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT PPU_STATUS_REG
  BPL vblankwait1
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT PPU_STATUS_REG
  BPL vblankwait2

ClearMemory:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x    ; move all sprites off screen
  INX
  BNE ClearMemory
   
LoadPalettes:
  LDA PPU_STATUS_REG              ; read PPU status to reset the high/low latch
  LDA #$3F
  STA PPU_ADDRESS_REG             ; write the high byte of $3F00 address
  LDA #$00
  STA PPU_ADDRESS_REG             ; write the low byte of $3F00 address
  
  LDX #$00
LoadPalettesLoop:
  LDA Mario_Palette_Table, X      ; load palette byte
  STA PPU_DATA_REG                ; write to PPU
  INX                             ; set index to next byte
  CPX #$20            
  BNE LoadPalettesLoop            ; Se X = $20 (Significa che ho ciclato su tutti e 32 gli elementi della Mario_Palette_Table)

InitPlayer:  
  ; Posizione iniziale di Mario.
  ; Settato al centro dello schermo in orizzante e sopra il pavimento in verticale
  LDA #$B0
  STA Mario_Pixel_YPos
  LDA #$70
  STA Mario_Pixel_XLeftPos
  CLC
  ADC #$08
  STA Mario_Pixel_XRightPos

LoadBackground:
  LDA PPU_STATUS_REG      ; read PPU status to reset the high/low latch
  LDA #$20
  STA PPU_ADDRESS_REG     ; write the high byte of $2000 address
  LDA #$00
  STA PPU_ADDRESS_REG     ; write the low byte of $2000 address

  ; Uso strataggemma di caricare l'indirizzo in L_Byte e H_Byte
  ; e quindi usare questi ultimi con indirizzamento indiretto,
  ; cosi da superare il limite di poter iterare fino a un masssimo di 256 elementi (8 bit) dovuti ai registri.
  LDA #<Background_TileNum_Table    ; Carica il byte di memoria meno significativo
  STA L_Byte                        
  LDA #>Background_TileNum_Table    ; Carica il byte di memoria piu significativo
  STA H_Byte
  LDX #$00                         
  LDY #$00
LoadBackgroundLoop:
  LDA ($09), Y                 ; Carica dati con l'indirizzo ottenuto da (L_Byte + H_Byte) load data from address (background + the value in x)
  STA PPU_DATA_REG                    ; write to PPU
  INY
  CPY #$00
  BNE LoadBackgroundLoop
  INC H_Byte
  INX
  CPX #$04
  BNE LoadBackgroundLoop

TurnOnNmiAndRendering:
  LDA #%10010000        ; Abilita:NMI, Sprite su Pattern Table 0 e Background da Pattern Table 1 
  STA PPU_CTRL_REG1
  LDA #%00011110        ; rende visibili: Sprite e Background 
  STA PPU_CTRL_REG2  
  
  LDA #$00              ; disabilita Background Scrolling 
  STA PPU_SCROLL_REG
  STA PPU_SCROLL_REG

Forever:
  JMP Forever           ; game loop infinito per non far terminare il programma


DrawPlayer:
  LDY #$00               ; Reg Y usato come Offset per l'indirizzamento degli SPRITE. Ogni sprite ha 4 indirizzi.
  LDX Tile_Table_Offset  ; Reg X usato come OFfset per l'indirizzamento delle Table.

  LDA #$08
  STA Loop_Index          ; Indice del loop. Settato al max del numero di sprite Sprite da disegnare (8 Sprite) e viene descrementato di 2 a ogni ciclo (poichè lavoro su 2 sprite alla volta)

  LDA #$B0
  STA Mario_Pixel_YPos    ; Resetta la y del pixel al valore originale, poichè viene incrementato a ogni riga di sprite che disegno

DrawPlayerLoop:
  ;; Disegna SPRITE a Sinistra
  LDA Mario_Pixel_YPos
  STA Sprite_Channel_YPos,Y       
  LDA Mario_Pixel_XLeftPos
  STA Sprite_Channel_XPos,Y        
  LDA Mario_TileNum_Table+0,X
  STA Sprite_Channel_TileNum,Y      
  LDA Mario_TileAttribs_Table+0,X
  EOR Player_Direction                  ; Lo XOR con la direzione del player permette di invertire il flipping di base previsto nella Mario_TileAttribs_Table
  STA Sprite_Channel_Attribs,Y  

  ;; Disegna SPRITE a Destra
  LDA Mario_Pixel_YPos
  STA Sprite_Channel_YPos + 4, Y           
  LDA Mario_Pixel_XRightPos
  STA Sprite_Channel_XPos + 4, Y       
  LDA Mario_TileNum_Table+1,X
  STA Sprite_Channel_TileNum + 4, Y    
  LDA Mario_TileAttribs_Table+1,X
  EOR Player_Direction
  STA Sprite_Channel_Attribs + 4, Y  

  ; Incrementa Offset delle SPRITE
  TYA        ; Porta Y in A
  CLC        ; Azzera il Carry
  ADC #$08   ; Incrementa offset di A + 8 (8 = 4addr x 2sprite)
  TAY        ; Riporta il risultato in Y

  ; Incrementa la posizione y dei pixel per passare alla prossima riga degli sprite.
  LDA Mario_Pixel_YPos
  CLC
  ADC #$08                        ; Ogni sprite è 8x8 per cui incremento la riga di 8
  STA Mario_Pixel_YPos
  
  ; Incremento Offset delle TABLE (2 volte poichè disegno 2 sprite ogni ciclo)
  INX
  INX

  ; Decremento l'indice del loop (2 volte poichè disegno 2 sprite ogni ciclo)
  DEC Loop_Index
  DEC Loop_Index
  BNE DrawPlayerLoop 
RTS  

HandleInput:
  LDA #$00
  STA Controller_Arrow_Pressed

  ; Reset Controller
  ; Ogni volta va resettato il controller (In realtà l'istruzione resetta entrambi i controller)
  ; Siccome la PPU è a 8bit per scrivere 16bit devo scrivere 2 volte
  LDA #$01
  STA JOYPAD_STATUS
  LDA #$00
  STA JOYPAD_STATUS       

  ; Lettura input dal Joypad 1. Gli input vanno letti in ordine.
  ; In questo caso gestisco solo Left e Right
  LDA JOYPAD_PORT1    ; player 1 - A
  LDA JOYPAD_PORT1    ; player 1 - B
  LDA JOYPAD_PORT1    ; player 1 - Select
  LDA JOYPAD_PORT1    ; player 1 - Start
  LDA JOYPAD_PORT1    ; player 1 - Up
  LDA JOYPAD_PORT1    ; player 1 - Down

  LDA JOYPAD_PORT1    ; player 1 - Left
  AND #%00000001      ; only look at bit 0
  BNE LeftBtnPressed

  LDA JOYPAD_PORT1     ; player 1 - Right
  AND #%00000001       ; only look at bit 0
  BNE RightBtnPressed

  ; Se non sono state premute Left o Right
  LDA Controller_Arrow_Pressed
  AND #%00000001
  BEQ NoArrowBtnPressed 

  RTS

NoArrowBtnPressed:      ; Se nessuna freccia è stata premuta allora riporto Mario in Standing 
  LDA #$00
  STA Player_Status     ; 0=Standing
  STA Tile_Table_Offset ; Riporta il table offset a 0 in cui ci sono i tile e attribs per lo Standing
RTS

LeftBtnPressed:
  LDA #$01
  STA Controller_Arrow_Pressed

  LDA Player_Direction
  AND #$40
  BNE DecrementPosition      ; Se Player_Direction è gia LEFT allora aggiorna solo la posizione

  LDA #$40
  STA Player_Direction   ; LEFT

  ;INVERTO POS X PER INVERTIRE GLI SPRITE
  LDX Mario_Pixel_XLeftPos       
  LDY Mario_Pixel_XRightPos      
  STY Mario_Pixel_XLeftPos       
  STX Mario_Pixel_XRightPos

DecrementPosition:
  LDX Mario_Pixel_XLeftPos
  SEC
  DEX
  DEX
  STX Mario_Pixel_XLeftPos

  LDX Mario_Pixel_XRightPos
  SEC
  DEX
  DEX
  STX Mario_Pixel_XRightPos

  JSR WalkingRoutine
RTS

RightBtnPressed:
  LDA #$01
  STA Controller_Arrow_Pressed

  LDA Player_Direction
  AND #$40
  BEQ IncrementPosition      ; Se Player_Direction NON E' LEFT (Quindi è RIGHT) allora aggiorna solo la posizione

  LDA #$00
  STA Player_Direction   ; RIGHT

  ;INVERTO POS X PER INVERTIRE GLI SPRITE (Inverto poiche venivo dalla direzione left)
  LDX Mario_Pixel_XLeftPos       
  LDY Mario_Pixel_XRightPos      
  STY Mario_Pixel_XLeftPos       
  STX Mario_Pixel_XRightPos

IncrementPosition:
  LDX Mario_Pixel_XLeftPos
  CLC
  INX
  INX
  STX Mario_Pixel_XLeftPos

  LDX Mario_Pixel_XRightPos
  CLC
  INX
  INX
  STX Mario_Pixel_XRightPos
  
  JSR WalkingRoutine
RTS

WalkingRoutine:
  LDX Player_Status
  CPX #$01  ;Walking
  BNE SetWalkingStatus ; if NO WALKING: Setta Stato WALKING
  LDX Tile_Table_Offset   ; else se Sono Al frame 3 di walking
  CPX #$18             ;   24 = Frame3 Walking
  BEQ SetWalkingStatus ;   Resetta a Frame1 Walking Status     
  
  ; Per regolare la velocità con cui passare tra un Frame dei Tile e l'altro (e quindi l'animazione)
  LDA Frame_Counter
  AND #%00000111
  BEQ NextWalkingStatus
  RTS
  
  NextWalkingStatus:
    CLC
    LDA Tile_Table_Offset
    ADC #$08             ; else Passa al frame successivo di walking (8 per passare alla tabella successiva)
    STA Tile_Table_Offset
  RTS

  SetWalkingStatus:
    LDA #$01
    STA Player_Status
    LDA #$08
    STA Tile_Table_Offset
  RTS

NMI:
  ; Abilita il trasferimento DMA per gli Sprite (dalla Cartuccia alla PPU)
  LDA #$00
  STA PPU_SPRITE_ADDR_REG       ; set the low byte (00) of the RAM address
  LDA #$02
  STA DMA_SPRITE_COPY_REG       ; set the high byte (02) of the RAM address, start the transfer
  
  INC Frame_Counter             ; Aggiorna il contatore dei frame
  JSR HandleInput               ; Gestione del controller
  JSR DrawPlayer                ; Disegno di Mario
  RTI        ; return from interrupt

.org $FFFA                  ; Imposta il programma all'indirizzo di memoria 65530. Contestualmente riempe tutti i precedenti con 0. (partendo dalla memoria dell'ultima istruzione di programma) 
                            ; Cosi raggiungo la dimensione di programma standard della CARTUCCIA (32KB), poichè deve avere dimensione fissa.
; #####################################################


; #####################################################
; ############ Impostazione INTERRUPT iNES ############
; #####################################################
; Da $FFFA (65530) a $FFFF(65536), ci sono 6 byte per configurare la gestione degli interrupt
; Ci sono 3 tipi di interrupt ognuno dei quali è accessible su 2 Byte
; #####################################################
.dw NMI                     ; [$FFFA, $FFFB] gestione interrupt "vblank" => vai all'indirizzo NMI
.dw RESET                   ; [$FFFC, $FFFD] gestione interrupt "reset" => vai alla label "RESET". Invece che dirgli di ricominciare dall'indirizzo 8000 con [.dw $8000]
.dw 0                       ; [$FFFE, $FFFF] gestione interrupt "break" => vai all'indirizzo 0 (al momento per non gestirlo)
; #####################################################

.incbin "src/mario.chr"   ;includes 8KB graphics file from SMB1