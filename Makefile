.PHONY: all clean

CFLAGS=-Wall

TARGETS=followme.bin followme.s19 followme.wav followme.dsk followme.ccc
EXTRA=followme.2k followme.4k followme.8k followme.16k followme.32k

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

followme.dsk: followme.bin COPYING
	rm -f $@
	decb dskini $@
	decb copy -2 -b $< $@,$$(echo $< | tr [:lower:] [:upper:])
	decb copy -3 -a -l COPYING $@,COPYING

followme.2k: followme.ccc
	rm -f $@
	dd if=/dev/zero bs=2k count=1 | \
		tr '\000' '\377' > $@
	dd if=$< of=$@ conv=notrunc

followme.4k: followme.2k
	cat $< > $@
	cat $< >> $@

followme.8k: followme.4k
	cat $< > $@
	cat $< >> $@

followme.16k: followme.8k
	cat $< > $@
	cat $< >> $@

followme.32k: followme.16k
	cat $< > $@
	cat $< >> $@

clean:
	$(RM) $(TARGETS) $(EXTRA)
