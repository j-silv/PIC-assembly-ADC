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
    EXTERN      PTR_PROMPT_MSG, PTR_RESULT_MSG
    ; subprograms
    EXTERN      copy_init_data, USART_Config, ADC_Config, TMR1_Config, PRINT_PROMPT_MSG

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
                lgoto      MAIN_Config

#define INTERRUPTS_ON            ; si commenté, les interrupts ne sont pas enables
                                 ; si c'est le cas, seulement le message de prompt
                                 ; est affiché au terminal et le programme reste
                                 ; dans la boucle while() sans en sortir

; ==============================================================================
;                         configuration des periphiques
; ==============================================================================

MAIN_FILE       CODE

; ENABLE_MCLR     
    ; banksel     PCON
    ; ; this is to enable master clear button on PICDEM
    ; movlw	    (1 << NOT_BOR | 1 << NOT_POR )
    ; movwf       PCON
    

MAIN_Config
    PAGESEL     copy_init_data
    lcall        copy_init_data
    ; the ADC result msg is initialized to "[X,X, ,V,\r,\n,\0]"
    ; the prompt terminal msg is initialized to "[T,E,S,T,\r,\n,\0]"
    PAGESEL     USART_Config
    lcall        USART_Config
    PAGESEL     ADC_Config
    lcall        ADC_Config
    PAGESEL     TMR1_Config
    lcall        TMR1_Config


; ==============================================================================
;               Load/initialize prompt and result msg and print prompt
; ==============================================================================

    ; the prompt terminal message is sent with polling method to PC terminal
    PAGESEL     PRINT_PROMPT_MSG
    lcall        PRINT_PROMPT_MSG

; ==============================================================================
;                           Interrupts configuration
; ==============================================================================

; clear all interrupt flags on startup
CLR_PERIPH_FLAGS
  banksel     PIR1
  bcf         PIR1, TMR1IF 
  bcf         PIR1, ADIF


#ifdef INTERRUPTS_ON
PERIPH_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, PEIE  ; ADC/USART peripheral interrupt enable
USART_RCIF_ENABLE
  banksel     PIE1
  bsf         PIE1, RCIE   ; Receive USART flag enable
GLOBAL_INT_ENABLE
  banksel     INTCON
  bsf         INTCON, GIE  ; global interrupt enable
#endif

; ==============================================================================
;                       programme principal (boucle infinie)
; ==============================================================================

main
        nop
        lgoto     main

; ----------------------------------
;          end module code
; ----------------------------------
        end
