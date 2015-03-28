.PHONY: all clean

CFLAGS=-Wall

TARGETS=followme.bin followme.s19 followme.wav followme.dsk
EXTRA=followme.ram

all: $(TARGETS)

%.bin: %.asm
	lwasm -9 -l -f decb -o $@ $<

%.s19: %.asm
	lwasm -9 -l -f srec -o $@ $<

%.ram: %.asm
	lwasm -9 -l -f raw -o $@ $<

followme.wav: followme.ram
	makewav -r -nFOLLOWME -2 -a -d0x000e -e0x000e -o$@ $<

followme.dsk: followme.bin COPYING
	rm -f $@
	decb dskini $@
	decb copy -2 -b $< $@,$$(echo $< | tr [:lower:] [:upper:])
	decb copy -3 -a -l COPYING $@,COPYING

clean:
	$(RM) $(TARGETS) $(EXTRA)
