nasm -felf64 hexdump.asm -o hexdump.o
ld -o hexdump hexdump.o --strip-all
rm hexdump.o