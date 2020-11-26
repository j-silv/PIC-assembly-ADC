;______________________________________________________________________________
; TP Master 1 - MNE (2020-2021)
; Justin SILVER
;
; systeme d'acquisition, tension --> PC avec un
; microcontroleur - PIC16F877
;
; Ce programme lit une tension binaire venant de l'ADC, le
; convertit en decimal et apres en ASCII.
; Ensuite, le resultat est envoye via USART au terminal PC
; ______________________________________________________________________________

; ==============================================================================
;                           variables/constantes
; ==============================================================================
;#define INTERRUPTS_ON      ; si commenté, les interrupts ne sont pas enables

PTR_PROMPT_MSG   EQU 0x21   ; pointe a msg prompt pour l'utilisateur (6 bytes)
                            ; "Test\r\n" (bank 0)
SIZE_PROMPT_MSG  EQU 0x06   ; prompt message is 6 bytes long

; * recommendation: utilser cblock

W_TEMP           EQU 0x70   ; pour context sauvegarde (ISR)
STATUS_TEMP      EQU 0x71   ; pour context sauvegarde (ISR)
ADC_RESULT       EQU 0x72   ; contient le resultat
			                ; binaire (tension) de l'ADC
TIMER1_V_COUNT   EQU 0x73   ; contient le nombre de fois le peripherique
                            ; Timer1 a fait un overflow
TX_CHAR_COUNT    EQU 0x74   ; contient le nombre de caracteres pas encore envoye via
                            ; USART pour un transfert donnee
CURRENT_MODE     EQU 0x75   ; contient le mode de fonctionnement actuel du systeme
                            ; 'A' pour automatique, 'D' pour manuel
MODE_REQUEST     EQU 0x76   ; contient le mode de fonctionnement demande par
                            ; l'utilisateur
;*

X_VAL_SPBRG      EQU D'25'  ; prescaler valeur pour le baud-rate generateur
VIRGULE_ASCII    EQU 0x2C

; * - accesible de n'importe quelle page de memoire donne

; ==============================================================================
;                               configuration du uC
; ==============================================================================

    list p=16f877
    include "p16f877.inc"

    ; PIC16F877 Configuration Bit Settings
    ; Assembly source line config statements
    ; CONFIG
    ; __config 0xFF39
    __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_ON

    org         0x000            ; Commencer au RESET vector
    clrf        PCLATH           ; 1ere page memoire programme selectionne
    goto        ADC_config       ; brancher pour configurer les peripheriques, les interrupts, etc.

; ==============================================================================
;                        Interrupt service routine (ISR)
; ==============================================================================

; ------------------------------------
;       Sauvegarder le contexte
; ------------------------------------

    org         0x004             ; interrupt vector location pour le PIC uC
    movwf       W_TEMP            ; Copy W to TEMP register
    swapf       STATUS, W         ; Swap status to be saved into W
    movwf       STATUS_TEMP       ; Save status to bank zero STATUS_TEMP register

; -----------------------------------
;           Flag checking
; -----------------------------------

; Did we receive a message via USART?
RCIF_status
    banksel       PIR1
    btfsc         PIR1, RCIF
    call          RCIF_Callback

; Did the Timer1 module overflow?
TMR1F_status
    nop       ; NOT YET CODED

; Is the analog to digital conversion done?
ADIF_status
    nop       ; NOT YET CODED

; Is the USART TX register ready for a new character?
TXIF_status
    banksel       PIR1
    btfsc         PIR1, TXIF
    call          TXIF_Callback

; -------------------------------------
;       Restaurer le contexte
; -------------------------------------

    swapf         STATUS_TEMP,W   ; Swap STATUS_TEMP register into W
                                  ; (sets bank to original state)
    movwf         STATUS          ; Move W into STATUS register
    swapf         W_TEMP,F        ; Swap W_TEMP
    swapf         W_TEMP,W        ; Swap W_TEMP into W
    retfie                        ; return from interrupt


; ==============================================================================
;                           Peripheral configuration
; ==============================================================================

; ----------------------------------------------
;       ADC (entry point for configuration)
; ----------------------------------------------
ADC_config
	    banksel      ADCON1
        ; Left justify ,1 analog channel
        ; VDD and VSS references
        movlw        ( 0<<ADFM | 1<<PCFG3 | 1<<PCFG2 | 1<<PCFG1 | 0<<PCFG0 )
        movwf        ADCON1

        banksel      ADCON0
        ; Fosc/8, A/D enabled
        movlw        ( 0 << ADCS1 | 1<<ADCS0 | 1<<ADON )
        movwf        ADCON0

