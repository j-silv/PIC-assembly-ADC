;==========================================================
; TP Master 1 - MNE (2020-2021)
; Justin SILVER
; ==========================================================
; systeme d'acquisition pour PC
; microcontroleur - PIC16F877
; ==========================================================
; Ce programme lit une tension brute venant de l'ADC, le
; convertit en decimal et apres en ASCII.
; Ensuite, le resultat est envoye via USART au terminal PC
; ==========================================================

; ==========================================================
;                    variables/constantes
; ==========================================================

W_TEMP         EQU 0x70     ; pour context sauvegarde (ISR)
STATUS_TEMP    EQU 0x71     ; pour context sauvegarde (ISR)
;PCLATH_TEMP   EQU 0x72     ; necessaire si plusieurs pages memoires programmes
			                ; sont utilises
ADC_RESULT     EQU 0x73     ; registre en memoire qui contient le resultat
			                ; binaire (tension) de l'ADC
TIMER1_V_COUNT EQU 0x74     ; registre qui contient le nombre de fois le peripherique
                            ; Timer1 a fait un overflow
X_VAL_SPBRG    EQU D'25'    ; prescaler valeur pour le baud-rate generateur
VIRGULE_ASCII  EQU 0x2C

; ==========================================================
;                    configuration du uC
; ==========================================================

    list p=16f877

    ; Inclure le fichier de description des d�finitions du 16f877
    include "p16f877.inc"

    ; PIC16F877 Configuration Bit Settings
    ; Assembly source line config statements
    ; CONFIG
    ; __config 0xFF39
    __CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_ON

    org         0x000            ; Commencer au RESET vector
    clrf        PCLATH           ; 1ere page memoire programme selectionne
    goto        PIC_config       ; brancher pour configurer les peripheriques, les interrupts, etc.

; ===========================================================
;                Interrupt service routine (ISR)
; ===========================================================

; -----------------------------------------------------------
;                    Sauvegarder le contexte
; -----------------------------------------------------------

    org         0x004             ; interrupt vector location pour le PIC uC
    movwf       W_TEMP            ; Copy W to TEMP register
    swapf       STATUS, W         ; Swap status to be saved into W
    ; cette instruction n'est pas necessaire car tous les X_TEMPs registres
    ; sont communs pour toutes les pages de RAM
    clrf        STATUS            ; selectionner bank 0, regardless of current bank
                                  ; Clears IRP,RP1,RP0
    movwf       STATUS_TEMP       ; Save status to bank zero STATUS_TEMP register

    ; ces instructions ne sont pas necessaire car seulement la 1ere page mem program
    ; est utilise dans ce programme
    ;movf         PCLATH, W       ; Only required if using pages 1, 2 and/or 3
    ;movwf        PCLATH_TEMP     ; Save PCLATH into W
    ;clrf         PCLATH          ; Page zero, regardless of current page

; -----------------------------------------------------------
;                         Actual ISR
; -----------------------------------------------------------

    ; investiguer le status des flags pour determiner la source de l'interruption
    banksel       PIR1            ; PIR1 contient les flag bits pour les perihiques
    btfsc         PIR1, TXIF      ; si le transmit empty flag est allume,
    ; envoyer un nouveau char
    call          TXIF_Callback

; -----------------------------------------------------------
;                    Sauvegarder le contexte
; -----------------------------------------------------------

    ; au cas ou le ISR programme change de banc
    ; cette instruction n'est pas necessaire car tous les X_TEMPs registres
    ; sont communs pour toutes les pages de RAM
    clrf          STATUS          ; selectionner bank 0, regardless of current bank
                                  ; Clears IRP,RP1,RP0

    ; ces instructions ne sont pas necessaire car seulement la 1ere page mem program
    ; est utilise dans ce programme
    ;movf         PCLATH_TEMP, W  ; Restore PCLATH
    ;movwf        PCLATH          ; Move W into PCLATH

    swapf         STATUS_TEMP,W   ; Swap STATUS_TEMP register into W
                                  ; (sets bank to original state)
    movwf         STATUS          ; Move W into STATUS register
    swapf         W_TEMP,F        ; Swap W_TEMP
    swapf         W_TEMP,W        ; Swap W_TEMP into W
    retfie                        ; return from interrupt!


