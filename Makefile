.PHONY: all clean

CFLAGS=-Wall

TARGETS=followme.bin followme.s19 followme.wav followme.dsk

all: $(TARGETS)

%.bin: %.asm
	lwasm -9 -l -f decb -o $@ $<

%.s19: %.asm
	lwasm -9 -l -f srec -o $@ $<

%.wav: %.bin
	cecb bulkerase $@
	cecb copy -2 -b -g $< \
		$(@),$$(echo $< | cut -c1-8 | tr [:lower:] [:upper:])

followme.dsk: followme.bin COPYING
	rm -f $@
	decb dskini $@
	decb copy -2 -b $< $@,$$(echo $< | tr [:lower:] [:upper:])
	decb copy -3 -a -l COPYING $@,COPYING

clean:
	$(RM) $(TARGETS) $(EXTRA)
