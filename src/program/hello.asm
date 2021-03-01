bits 16

org 2000H

HelloWorld:
  mov dh, 5
  mov dl, 10
  mov ax, 9
  call ax

  mov si, Hello
  mov bx, 43
  mov ax, 15H
  call ax

  mov ax, 36H
  call ax

  ret

  Hello db "Hello world", 0
