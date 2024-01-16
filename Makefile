AS=$(shell which as16)

OUTDIR=$(shell pwd)
SOURCE_LUT=lut.s
SOURCES=artillery.s 
ROM=$(OUTDIR)/artillery.c16
SYMS=$(OUTDIR)/artillery.sym
MMAP=$(OUTDIR)/mmap.txt

all: $(ROM) $(SYMS) $(MMAP)

$(SYMS): $(ROM)

$(MMAP): $(ROM)

$(ROM): $(SOURCES) $(SOURCE_LUT)
	$(AS) $< -o $@ -m

$(SOURCE_LUT): $(OUTDIR)/lut
	$(^) > $@

$(OUTDIR)/lut: lut.c
	gcc $< -o $@ -ggdb3 -O0 -lm

clean:
	rm -f $(ROM) $(MMAP) $(SYMS) $(OUTDIR)/lut $(SOURCE_LUT)
