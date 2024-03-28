;;! target = "aarch64"
;;! test = "compile"

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
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       fcvtzs  v0.4s, v0.4s
;;       ldp     x29, x30, [sp], #0x10
;;       ret
;;
;; wasm[0]::function[1]:
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       fcvtzu  v0.4s, v0.4s
;;       ldp     x29, x30, [sp], #0x10
;;       ret
;;
;; wasm[0]::function[2]:
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       fcvtzs  v6.2d, v0.2d
;;       sqxtn   v0.2s, v6.2d
;;       ldp     x29, x30, [sp], #0x10
;;       ret
;;
;; wasm[0]::function[3]:
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       fcvtzu  v6.2d, v0.2d
;;       uqxtn   v0.2s, v6.2d
;;       ldp     x29, x30, [sp], #0x10
;;       ret
;;
;; wasm[0]::function[4]:
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       smull   v16.8h, v0.8b, v1.8b
;;       smull2  v17.8h, v0.16b, v1.16b
;;       addp    v0.8h, v16.8h, v17.8h
;;       ldp     x29, x30, [sp], #0x10
;;       ret
;;
;; wasm[0]::function[5]:
;;       stp     x29, x30, [sp, #-0x10]!
;;       mov     x29, sp
;;       smull   v19.8h, v0.8b, v1.8b
;;       smull2  v20.8h, v0.16b, v1.16b
;;       addp    v19.8h, v19.8h, v20.8h
;;       saddlp  v19.4s, v19.8h
;;       add     v0.4s, v19.4s, v2.4s
;;       ldp     x29, x30, [sp], #0x10
;;       ret
