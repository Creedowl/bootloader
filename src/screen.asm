; 移动光标
; IN: DH=行，DL=列
OS_MoveCursor:
	pusha

	mov bh, 0 ; 第0页
	mov ah, 2
	int 10H

	popa
	ret

; 获取光标位置
; OUT: DH=行，DL=列
OS_GetCursorPos:
  pusha

  mov bh, 0 ; 第0页
  mov ah, 3
  mov [.tmp], dx
  popa
  mov dx, [.tmp]
  ret

  .tmp dw 0

; 清屏
OS_Cls:
	pusha

	mov dx, 0 ; 移动光标到(0, 0)
	call OS_MoveCursor

	mov ah, 6 ; 向上滚动窗口
	mov al, 0 ; 0 清除
	mov bh, 7 ; 背景色和前景色
	mov cx, 0 ; CH=高行数，CL=左列数
	mov dh, 24 ; DH=低行数
	mov dl, 79 ; DL=右列数
	int 10H

	popa
	ret

; 在当前光标位置写入一个字符
; IN: al=字符
OS_PutChar:
  pusha
  mov ah, 0AH
  mov bh, 0
  mov cx, 1
  int 10H

  popa
  ret

; 输入带颜色的字符串，需要先设置好光标位置
; In: si = 字符串地址, bx = 颜色
OS_PrintStringWithColor:
  pusha
  call OS_GetCursorPos ; DH=行，DL=列
  mov ah, 9
  mov bh, 0
.NextChar:
  lodsb
  call OS_MoveCursor
  test al, al
  jz .Finish
  mov cx, 1
  int 10H
  inc dl
  jmp .NextChar
.Finish:
  popa
  ret

OS_HideCursor:
  pusha
  mov ah, 1
  mov ch, 10H
  int 10H
  popa
  ret

OS_ShowCursor:
  pusha
  mov ah, 1
  mov ch, 0
  int 10H
  popa
  ret

; 在top bar上显示时间日期, 来自CMOS
OS_ShowDateTime:
  pusha
  mov cx, 6 ; 年 月 日 时 分 秒
  mov si, .DTOffset ; CMOS中时间信息的布局
  mov di, .DateTime ; 输出格式
.NextTime:
  lodsb ; 加载时间信息偏移
  out 70H, al
  in al, 71H ; 读取一个时间信息
  mov ah, al ; 采用BCD码, 4bit表示一位十进制数, 转换成字符时需要分成两个byte
  shr al, 4 ; 高4位表示低位
  and ax, 0F0FH ; 各取4位
  add ax, 3030H ; 等于两个字符都加上'0'
  mov [di], ax ; 保存字符结果
  add di, 3
  loop .NextTime

  mov dh, 0
  mov dl, 62
  call OS_MoveCursor
  mov si, .DateTime
  call OS_PrintString

  popa
  ret

  .DateTime db "00/00/00 00:00:00", 0
  .DTOffset db 9, 8, 7, 4, 2, 0

; 设置窗口背景
; IN: bx=背景颜色
OS_SetBackground:
  pusha
  push bx ; 保存颜色

  ; 先画个白色的top bar
  xor dx, dx
  call OS_MoveCursor ; 移动光标到(0, 0)
  mov ah, 9
  mov al, ' '
  mov bh, 0
  mov bl, 0F0H
  mov cx, 80
  int 10H

  ; 显示欢迎信息
  xor dx, dx
  call OS_MoveCursor ; 移动光标到(0, 0)
  mov si, .Welcome
  mov bx, 0F8H
  call OS_PrintStringWithColor

  ; 设置窗口主体颜色
  mov dh, 1 ; 移动光标到(1, 0)
  mov dl, 0
  call OS_MoveCursor
  mov ah, 9
  mov al, ' '
  mov cx, 1840 ; 设置第2行至第24行颜色, 共23*80位
  pop bx
  mov bh, 0
  int 10H

  ; 最后画个bottom bar
  mov dh, 24
  mov dl, 0
  call OS_MoveCursor ; 移动光标到(0, 0)
  mov ah, 9
  mov al, ' '
  mov bh, 0
  mov bl, 090H
  mov cx, 80
  int 10H

  ; 显示作者信息
  mov dh, 24
  mov dl, 0
  call OS_MoveCursor ; 移动光标到(24, 0)
  mov si, .Author
  mov bx, 09BH
  call OS_PrintStringWithColor

  ; 移动光标到(1, 0)
  mov dh, 1
  mov dl, 0
  call OS_MoveCursor

  popa
  ret

  .Welcome db " Welcome to Creedowl's kernel", 0
  .Author db " Creedowl @ 2020", 0

