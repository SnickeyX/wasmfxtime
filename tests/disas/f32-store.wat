;;! target = "x86_64"

;; Test basic code generation for f32 memory WebAssembly instructions.

(module
  (memory 1)
  (func (export "f32.store") (param i32 f32)
    local.get 0
    local.get 1
    f32.store))

;; function u0:0(i64 vmctx, i64, i32, f32) fast {
;;     gv0 = vmctx
;;     gv1 = load.i64 notrap aligned readonly gv0+8
;;     gv2 = load.i64 notrap aligned gv1
;;     gv3 = vmctx
;;     gv4 = load.i64 notrap aligned readonly checked gv3+80
;;     sig0 = (i64 vmctx, i32 uext, i32 uext, i32 uext) -> i32 uext system_v
;;     sig1 = (i64 vmctx, i32 uext, i32 uext) -> i32 uext system_v
;;     sig2 = (i64 vmctx, i32 uext) -> i32 uext system_v
;;     stack_limit = gv2
;;
;;                                 block0(v0: i64, v1: i64, v2: i32, v3: f32):
;; @002c                               v4 = global_value.i64 gv3
;; @002c                               v5 = load.i64 notrap aligned v4+8
;; @0031                               v6 = uextend.i64 v2
;; @0031                               v7 = global_value.i64 gv4
;; @0031                               v8 = iadd v7, v6
;; @0031                               store little heap v3, v8
;; @0034                               jump block1
;;
;;                                 block1:
;; @0034                               return
;; }
