AS      = nasm
CC      = gcc
ASFLAGS = -f elf64 -g -F dwarf
CFLAGS  = -no-pie
LIBS    = -lm -lpcre2-8
TARGET  = echelon

all: $(TARGET)

$(TARGET): echelon.o
	$(CC) -o $(TARGET) echelon.o $(CFLAGS) $(LIBS)

echelon.o: echelon.asm
	$(AS) $(ASFLAGS) echelon.asm

release: $(TARGET)
	strip $(TARGET)

clean:
	rm -f *.o *.lst $(TARGET)

.PHONY: all clean release
