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
;
; NOTE: extremely important... you cant have file names like PIC-x-y- etc with
; the colons like that... it will not compile!!!! fix that in your actual project file
; ______________________________________________________________________________

; ==============================================================================
;                           variables/constantes
; ==============================================================================

    ; import labels from other modules
    EXTERN      PTR_PROMPT_MSG
    ; subprograms
    EXTERN      USART_Config, ADC_Config, TMR1_Config

    ; ces registres sont accesibles de n'importe quelle page de memoire
    ; I believe I have to go ahead and use UDATA... I should do that
SHARED_REGS     UDATA_SHR
W_TEMP          RES 1   ; pour context sauvegarde (ISR)
STATUS_TEMP     RES 1   ; pour context sauvegarde (ISR)
ADC_RESULT      RES 1   ; contient le resultat
                        ; binaire (tension) de l'ADC
TMR1_V_COUNT    RES 1   ; contient le nombre de fois le peripherique
                        ; Timer1 a fait un overflow
CURRENT_MODE    RES 1   ; contient le mode de fonctionnement actuel du systeme
                        ; 'A' pour automatique, 'D' pour manuel
MODE_REQUEST    RES 1   ; contient le mode de fonctionnement demande par
                        ; l'utilisateur

    ; export labels to other modules
    GLOBAL      W_TEMP, STATUS_TEMP, ADC_RESULT, TMR1_V_COUNT, CURRENT_MODE, MODE_REQUEST

; ==============================================================================
;                               configuration du uC
; ==============================================================================

    list p=16f877
    include "p16f877.inc"

    ; PIC16F877 Configuration Bit Settings
    ; turn on ICD with _DEBUG_OFF, because this
    ; clears the DEBUG bit in the config word (see doc)
    __CONFIG _DEBUG_OFF & _LVP_OFF & _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _CPD_OFF & _WRT_ON


START_PROGRAM   CODE      0x000
                nop              ; reserved for the  In-Circuit Debugger
                PAGESEL   MAIN_Config
                goto      MAIN_Config

;#define INTERRUPTS_ON           ; si commenté, les interrupts ne sont pas enables
                                 ; si c'est le cas, seulement le message de prompt
                                 ; est affiché au terminal et le programme reste
                                 ; dans la boucle while() sans en sortir

; ==============================================================================
;                         configuration des periphiques
; ==============================================================================

MAIN_FILE       CODE
MAIN_Config
    PAGESEL     USART_Config
    call        USART_Config
    PAGESEL     ADC_Config
    call        ADC_Config
    PAGESEL     TMR1_Config
    call        TMR1_Config

; ==============================================================================
;                    Print prompt message to PC terminal (polling)
; ==============================================================================

; ------------------------------------------
;      Load prompt message into RAM
; ------------------------------------------

LOAD_PROMPT_RAM
    bankisel PTR_PROMPT_MSG ; selectionner banque pour l'acces indirecte
    movlw PTR_PROMPT_MSG    ; intialiser le pointeur

    movwf FSR               ; le FSR contient le pointeur
    movlw A'T'              ; premier byte du message prompt
    movwf INDF              ; Le registre pointe par PTR_PROMPT_MSG
                            ; est charge avec le premier byte du msg ('T') en ASCII
    incf FSR,F              ; prochain byte
    movlw A'e'              ; etc...
    movwf INDF

    incf FSR,F
    movlw A's'
    movwf INDF

    incf FSR,F
    movlw A't'
    movwf INDF

    incf FSR,F              ; return carriage character
    movlw A'\r'
    movwf INDF

    incf FSR,F              ; new line character
    movlw A'\n'
    movwf INDF

    incf FSR,F              ; END OF STRING NULL CHARACTER
    movlw A'\0'
    movwf INDF

; ----------------------------------------------
;      Print prompt via USART to PC terminal
; ----------------------------------------------

PRINT_PROMPT_MSG
    ; necessaire a faire un banksel/bankisel pour les deux, car ces 2 registres sont accede
    ; par 2 manieres different - addressage directe et addressage indirecte
    banksel     PIR1              ; selectionne le bank pour PIR1 this (RP1, RP0)
    bankisel    PTR_PROMPT_MSG    ; selectionne le bank pour PTR_PROMPT_MSG (IRP)

    movlw       PTR_PROMPT_MSG
    movwf       FSR               ; point to the start of the prompt msg

TEST_END_OF_MSG
    movf        INDF, W           ; move current byte pointed by FSR to work reg
    xorlw       A'\0'             ; this operation will make Z flag = 1 if
                                  ; null character ('\0') of the msg is reached
    btfsc       STATUS, Z         ; if the end of the msg is reached, end USART comm
    goto MSG_SENT

TEST_TXIF
    btfss       PIR1, TXIF        ; test if the TX_REG is empty
    goto        TEST_TXIF         ; sinon, attendre

    movf        INDF, W           ; place msg byte pointed to by FSR into work reg
    movwf       TXREG             ; send msg byte to USART TX register
    incf        FSR               ; increment pointer index to next byte in prompt msg
    goto        TEST_END_OF_MSG

; it is not necessary to preload the FSR and preset the IRP, a nop instruction could
; be placed here instead, or a rearranged labeling
MSG_SENT
                bankisel PTR_RESULT   ; preselect the correct bank for indirect addressing
                                      ; the start of this msg
                movlw PTR_RESULT      ; preload the FSR with the address to the
                movwf FSR             ; ADC result (this will be the next msg to send)


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

; ----------------------------------
;          end module code
; ----------------------------------
        end
