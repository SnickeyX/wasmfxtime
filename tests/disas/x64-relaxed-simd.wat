;;! target = "x86_64"
;;! test = "compile"
;;! flags = "-Ccranelift-sse41"

(module
  (func (param v128) (result v128)
    local.get 0
    i32x4.relaxed_trunc_f32x4_s
  )

  (func (param v128) (result v128)
    local.get 0
    i32x4.relaxed_trunc_f32x4_u
  )

  (func (param v128) (result v128)
    local.get 0
    i32x4.relaxed_trunc_f64x2_s_zero
  )

  (func (param v128) (result v128)
    local.get 0
    i32x4.relaxed_trunc_f64x2_u_zero
  )

  (func (param v128 v128) (result v128)
    local.get 0
    local.get 1
    i16x8.relaxed_dot_i8x16_i7x16_s
  )

  (func (param v128 v128 v128) (result v128)
    local.get 0
    local.get 1
    local.get 2
    i32x4.relaxed_dot_i8x16_i7x16_add_s
  )
)

;; wasm[0]::function[0]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       cvttps2dq %xmm0, %xmm0
;;       movq    %rbp, %rsp
;;       popq    %rbp
;;       retq
;;
;; wasm[0]::function[1]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       xorps   %xmm1, %xmm1
;;       maxps   %xmm1, %xmm0
;;       pcmpeqd %xmm1, %xmm1
;;       psrld   $1, %xmm1
;;       cvtdq2ps %xmm1, %xmm2
;;       cvttps2dq %xmm0, %xmm1
;;       subps   %xmm2, %xmm0
;;       cmpleps %xmm0, %xmm2
;;       cvttps2dq %xmm0, %xmm0
;;       pxor    %xmm2, %xmm0
;;       pxor    %xmm4, %xmm4
;;       pmaxsd  %xmm4, %xmm0
;;       paddd   %xmm1, %xmm0
;;       movq    %rbp, %rsp
;;       popq    %rbp
;;       retq
;;
;; wasm[0]::function[2]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       cvttpd2dq %xmm0, %xmm0
;;       movq    %rbp, %rsp
;;       popq    %rbp
;;       retq
;;
;; wasm[0]::function[3]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       xorpd   %xmm6, %xmm6
;;       maxpd   %xmm6, %xmm0
;;       minpd   0x1c(%rip), %xmm0
;;       roundpd $3, %xmm0, %xmm0
;;       addpd   0x1e(%rip), %xmm0
;;       shufps  $0x88, %xmm6, %xmm0
;;       movq    %rbp, %rsp
;;       popq    %rbp
;;       retq
;;   8b: addb    %al, (%rax)
;;   8d: addb    %al, (%rax)
;;   8f: addb    %al, (%rax)
;;   91: addb    %ah, %al
;;
;; wasm[0]::function[4]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       movdqa  %xmm0, %xmm7
;;       movdqa  %xmm1, %xmm0
;;       pmaddubsw %xmm7, %xmm0
;;       movq    %rbp, %rsp
;;       popq    %rbp
;;       retq
;;
;; wasm[0]::function[5]:
;;       pushq   %rbp
;;       movq    %rsp, %rbp
;;       pmaddubsw %xmm0, %xmm1
;;       pmaddwd 0xf(%rip), %xmm1
;;       movdqa  %xmm1, %xmm0
;;       paddd   %xmm2, %xmm0
;;       movq    %rbp, %rsp
;;       popq    %rbp
;;       retq
;;   ee: addb    %al, (%rax)
;;   f0: addl    %eax, (%rax)
;;   f2: addl    %eax, (%rax)
;;   f4: addl    %eax, (%rax)
;;   f6: addl    %eax, (%rax)
;;   f8: addl    %eax, (%rax)
;;   fa: addl    %eax, (%rax)
;;   fc: addl    %eax, (%rax)
;;   fe: addl    %eax, (%rax)
