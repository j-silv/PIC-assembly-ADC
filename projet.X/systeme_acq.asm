; ***********************************************************
;	TP Master 1 - MNE (2020-2021)
;	Justin SILVER
;	---------------------------------------------------------
;	systeme d'acquisition pour PC
; 	microcontroleur - PIC16F877
;	---------------------------------------------------------
;	Ce programme lit une tension brute venant de l'ADC, le
; 	convertit en decimal et apres en ASCII.
;	Ensuite, le resultat est envoye via USART au terminal PC
;	---------------------------------------------------------
;	NOTES:
;	-The TSR register is not loaded until the STOP bit has been
; 	 transmitted from the previous TXREG->TSR load/transmission
;
;	-ASYNCHRONOUS MASTER TRANSMISSION (BACK TO BACK)
;	 Quand TSR et TXREG sont vides, TXIF va engendrer un ISR
;	 pour envoyer un nouveau char via USART. Ensuite, le TXIF
;	 va tres vite devenir HIGH, donc 2 chars peuvent etre envoye
;	 "back to back"
;
;	-Pour afficher ASCII, il faut taper 'char' ou A'char'
;	 comme operand
;
;	-movf will affect STATUS bits (the Z bit) swapf will not.
; 	 raison pour laquelle on utilise SWAPF au lieu de MOVF pour
;	 la sauvegarde du contexte (ISR)
;
;	-TXREG = USART Transmit Data Register
; 	 RCREG = USART Receive Data Register
; ***********************************************************

; ------------------------------------------------------------
;					variables/constantes
; ------------------------------------------------------------

	 W_TEMP 		EQU 0x70 	; pour context sauvegarde (ISR)
	 STATUS_TEMP 	EQU 0x71 	; pour context sauvegarde (ISR)
	 ;PCLATH_TEMP 	EQU 0x72    ; necessaire si plusieurs pages memoires programmes
								; sont utilises
 	 TENSION_BRUTE 	EQU 0x73	; registre en memoire qui contient le resultat
 								; binaire (tension) de l'ADC
	 X_VAL_SPBRG 	EQU D'25' 	; prescaler valeur pour le baud-rate generateur
	 VIRGULE_ASCII	EQU 0x2C

; -----------------------------------------------------------
;					configuration du uC
; -----------------------------------------------------------

	list p=16f877

	; Inclure le fichier de description des d�finitions du 16f877
	include "p16f877.inc"

	; PIC16F877 Configuration Bit Settings
	; Assembly source line config statements
	; CONFIG
	; __config 0xFF39
	__CONFIG _FOSC_XT & _WDTE_OFF & _PWRTE_OFF & _CP_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _WRT_ON

	org			0x000			; Commencer au RESET vector
	clrf		PCLATH			; 1ere page memoire programme selectionne
 	goto 		config			; commencer la figuration des perihperiques, etc.

; -----------------------------------------------------------
;				Interrupt service routine (ISR)
; -----------------------------------------------------------

	org 		0x004 			; interrupt vector location pour le PIC uC
	movwf 		W_TEMP 			; Copy W to TEMP register
	swapf 		STATUS, W 		; Swap status to be saved into W

	; cette instruction n'est pas necessaire car tous les X_TEMPs registres
	; sont communs pour toutes les pages de RAM
	clrf 		STATUS 			; selectionner bank 0, regardless of current bank
								; Clears IRP,RP1,RP0

	movwf 		STATUS_TEMP 	; Save status to bank zero STATUS_TEMP register

	; ces instructions ne sont pas necessaire car seulement la 1ere page mem program
	; est utilise dans ce programme
	;movf 		PCLATH, W 		; Only required if using pages 1, 2 and/or 3
	;movwf		PCLATH_TEMP 	; Save PCLATH into W
	;clrf 		PCLATH 			; Page zero, regardless of current page

	; investiguer le status des flags pour determiner la source de l'interruption
	banksel		PIR1			; PIR1 contient les flag bits pour les perihiques
	btfsc 		PIR1, TXIF 		; si le transmit empty flag est allume,
								; envoyer un nouveau char
	call 		TXIF_callback

	; au cas ou le ISR programme change de banc
	; cette instruction n'est pas necessaire car tous les X_TEMPs registres
	; sont communs pour toutes les pages de RAM
	clrf 		STATUS 			; selectionner bank 0, regardless of current bank
								; Clears IRP,RP1,RP0

	; ces instructions ne sont pas necessaire car seulement la 1ere page mem program
	; est utilise dans ce programme
	;movf 		PCLATH_TEMP, W 	; Restore PCLATH
	;movwf 		PCLATH 			; Move W into PCLATH

	swapf 		STATUS_TEMP,W 	; Swap STATUS_TEMP register into W
	 							; (sets bank to original state)
	movwf 		STATUS 			; Move W into STATUS register
	swapf 		W_TEMP,F 		; Swap W_TEMP
	swapf 		W_TEMP,W 		; Swap W_TEMP into W
	retfie						; return from interrupt!

