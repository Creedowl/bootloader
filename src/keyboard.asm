OS_GetKey:
	mov ah, 0x11
	int 0x16

	jnz .key_pressed

	hlt
	jmp OS_GetKey

.key_pressed:
	mov ah, 0x10
	int 0x16
	ret