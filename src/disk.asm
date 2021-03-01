
OS_GetFilelist:
  pusha

  mov ax, ds
  mov bx, 32
  mov cx, 13 ; 1 (mbr) + 2 (NumberOfFats) * 6 (SectorsPerFat)
  mov dx, [FileBuffer]
  call ReadDisk

  call ReadFat

; 查找根目录中的普通文件
SearchValidFiles:
  mov cx, 512 ; 查找整个目录，共512项
  mov si, [FileBuffer] ; di指向目录地址
  mov di, Buffer


.SearchLoop:
  xchg cx, dx ; 交换循环变量，这里cx用于比较文件名
  
  mov al, [si] ; 目录项头一字节
  test al, al ; 不是文件
  je .Skip

  cmp al, 0E5H ; 文件删除标记
  je .Skip

  mov al, [si + 11] ; 文件属性
  cmp al, 20H ; 普通文件
  jne .Skip

  mov cx, 8
  rep movsd
  jmp .NextEntry

.Skip
  add si, 32
.NextEntry
  xchg dx, cx ; 循环查找下一个文件
  loop .SearchLoop

  popa
  ret

; 加载fat表
ReadFat:
  pusha
  mov ax, ds
  mov bx, 6 ; fat扇区数
  mov cx, 1 ; 位于mbr扇区后, 偏移为1
  mov dx, [FatBuffer]
  call ReadDisk

  popa
  ret

; IN: ax=簇号
OS_ReadFile:
  pusha
  mov [Cluster], ax
  mov bx, 16
  mov cx, 45
  mov dx, 16
  mov ax, [Cluster]
  sub ax, 2
  mul dx
  add cx, ax ; cx = 起始扇区偏移 = 1 + 32 + 2 * 6 + (cluster - 2) * 16
  mov dx, [Pointer] ; dx = 缓冲区偏移
  mov ax, ds ; ax = 缓冲区段值 2000H
  call ReadDisk
  add word [Pointer], 16 ; 已读的扇区

  ; 计算当前簇在fat表中的位置, 每3个byte对应两个簇, cluster * 3 / 2 == 在fat表中的位置
  mov ax, [Cluster]  
  xor dx, dx
  mov bx, 3
  mul bx
  mov bx, 2
  div bx ; dx = cluster mod 2, 用于判断当前簇是奇数位还是偶数位
  mov si, [FatBuffer]
  add si, ax
  mov ax, [si]
  test dx, dx
  jz .Even

.Odd:
  ; 奇数位时要抛弃前4bit
  shr ax, 4
  jmp .NextCluster

.Even:
  ; 偶数位时取低12bit
  and ax, 0FFFH

.NextCluster:
  cmp ax, 0FF8H ; 当簇的值大于0xFF8时说明到达文件结尾
  mov bx, ax
  call OS_ShowRegister
  ; jmp $
  jae .Done ; 
  mov [Cluster], ax ; 否则开始读下一个簇
  jmp OS_ReadFile

.Done:
  popa
  ret

  Cluster dw 0
  Pointer dw 2000H

; IN: ax = 缓冲区段值, bx = 读取扇区数, cx = 起始扇区号LBA低4字节, dx = 缓冲区偏移
ReadDisk:
  pusha
  mov [DAP + 6], ax ; 缓冲区段值
  mov [DAP + 4], dx ; 缓冲区偏移
  mov [DAP + 2], bx ; 读取扇区数
  movzx ecx, cx
  mov [DAP + 8], ecx ; 起始扇区号LBA低4字节
  mov si, DAP ; 加载DAP
  mov dl, 80H ; 读取c盘(默认磁盘)
  mov ah, 42H
  int 13H
  jc DiskError ; 读取出错处理
  popa
  ret

DiskError:
  mov si, DiskReadError
  call OS_PrintString
  jmp OS_Reboot

DiskReadError db "Read disk error", 0DH, 0AH, 0

DAP:
  db 10H ; DAP大小
  db 0 ; 保留
  dw 0 ; 扇区数
  dw 0 ; 缓冲区偏移
  dw 0 ; 缓冲区段值
  dd 0 ; LBA低4字节
  dd 0 ; LBA高4字节

FileBuffer dw 3000H
FatBuffer dw 7000H
