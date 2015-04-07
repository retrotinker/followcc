.PHONY: all clean

CFLAGS=-Wall

TARGETS=followcc.bin followcc.s19 followcc.wav followcc.dsk followcc.ccc
EXTRA=followcc.2k followcc.4k followcc.8k followcc.16k followcc.32k

all: $(TARGETS)

%.bin: %.asm
	lwasm -9 -l -f decb -o $@ $<

%.s19: %.asm
	lwasm -9 -l -f srec -o $@ $<

%.ccc: %.asm
	lwasm -DROM -9 -l -f raw -o $@ $<

%.wav: %.bin
	cecb bulkerase $@
	cecb copy -2 -b -g $< \
		$(@),$$(echo $< | cut -c1-8 | tr [:lower:] [:upper:])

followcc.dsk: followcc.bin COPYING
	rm -f $@
	decb dskini $@
	decb copy -2 -b $< $@,$$(echo $< | tr [:lower:] [:upper:])
	decb copy -3 -a -l COPYING $@,COPYING

followcc.2k: followcc.ccc
	rm -f $@
	dd if=/dev/zero bs=2k count=1 | \
		tr '\000' '\377' > $@
	dd if=$< of=$@ conv=notrunc

followcc.4k: followcc.2k
	cat $< > $@
	cat $< >> $@

followcc.8k: followcc.4k
	cat $< > $@
	cat $< >> $@

followcc.16k: followcc.8k
	cat $< > $@
	cat $< >> $@

followcc.32k: followcc.16k
	cat $< > $@
	cat $< >> $@

clean:
	$(RM) $(TARGETS) $(EXTRA)
