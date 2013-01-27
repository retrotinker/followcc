.PHONY: all clean

CFLAGS=-Wall

TARGETS=followme.bin followme.s19 followme.wav
EXTRA=followme.ram

all: $(TARGETS)

%.bin: %.asm
	mamou -mb -tb -l -y -o$@ $<

%.s19: %.asm
	mamou -mb -ts -l -y -o$@ $<

%.ram: %.asm
	mamou -mr -tb -l -y -o$@ $<

followme.wav: followme.ram
	makewav -r -nFOLLOWME -2 -a -d0x000e -e0x000e -o$@ $<

clean:
	$(RM) $(TARGETS) $(EXTRA)