; ----------------------------------------------------
;        USART (mode asynchronous full-duplex)
; ----------------------------------------------------
USART_config
    ; entrees/sorties (RC6/TX/CK and RC7/RX/DT)
    ; TXUSART EST OUTPUT (RC6 -> sortie)
    ; RXUSART EST INPUT (RC7 -> entree)
    banksel     TRISC
    movlw       ( 0<<TRISC6 | 1<<TRISC7 )
    movwf       TRISC

    ; USART baud-rate
    ; Utilisation de HIGH SPEED mode (BRGH = 1) pour reduire l'erreur sur le baud rate
    ; formule du baud rate = (Asynchronous) Baud Rate = FOSC/(16(X+1)) ou X  est la
    ; valeur du registre SPBRG et est de 0...255
    ; nous voulons 9600 baud avec un FOSC de 4 MHz, ca donne X = 25
    banksel     SPBRG
    movlw       X_VAL_SPBRG
    movwf       SPBRG

    ; mode asynchrone
    ; high speed pour reduire l'erreur
    ; 8-bit transmission mode
    ; enable la transmission
    banksel     TXSTA
    movlw	    ( 0<<TXEN | 0<<TX9 | 1<<BRGH | 0<<SYNC )
    movwf	    TXSTA

    ; peripherique serie est "enabled"
    ; enables continuous receive
    banksel     RCSTA
    movlw       ( 1<<SPEN | 1<<CREN )
    movwf       RCSTA

    banksel     TX_CHAR_COUNT
    ;movlw       0x00            ; initaliser nombre de char envoye a 0
    ;movwf       TX_CHAR_COUNT
    clrf       TX_CHAR_COUNT   ; facon plus facile/rapide ->

; ----------------------------------
;              Timer1
; ----------------------------------

Timer1_config
    banksel     T1CON
    ; Prescaler = 1:8
    ; Oscillator shut off
    ; Internal clock (Fosc/4) used
    ; Timer enabled
    movlw       ( 1<<T1CKPS1 | 1<<T1CKPS0 | 0 << TMR1CS | 1<<TMR1ON )
    movwf       T1CON

    ;movlw       0x00        ; initaliser nombre d'overflow compte a 0
    ;movwf       TIMER1_V_COUNT
    clrf       TIMER1_V_COUNT   ; facon plus facile/rapide ->


; ==============================================================================
;                           Interrupts configuration
; ==============================================================================

#ifdef INTERRUPTS_ON

PERIPH_INT_ENABLE
    banksel     INTCON
    ;movlw       ( 1<<PEIE )    ; ADC/USART peripheral interrupt enable
    ;movwf       INTCON
    bsf         INTCON, PEIE  ; faut mieux simplement faire un bsf


GLOBAL_INT_ENABLE
    banksel     INTCON
    ;movlw       ( 1<<GIE ) ; global interrupt enable
    ;movwf       INTCON
    bsf         INTCON, GIE  ; faut mieux simplement faire un bsf


#endif

; ==============================================================================
;                    Print prompt message to PC terminal (polling)
; ==============================================================================

PRINT_PROMPT_MSG
    call        LOAD_PROMPT_RAM   ; sizeof prompt msg and prompt msg are intialized

    banksel     PIR1              ; selectionne le bank pour PIR1 (RP1, RP0)
    bankisel    PTR_PROMPT_MSG    ; selectionne le bank pour PTR_PROMPT_MSG (IRP)

    movlw       PTR_PROMPT_MSG
    movwf       FSR               ; point to the start of the prompt msg

TEST_TXIF
    btfss       PIR1, TXIF        ; test if the TX_REG is empty
    goto        TEST_TXIF         ; sinon, attendre

    movf        INDF, W
    movwf       TXREG             ; send first byte to USART TX register
    incf        FSR               ; increment pointer index to next char in prompt msg
    decfsz      TX_CHAR_COUNT     ; decrement # of chars that remain to be sent
    goto        TEST_TXIF         ; skip if the entire message has been sent
                                  ; this would mean that TX_CHAR_COUNT went from 6 to 0

; ==============================================================================
;                           Last configuration steps
; ==============================================================================
    banksel     PIE1
    ;movlw       ( 1<<RCIE )       ; Receive USART flag enable
    ;movwf       PIE1
    bsf         PIE1, RCIE         ; sinon je vais ecraser les autres bits


    goto        main              ; branch to endless loop

; ==============================================================================
;                                  ISR callbacks
; ==============================================================================

; ----------------------------------
;              RCIF
; ----------------------------------

RCIF_Callback
    banksel     RCREG
    movf        RCREG, W
    movwf       MODE_REQUEST         ; save what was received into a dedicated register
                                     ; this is to avoid possibly reading 2 different
                                     ; bytes in FIFO during the XOR tests below
TEST_IF_A_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'A'                 ; this operation will make Z flag = 0 if
                                     ; the character 'A' was received
    btfsc       STATUS, Z
    goto SET_AUTOMATIC_MODE

TEST_IF_A_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'a'                 ; this operation will make Z flag = 0 if
                                     ; the character 'a' was received
    btfsc       STATUS, Z
    goto SET_AUTOMATIC_MODE

TEST_IF_R_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'R'                 ; this operation will make Z flag = 0 if
                                     ; the character 'R' was received
    btfsc       STATUS, Z
    goto SET_MANUAL_MODE

