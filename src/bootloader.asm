bits 16

jmp StartOfEverything
nop

OEMLabel db "Creedowl"
BytesPerSector dw 512
SectorsPerCluster	db 16
ReservedForBoot dw 1
NumberOfFats db 2
RootDirEntries dw 512 ; 512 * 32 = 32扇区
LogicalSectors dw 32768
MediumByte db 0F0h
SectorsPerFat dw 6
SectorsPerTrack dw 32
Sides 	dw 16
HiddenSectors dd 0
LargeSectors dd 0
DriveNo 	dw 0
Signature db 41
VolumeID dd 0066ccffh
VolumeLabel db "Creedowl   "
FileSystem db "FAT12   "

StartOfEverything:
  ; 准备运行环境
  xor ax, ax
  mov ss, ax
  mov sp, 7C00H ; 设置栈顶
  mov ax, 7C0H
  mov ds, ax ; 设置数据段起始地址，等价于 org 7C00H

  mov si, MoveMyself
  call PrintString

  ; 自身腾挪
  mov ax, 0060H
  mov es, ax
  xor di, di ; 0060H:0000H
  xor si, si
  cld
  mov cx, 100H ; 512 byte
  rep movsw
  push es ; 返回段值入栈
  push Start ; 返回偏移入栈
  retf ; 段间返回到 es:Start

Start:
  mov ax, cs
  mov ds, ax
  mov es, ax ; cs, ds, es都在一个段

  mov si, Welcome
  call PrintString

; 读取fat12根目录
ReadRootDir:
  mov ax, ds
  mov bx, 32
  mov cx, 13 ; 1 (mbr) + 2 (NumberOfFats) * 6 (SectorsPerFat)
  mov dx, Buffer
  call ReadDisk

; 查找内核文件
SearchKernelFile:
  mov cx, [RootDirEntries] ; 查找整个目录，共512项
  mov di, Buffer ; di指向目录地址
  xor ax, ax

.SearchLoop:
  xchg cx, dx ; 交换循环变量，这里cx用于比较文件名
  mov si, KernelFilename ; si指向kernerl.bin的文件名
  mov cx, 11 ; 在fat12中每个目录项占32个字节, 其中文件名加拓展名为头11个字节
  rep cmpsb
  je FoundKernelFile ; 若找到kernel.bin则跳转加载
  add ax, 32 ; 否则比较下一个文件
  mov di, Buffer
  add di, ax
  xchg dx, cx ; 循环比较下一个文件
  loop .SearchLoop
  mov si, KernelNotFound ; 找不到kernel.bin, 重启
  call PrintString
  jmp Reboot

FoundKernelFile:
  mov ax, [di + 0FH] ; 文件第一个簇的偏移为26, 保存
  mov [Cluster], ax

; 加载fat表
ReadFat:
  mov ax, ds
  mov bx, [SectorsPerFat] ; fat扇区数
  mov cx, 1 ; 位于mbr扇区后, 偏移为1
  mov dx, Buffer
  call ReadDisk

  mov ax, 1000H
  mov es, ax

ReadFile:
  xor bx, bx
  mov bl, [SectorsPerCluster] ; bx = 16, 读取扇区数

  xor cx, cx
  mov cl, [DataBase] ; 45

  mov dx, 16
  mov ax, [Cluster]
  sub ax, 2
  mul dx
  add cx, ax ; cx = 起始扇区偏移 = 1 + 32 + 2 * 6 + (cluster - 2) * 16
  mov dx, [Pointer] ; dx = 缓冲区偏移
  mov ax, es ; ax = 缓冲区段值 1000H
  call ReadDisk
  add word [Pointer], 16 ; 已读的扇区

  ; 计算当前簇在fat表中的位置, 每3个byte对应两个簇, cluster * 3 / 2 == 在fat表中的位置
  mov ax, [Cluster]  
  xor dx, dx
  mov bx, 3
  mul bx
  mov bx, 2
  div bx ; dx = cluster mod 2, 用于判断当前簇是奇数位还是偶数位
  mov si, Buffer
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
  jae NewWorld ; 走向新世界
  mov [Cluster], ax ; 否则开始读下一个簇
  jmp ReadFile

; 跳转到kernel
NewWorld:
  jmp 1000H:0000H

  jmp Reboot

; 重启
Reboot:
  mov si, RebootHint
  call PrintString
  mov ax, 0
	int 16H
	mov ax, 0
	int 19H

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
  call PrintString
  jmp Reboot

; IN: si = string
PrintString:
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
ShowRegister:
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

; vars and consts

Cluster dw 0
Pointer dw 0
KernelFilename db "KERNEL  BIN"
MoveMyself db "0060:0000", 0DH, 0AH, 0
Welcome db "Loading kernel", 0DH, 0AH, 0
RebootHint db "Press any key...", 0DH, 0AH, 0
DiskReadError db "E: Disk r", 0DH, 0AH, 0
KernelNotFound db "Kernel not found", 0DH, 0AH, 0
DataBase db 45 ; 数据区起始扇区偏移 = DirBase + 32 (Dir)
DAP:
  db 10H ; DAP大小
  db 0 ; 保留
  dw 0 ; 扇区数
  dw 0 ; 缓冲区偏移
  dw 0 ; 缓冲区段值
  dd 0 ; LBA低4字节
  dd 0 ; LBA高4字节

times  510-($-$$) db 0
db 55H, 0AAH

Buffer: