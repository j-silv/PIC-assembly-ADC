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

    ; import labels from other modules
    EXTERN      PTR_PROMPT_MSG, SIZE_PROMPT_MSG, X_VAL_SPBRG
    ; subprograms
    EXTERN      USART_Config, ADC_Config, TMR1_Config
    
    ; ces registres sont accesibles de n'importe quelle page de memoire
    ; I believe I have to go ahead and use UDATA... I should do that
    CBLOCK      0x70
W_TEMP          ; pour context sauvegarde (ISR)
STATUS_TEMP     ; pour context sauvegarde (ISR)
ADC_RESULT      ; contient le resultat
			    ; binaire (tension) de l'ADC
TMR1_V_COUNT  ; contient le nombre de fois le peripherique
                ; Timer1 a fait un overflow
TX_CHAR_COUNT   ; contient le nombre de caracteres pas encore envoye via
                ; USART pour un transfert donnee
CURRENT_MODE    ; contient le mode de fonctionnement actuel du systeme
                ; 'A' pour automatique, 'D' pour manuel
MODE_REQUEST    ; contient le mode de fonctionnement demande par
                ; l'utilisateur
    ENDC

    ; export labels to other modules
    GLOBAL      W_TEMP, STATUS_TEMP, ADC_RESULT, TMR1_V_COUNT, TX_CHAR_COUNT, CURRENT_MODE, MODE_REQUEST

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

;#define INTERRUPTS_ON      ; si commenté, les interrupts ne sont pas enables
MAIN_FILE    CODE        0x000            ; Commencer au RESET vector
    clrf        PCLATH           ; 1ere page memoire programme selectionne

; ==============================================================================
;                         configuration des periphiques
; ==============================================================================

    call        USART_Config
    call        ADC_Config
    call        TMR1_Config


; ==============================================================================
;                    Print prompt message to PC terminal (polling)
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

PRINT_PROMPT_MSG
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
;                           Interrupts configuration
; ==============================================================================

#ifdef INTERRUPTS_ON
PERIPH_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, PEIE  ; ADC/USART peripheral interrupt enable
GLOBAL_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, GIE  ; global interrupt enable
USART_RCIF_ENABLE
  banksel     PIE1
  bsf         PIE1, RCIE   ; Receive USART flag enable
#endif

; ==============================================================================
;                       programme principal (boucle infinie)
; ==============================================================================
main
        nop
        goto     main
        end                ; fin du programme (directive d'assemblage)