TEST_IF_R_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'r'                 ; this operation will make Z flag = 0 if
                                     ; the character 'r' was received
    btfsc       STATUS, Z
    goto SET_MANUAL_MODE

TEST_IF_D_UPPER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'D'                 ; this operation will make Z flag = 0 if
                                     ; the character 'D' was received
    btfsc       STATUS, Z
    goto CONVERSION_REQUEST

TEST_IF_D_LOWER
    movf        MODE_REQUEST, W      ; move what was received into working reg
    xorlw       A'd'                 ; this operation will make Z flag = 0 if
                                     ; the character 'd' was received
    btfsc       STATUS, Z
    goto CONVERSION_REQUEST

SET_AUTOMATIC_MODE
    movlw       A'A'
    movwf       CURRENT_MODE         ; set the current mode reg to automatic
    banksel     PIE1
    ;movlw       ( 1<<TMR1IE )        ; Timer1 interrupt enable
    ;movwf       PIE1
    bsf         PIE1, TMR1IE         ; sinon je vais ecraser les autres bits
    goto EXIT_CALLBACK

SET_MANUAL_MODE
    movlw       A'R'
    movwf       CURRENT_MODE         ; set the current mode reg to manual
    banksel     PIE1
    ;movlw       ( 0<<TMR1IE )        ; Timer1 interrupt disable
    ;movwf       PIE1
    bcf         PIE1, TMR1IE         ; sinon je vais ecraser les autres bits
    goto EXIT_CALLBACK

CONVERSION_REQUEST
    movf        CURRENT_MODE, W
    xorlw       A'R'                 ; this operation will make Z flag = 0 if
                                     ; the current mode is manual! Thus the
                                     ; user has correctly requested a conersion
    btfsc       STATUS, Z
    call START_ADC

EXIT_CALLBACK
    return

; ----------------------------------
;              TMMR1IF
; ----------------------------------

TMR1IF_Callback
    call START_ADC
    return

; ----------------------------------
;              ADIF
; ----------------------------------

ADIF_Callback
    banksel     PIE1
    ;movlw       ( 1<<TXIE ) ; USART TX flag enable
    ;movwf       PIE1
    bsf         PIE1, TXIE  ; sinon je vais ecraser les autres bits

    return

; ----------------------------------
;              TXIF
; ----------------------------------

TXIF_Callback
    banksel     TXREG
    movlw       A'a'     ; move the ASCII code of "a" to w
    movwf       TXREG    ; write to USART transfer register
    return

; ==============================================================================
;                                Sous-programmes
; ==============================================================================

; --------------------------------------------------------------
;      Load prompt message into RAM and initialize sizeof msg
; --------------------------------------------------------------

LOAD_PROMPT_RAM
    bankisel PTR_PROMPT_MSG ; selectionner banque pour l'acces indirecte
    movlw PTR_PROMPT_MSG    ; intialiser le pointeur

    movwf FSR               ; le FSR contient le pointeur
    movlw A'T'              ; premier byte du message prompt
    movwf INDF              ; Le registre pointe par PTR_PROMPT_MSG
                            ; est charge avec le premier byte du msg ('T') en ASCII
    incf FSR               ; prochain byte ** add the destination (incf = FSR, F)***
    movlw A'e'              ; etc...
    movwf INDF
    incf FSR
    movlw A's'
    movwf INDF
    incf FSR
    movlw A't'
    movwf INDF
    incf FSR
    movlw A'\r'
    movwf INDF
    incf FSR
    movlw A'\n'
    movwf INDF

    ; The prompt is 6 bytes long, initialize this value
    movlw SIZE_PROMPT_MSG
    movwf TX_CHAR_COUNT

    return

; -------------------------------------
;      Lire tension ADC (polling)
; -------------------------------------

Lire_Tension_Polling
           banksel  ADCON0
start      bsf      ADCON0,GO            ; demarrage de la conversion
non        btfsc    ADCON0,GO_NOT_DONE   ; attendre la fin de conversion
           goto     non
oui        movf     ADRESH,W             ; mettre resultat (8 bits de poids fort)
                                         ; de la conversion au reg de travail
           movwf    ADC_RESULT           ; sauvegarder resultat (tension) en memoire
           return

; -------------------------------------
;   Start ADC conversion (interrupts)
; -------------------------------------

START_ADC
           banksel     ADCON0
           bsf         ADCON0, GO      ; demarrage de la conversion
           banksel     PIE1
           ;movlw       ( 1<<ADIE )     ; ADC conversion done interrupt flag enable
           ;movwf       PIE1
           bsf         PIE1, ADIE     ; sinon je vais ecraser les autres bits

           return

; ------------------------------------
;           Transcodage ASCII
; ------------------------------------

; NOT YET CODED


; ==============================================================================
;                       programme principal (boucle infinie)
; ==============================================================================
main
        nop
        goto     main
        end                     ; fin du programme (directive d'assemblage)