; -----------------------------------------------------------
;	configuration de l'ADC (entry point for configuration)
; -----------------------------------------------------------

config	banksel ADCON1
		movlw	B'00001110'		; Left justify,1 analog channel
		movwf	ADCON1			; VDD and VSS references

		banksel ADCON0
		movlw	B'01000001'		; Fosc/8, A/D enabled
		movwf	ADCON0

; -----------------------------------------------------------
;	configuration de l'usart (mode asynchronous full-duplex)
; -----------------------------------------------------------

; configure les entrees/sorties de l'usart (RC6/TX/CK and RC7/RX/DT)
;   pas certain si ceci est necessaire ou si le perihperique configure
;	deja input/output
	banksel		TRISC
	bcf 		TRISC, TRISC6	; TXUSART EST OUTPUT (RC6 -> sortie)
	bsf 		TRISC, TRISC7 	; RXUSART EST INPUT (RC7 -> entree)

; configure le baud-rate de l'usart
; Utilisation de HIGH SPEED mode (BRGH = 1) pour reduire l'erreur sur le baud rate
; formule du baud rate = (Asynchronous) Baud Rate = FOSC/(16(X+1)) ou X  est la
; valeur du registre SPBRG et est de 0...255
; nous voulons 9600 baud avec un FOSC de 4 MHz, ca donne X = 25
	banksel 	SPBRG
	movlw		X_VAL_SPBRG
	movwf 		SPBRG

; mettre en route le peripherique en mode asynchrone
	banksel 	TXSTA
	bcf 		TXSTA, SYNC 	; mettre en mode asynchrone (sync OFF)
	bsf 		TXSTA, BRGH 	; mettre en mode high speed pour reduire l'erreur
	bcf 		TXSTA, TX9  	; mettre en 8-bit transmission mode
	bcf 		TXSTA, TXEN  	; mettre en route la transmission

	banksel 	RCSTA
	bsf 		RCSTA, SPEN 	; peripherique serie est "enabled"

; mettre en route les interruptions
	; USART interrupt flags enable
	banksel 	PIE1
	bsf 		PIE1, TXIE		; enable le interrupt flag pour
								; le registre de transfert USART
	; USART interrupt and interrupt enable bit
	banksel		INTCON
	bsf 		INTCON, PEIE 	; perihique interrupt enable

	; **apres que TOUT est configure, cette instruction peux etre execute**
	bsf 		INTCON, GIE	 	; global interrupt enable

; -----------------------------------------------------------
;			programme principal (boucle infinie)
; -----------------------------------------------------------
main	nop
		goto 	main
		end 					; fin du programme (directive d'assemblage)

; -----------------------------------------------------------
;			sous-programme: lire tension de l'ADC
; -----------------------------------------------------------

start	bsf 	ADCON0,GO		; demarrage de la conversion
non		btfsc	ADCON0,GO		; attendre la fin de conversion
		goto	non
oui		movf	ADRESH,W		; mettre resultat (8 bits de poids fort)
								; de la conversion au reg de travail
		movwf	TENSION_BRUTE	; sauvegarder resultat (tension) en memoire
		goto 	start			; boucler sur la procedure de lecture

; -----------------------------------------------------------
;	sous-programme d'envoyer une lettre via USART
; -----------------------------------------------------------

TXIF_callback	movlw	A'a' 	; move the ASCII code of "a" to w
				movwf	TXREG 	; write to USART transfer register

				return			; return to ISR or whoever called this subprogram

; -----------------------------------------------------------
;	sous-programme de faire le transcodage ASCII
; -----------------------------------------------------------
