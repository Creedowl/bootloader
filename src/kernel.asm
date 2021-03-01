bits 16

; 模拟系统调用
OS:
  jmp OS_Main ; 0000H
  jmp OS_Reboot ; 0003H
  jmp OS_PrintString ; 0006H
  jmp OS_MoveCursor ; 0009H
  jmp OS_Cls ; 000CH
  jmp OS_GetCursorPos ; 000FH
  jmp OS_SetBackground ; 0012H
  jmp OS_PrintStringWithColor ; 0015H
  jmp OS_HideCursor ; 0018H
  jmp OS_ShowCursor ; 001BH
  jmp OS_GetFilelist ; 001EH
  jmp OS_DrawBox ; 0021H
  jmp OS_DrawFileList ; 0024H
  jmp OS_ShowDateTime ; 0027H
  jmp OS_PutChar ; 002AH
  jmp OS_GetKey ; 002DH
  jmp OS_ReadFile ; 0030H
  jmp OS_ShowRegister ; 0033H
  jmp OS_Wait ; 0036H

  db 255 dup(0) ; 保证上述jmp指令的宽度都是3byte

OS_Main:
  xor ax, ax
  mov ss, ax
  mov sp, 0FFFFH
  mov ax, cs
  mov ds, ax
  mov es, ax
  
  call OS_GetFilelist ; 获取文件列表
  call OS_HideCursor ; 隐藏光标

  mov bx, 030H
  call OS_SetBackground ; 设置背景
  call OS_ShowDateTime ; 显示时间

  call OS_DrawFileList

  call OS_Select

  jmp OS_Reboot

  jmp $


; 输出字符串
; IN: si = string
OS_PrintString:
  pusha
  mov ah, 0EH ; tty mode
.repeat:
  lodsb
  test al, al
  jz .done
  int 10H
  jmp .repeat
.done:
  popa
  ret

; In: bx = register value to print
OS_ShowRegister:
  pusha
  mov ah, 0EH ; tty mode
  mov al, '0'
  int 10H
  mov al, 'x'
  int 10H
  mov cx, 4
.ShowLoop:
  rol bx, 4
  mov al, bl
  and al, 0FH
  add al, '0'
  cmp al, '9'
  jle .Be
  add al, 7
.Be:
  int 10H
  loop .ShowLoop
  mov al, 0DH
  int 10H
  mov al, 0AH
  int 10H
  popa
  ret

OS_Reboot:
  call OS_Cls
  mov si, RebootHint
  call OS_PrintString
  call OS_Wait
	mov ax, 0
	int 19H

OS_Wait:
  pusha
  mov ax, 0
	int 16H
  popa
  ret

; vars and consts

RebootHint db "Press any key to reboot...", 0DH, 0AH, 0

%INCLUDE "src/screen.asm"
%INCLUDE "src/disk.asm"
%INCLUDE "src/keyboard.asm"

Buffer:
