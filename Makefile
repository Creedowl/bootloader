SRCDIR = ./src
BUILDDIR = ./build
DISK = $(BUILDDIR)/disk.dmg
NASM_BUILD = nasm -w+orphan-labels -f bin
BOOTLOADER = $(SRCDIR)/bootloader.asm
TEMPFILE = $(BUILDDIR)/temp.xxxx
PROGRAMS := $(wildcard $(SRCDIR)/program/*.asm)
PROGRAMSBIN := $(PROGRAMS:$(SRCDIR)/program/%.asm=$(BUILDDIR)/program/%.bin)

$(shell mkdir -p $(BUILDDIR)/program)

.PHONY:
run: $(BUILDDIR)/bootloader.bin $(BUILDDIR)/kernel.bin
	qemu-system-i386 -drive format=raw,file=$(DISK),media=disk -monitor stdio

.PHONY:
debug: $(BUILDDIR)/bootloader.bin $(BUILDDIR)/kernel.bin
	qemu-system-i386 -s -S -drive format=raw,file=$(DISK),media=disk -monitor stdio

$(BUILDDIR)/program/%.bin: $(SRCDIR)/program/%.asm
	$(NASM_BUILD) $< -o $@

$(BUILDDIR)/kernel.bin: $(SRCDIR)/kernel.asm $(BUILDDIR)/bootloader.bin $(PROGRAMSBIN)
	$(NASM_BUILD) $< -o $(BUILDDIR)/kernel.bin
	mktemp -d $(TEMPFILE)
	$(eval dev = $(shell hdiutil attach -nobrowse -nomount $(DISK)))
	mount -t msdos $(dev) $(TEMPFILE)
	rm -rf $(TEMPFILE)/*
	cp $(BUILDDIR)/kernel.bin $(TEMPFILE)/
	cp $(BUILDDIR)/program/*.bin $(TEMPFILE)/
	diskutil umount $(dev)
	hdiutil detach $(dev)
	rm -rf $(TEMPFILE)

$(BUILDDIR)/bootloader.bin: $(SRCDIR)/bootloader.asm createImg
	$(NASM_BUILD) $< -o $(BUILDDIR)/bootloader.bin
	dd if=$(BUILDDIR)/bootloader.bin of=$(DISK) conv=notrunc

.PHONY:
createImg:
  ifeq (, $(wildcard $(DISK))) 
		hdiutil create -fs "MS-DOS FAT12" -size 16m -layout None $(DISK)
  endif
	# rm -f $(DISK)
	# hdiutil create -fs "MS-DOS FAT12" -size 16m -layout None $(DISK)

# createImg:
# 	dd if=/dev/zero of=$(DISK) conv=sync bs=1m count=16
# 	$(eval dev = $(shell hdiutil attach -nobrowse -nomount $(DISK)))
# 	echo $(dev)
# 	newfs_msdos -F 12 -v disk	$(dev)
# 	hdiutil detach $(dev)

.PHONY:
clean:
	rm -rf $(BUILDDIR)/*

.PHONY:
cleanall:
	rm -rf $(BUILDDIR)