; ===========================================================
;                 Peripheral configuration
; ===========================================================

; -----------------------------------------------------------
;             ADC (entry point for configuration)
; -----------------------------------------------------------
PIC_config
	    banksel      ADCON1
        ; Left justify ,1 analog channel
        ; VDD and VSS references
        movlw        ( 0<<ADFM | 1<<PCFG3 | 1<<PCFG2 | 1<<PCFG1 | 0<<PCFG0 )
        movwf        ADCON1

        banksel      ADCON0
        ; Fosc/8, A/D enabled
        movlw        ( 0 << ASC1 | 1<<ADSC0 | 1<<ADON )
        movwf        ADCON0

        ; ADC/USART interrupt and interrupt enable bit
        banksel      INTCON
        movlw        ( 1<<PEIE ) ; peripherique interrupt enable
        movwf        INTCON

; -----------------------------------------------------------
;           USART (mode asynchronous full-duplex)
; -----------------------------------------------------------

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

    banksel     RCSTA
    movlw       ( 1<<SPEN ) ; peripherique serie est "enabled"
    movwf       RCSTA

    ; ADC/USART interrupt and interrupt enable bit
    banksel     INTCON
    movlw       ( 1<<PEIE ) ; peripherique interrupt enable
    movwf       INTCON

; --------------------------------------------------
;                      Timer1
; --------------------------------------------------
    banksel     T1CON
    ; Prescaler = 1:8
    ; Oscillator shut off
    ; Internal clock (Fosc/4) used
    ; Timer enabled
    movlw       ( 1<<T1CKPS1 | 1<<T1CKPS0 | 0 << TMR1CS | 1<<TMR1ON )
    movwf       T1CON


;___________________________TEST TP 27/11/20________________________
; TEST --> character sending via USART
    ; USART TX flag enable
    ;banksel     PIE1
    ;movlw       ( 1<<TXIE )
    ;movwf       PIE1

; **apres que TOUT est configure, cette instruction peux etre executee**
    banksel     INTCON
    movlw       ( 1<<GIE ) ; global interrupt enable
    movwf       INTCON

    goto        main       ; branch to endless loop
;__________________________TEST TP 27/11/20_________________________



; ===========================================================
;                       ISR callbacks
; ===========================================================

RXIF_Callback()
    ; Timer1 interrupt and interrupt enable bit
    ;banksel     PIE1
    ;movlw       ( 1<<TMR1E ) ; peripherique interrupt enable
    ;movwf       PIE1
                return

TMR1IF_Callback()
    ; ADC conversion done flag enable
    banksel     PIE1
    movlw       ( 1<<ADIE )
    movwf       PIE1
                return

ADIF_Callback()
    ; USART TX flag enable
    banksel     PIE1
    movlw       ( 1<<TXIE )
    movwf       PIE1
                return

TXIF_Callback()
                movlw    A'a'     ; move the ASCII code of "a" to w
                movwf    TXREG    ; write to USART transfer register
                return            ; return to ISR or whoever called this subprogram



; ===========================================================
;                       Sous-programmes
; ===========================================================

; -------------------------------------------
;                 Lire tension ADC
; -------------------------------------------

Lire_Tension_Polling()
           banksel  ADCON0
start      bsf      ADCON0,GO        ; demarrage de la conversion
non        btfsc    ADCON0,GO        ; attendre la fin de conversion
           goto     non
oui        movf     ADRESH,W         ; mettre resultat (8 bits de poids fort)
                                     ; de la conversion au reg de travail
           movwf    ADC_RESULT       ; sauvegarder resultat (tension) en memoire

; -------------------------------------------
;           Envoyer lettre via USART
; -------------------------------------------

 ; -------------------------------------------
 ;           Transcodage ASCII
 ; -------------------------------------------


; ===========================================================
;            programme principal (boucle infinie)
; ===========================================================
main
        nop
        goto     main
        end                     ; fin du programme (directive d'assemblage)
