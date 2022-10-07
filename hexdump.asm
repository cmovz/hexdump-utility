section .idata

; byte pattern to clean up line
align 16
space_pattern: times 16 db 0x20

hex_table: db '0123456789abcdef'
printable_table:
  db '................................ !"#$%&',"'",'()*+,-./0123456789:;<=>?@AB'
  db 'CDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~.............'
  db '.........................................................................'
  db '...........................................'

; error msgs
usage_msg: db 'Usage: hexdump file_name',0xa
USAGE_MSG_LEN: equ $ - usage_msg
open_err_msg: db 'Failed to open file',0xa
OPEN_ERR_MSG_LEN: equ $ - open_err_msg
stat_err_msg: db 'Failed to query file size',0xa
STAT_ERR_MSG_LEN: equ $ - stat_err_msg
mmap_err_msg: db 'Failed to mmap file',0xa
MMAP_ERR_MSG_LEN: equ $ - mmap_err_msg
write_err_msg: db 'Failed to write',0xa
WRITE_ERR_MSG_LEN: equ $ - write_err_msg


section .bss

align 16
line: resb 81


section .text

global _start
_start:
  mov rdi,[rsp]   ; argc
  cmp rdi,2       ; 2 args: hexdump file_name
  jne .print_usage_err

  lea rdi,[rsp+8] ; argv
  mov rdi,[rdi+8] ; filename: argv[1]
  xor rsi,rsi     ; flags
  xor rdx,rdx     ; mode
  mov rax,2       ; open
  syscall

  cmp rax,0
  jl .print_open_file_err

  mov r12,rax   ; save fd
  sub rsp,144   ; space for struct stat
  mov rdi,r12   ; fd
  mov rsi,rsp   ; ptr to struct stat
  mov rax,5     ; fstat
  syscall

  cmp rax,0
  jne .print_stat_err

  mov r13,[rsp+48]  ; file size
  add rsp,144       ; remove from stack
  xor rdi,rdi       ; addr
  mov rsi,r13       ; len
  mov rdx,1         ; PROT_READ
  mov r10,2         ; MAP_PRIVATE
  mov r8,r12        ; fd
  xor r9,r9         ; offset
  mov rax,9         ; mmap
  syscall

  cmp rax,0
  js .print_mmap_err

  mov r14,rax     ; file mem address
  xor r15,r15     ; loop variable

  ; check if file size is greater than 0
  cmp r15,r13
  je .done

  ; clear line by filling it with spaces, the '|' char and a newline at the end
  xor rbx,rbx   ; zero out the hex index
  mov rbp,60    ; index for printable chars
  movdqa xmm0,[space_pattern]
  movdqa [line],xmm0
  movdqa [line+16],xmm0
  movdqa [line+32],xmm0
  movdqa [line+48],xmm0
  movdqa [line+64],xmm0
  mov byte [line+59],0x7c
  mov byte [line+80],0xa

.main_loop:
  xor rax,rax       ; zero upper register
  mov al,[r14+r15]  ; get byte from file

  mov rcx,rax       ; store byte in rcx
  mov r10,rax;      ; store byte in r10

  shr al,4                ; get high nibble
  mov al,[hex_table+rax]  ; convert high nibble to hex char
  mov [line+rbx],al       ; add hex char to line

  and rcx,0xf             ; get low nibble
  mov cl,[hex_table+rcx]  ; convert low nibble to hex char
  mov [line+rbx+1],cl     ; add hex char to line

  mov r10b,[printable_table+r10]  ; get printable char corresponding to byte
  mov [line+rbp],r10b             ; add printable char to the line

  inc rbp         ; added 1 printable char
  add rbx,3       ; added 2 hex characters + space
  cmp rbx,60      ; check if filled the line already
  jne .end_loop

  ; write line
  mov rdi,1       ; stdout
  mov rsi,line    ; line mem
  mov rdx,81      ; 81 characters
  mov rax,1       ; write
  syscall
  cmp rax,81
  jne .print_write_err

  ; clear line by filling it with spaces, the '|' char and a newline at the end
  xor rbx,rbx   ; zero out the hex index
  mov rbp,60    ; reset the printable char index
  movdqa xmm0,[space_pattern]
  movdqa [line],xmm0
  movdqa [line+16],xmm0
  movdqa [line+32],xmm0
  movdqa [line+48],xmm0
  movdqa [line+64],xmm0
  mov byte [line+59],0x7c
  mov byte [line+80],0xa

.end_loop:
  inc r15
  cmp r15,r13
  jne .main_loop

  ; check if there's a partial line to write
  cmp rbx,0
  je .done

  ; write line
  mov rdi,1       ; stdout
  mov rsi,line    ; line mem
  mov rdx,81      ; 81 characters
  mov rax,1       ; write
  syscall
  cmp rax,81      ; check if wrote everything
  jne .print_write_err

.done:
  xor rdi,rdi     ; exit code 0
  mov rax,60      ; exit 
  syscall

.print_write_err:
  ; maybe it's writing to a file, there's no space
  ; and stderr goes to the terminal
  mov rsi,write_err_msg
  mov rdx,WRITE_ERR_MSG_LEN
  jmp PrintErrorAndExit

.print_mmap_err:
  mov rsi,mmap_err_msg
  mov rdx,MMAP_ERR_MSG_LEN
  jmp PrintErrorAndExit

.print_stat_err: 
  mov rsi,stat_err_msg
  mov rdx,STAT_ERR_MSG_LEN
  jmp PrintErrorAndExit

.print_open_file_err:
  mov rsi,open_err_msg
  mov rdx,OPEN_ERR_MSG_LEN
  jmp PrintErrorAndExit

.print_usage_err:
  mov rsi,usage_msg
  mov rdx,USAGE_MSG_LEN


PrintErrorAndExit:
  ; rsi must contain mem address
  ; rdx must contain length
  mov rdi,2   ; stderr
  mov rax,1   ; write
  syscall

  ; exit
  mov rdi,1   ; error code
  mov rax,60  ; exit
  syscall