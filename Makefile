.PHONY: all clean

CFLAGS=-Wall

TARGETS=cocospin.bin cocospin.s19

all: $(TARGETS)

%.bin: %.asm
	mamou -mb -tb -l -y -o$@ $<

%.s19: %.asm
	mamou -mb -ts -l -y -o$@ $<

.c.o:
	$(CC) $(CFLAGS) -c -o $@ $<
