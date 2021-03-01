# NUAA 汇编课程设计

## 简介
本项目为南航汇编语言课程的课程设计，使用汇编语言制作了一个简单的加载器，并编写了一个简单的 kernel ，实现了简单的图形界面和工作程序加载。

## 开发环境

- IDE：vscode
- 编译器：nasm
- 虚拟机：qemu
- 构建工具：make
- 项目管理：git
- 辅助工具：dd, hexf, gdb

本项目在 macOS 下开发，采用 unix 工具链，通过 vscode 编辑好代码后使用 makefile 中的指令进行编译运行，构建镜像文件，最后通过 qemu 启动

## 开发运行

请参考 Makefile 中的命令

## 课设报告

[report](汇编课设报告.md)