; 绘制一个矩形
; IN: ch=左上角的行号, cl=左上角的列号, dh=右下角的行号, dl=右下角的行号, bh=颜色属性
OS_DrawBox:
  pusha

  mov ah, 6
  mov al, 0
  int 10H

  popa
  ret

; 在指定位置写入字符串, 超过宽度后换行
; IN: dh=行, dl=列, si=字符串, bl=宽度
OS_PrintStringWithRange:
  pusha
  mov [.Column], dl
  add bl, dl

  call OS_MoveCursor
  mov ah, 0AH
  mov bh, 0
  mov cx, 1
.NextChar_2:
  lodsb
  test al, al
  jz .Finish_2
  int 10H
  inc dl
  cmp dl, bl
  jne .NextChar_3
  inc dh
  mov dl, [.Column]
.NextChar_3:
  call OS_MoveCursor
  jmp .NextChar_2

.Finish_2:
  popa
  ret

  .Column db 0

; IN: bh=old, bl=new
Highlight:
  pusha
  mov [.Old], bh
  mov [.Current], bl

  mov dh, [.Old]
  mov dl, 16
  call OS_MoveCursor
  mov cx, 46
.NextH_1:
  mov ah, 8
  mov bh, 0
  int 10H
  mov ah, 9
  mov bl, 0F0H
  mov [.Count], cx
  mov cx, 1
  int 10H
  inc dl
  call OS_MoveCursor
  mov cx, [.Count]
  loop .NextH_1

  mov dh, [.Current]
  mov dl, 16
  call OS_MoveCursor
  mov cx, 46
.NextH_2:
  mov ah, 8
  mov bh, 0
  int 10H
  mov ah, 9
  mov bl, 0FH
  mov [.Count], cx
  mov cx, 1
  int 10H
  inc dl
  call OS_MoveCursor
  mov cx, [.Count]
  loop .NextH_2

  popa
  ret
  
  .Old db 0
  .Current db 0
  .Count db 0

OS_DrawFileList:
  pusha

  ; 在(2, 14)到(22, 63)画一个矩形背景
  xor cx, cx
  mov ch, 2
  mov cl, 14

  mov dh, 22
  mov dl, 63
  mov bh, 6FH
  call OS_DrawBox

  ; 显示提示
  mov si, .Tip
  mov dh, 3
  mov dl, 15
  mov bl, 48
  call OS_PrintStringWithRange

  ; 再画一个框用来放文件
  mov ch, 6
  mov cl, 15
  mov dh, 21
  mov dl, 62
  mov bh, 0F0H
  call OS_DrawBox

  mov si, Buffer

  mov dh, 7
  mov dl, 17
.NextFilename:
  mov al, [si]
  test al, al
  je .FinishFilelist
  call OS_MoveCursor
  mov cx, 11
.NextFilenameChar:
  lodsb
  call OS_PutChar
  inc dl
  call OS_MoveCursor
  loop .NextFilenameChar
  add si, 21
  inc dh
  mov dl, 17
  jmp .NextFilename

.FinishFilelist:

  popa
  ret

  .Tip db "Please select a file to load, using the arrow key to select and press enter to load", 0

OS_Select:
  pusha
  mov bh, 7
  mov bl, 7
  call Highlight

.WaitForKey:
  call OS_ShowDateTime
  call OS_GetKey
  cmp ah, 48H ; up
  je .UP
  cmp ah, 50H ; down
  je .DOWN
  cmp al, 13 ; enter
  je .ENTER
  cmp al, 27 ; esc
  je .ESC
  jmp .WaitForKey

.UP:
  mov al, [.Pos]
  cmp al, 7
  jle .WaitForKey
  mov bh, al
  dec al
  mov bl, al
  call Highlight
  mov [.Pos], al
  jmp .WaitForKey

.DOWN:
  mov al, [.Pos]
  cmp al, 20
  jge .WaitForKey
  mov bh, al
  inc al
  mov bl, al
  call Highlight
  mov [.Pos], al
  jmp .WaitForKey

.ENTER:
  mov al, [.Pos]
  sub al, 7
  mov bl, 32
  mul bl
  mov si, Buffer
  cbw
  add si, ax
  mov ax, [si + 26]
  call OS_ReadFile

  call OS_Cls
  call OS_ShowCursor
  mov dh, 0
  mov dl, 0
  call OS_MoveCursor

  mov ax, 2000H
  mov es, ax
  mov di, 0
  pusha
  call 2000H
  popa

.ESC:
  mov al, 7
  mov [.Pos], al
  popa
  ret

  .Pos db 7
