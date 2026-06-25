(module $tests

  (memory 8)

  (func $buf2float (export "buf2float")
    (param $buf i32)
    (param $len i32)

    (result f32 i32)

    ;; result:
    ;;   f32: the value or 0 on no data
    ;;   i32: valid(0 if invalid, non-0 if valid)

    local.get $len
    i32.const 2
    i32.shr_u
    i32.eqz
    if
      f32.const 0.0
      i32.const 0
      return
    end

    local.get $buf
    f32.load
    i32.const 1
  )

  (func $t0a (export "t0a_buf2float_empty") (result i32)
    (local $ret i32)
    (local $val f32)

    i32.const 0 ;; dummy
    i32.const 0
    call $buf2float
    local.set $ret
    local.set $val

    local.get $ret
    i32.const 0
    i32.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t0b (export "t0b_buf2float_too_small") (result i32)
    (local $ret i32)
    (local $val f32)

    i32.const 0 ;; dummy
    i32.const 3
    call $buf2float
    local.set $ret
    local.set $val

    local.get $ret
    i32.const 0
    i32.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t0c (export "t0c_buf2float_single") (result i32)
    (local $ret i32)
    (local $val f32)

    i32.const 0x0001_0000
    f32.const 1013.25
    f32.store

    i32.const 0x0001_0000
    i32.const 4
    call $buf2float
    local.set $ret
    local.set $val

    local.get $ret
    i32.eqz
    if
      i32.const 1
      return
    end

    local.get $val
    f32.const 1013.25
    f32.ne
    if
      i32.const 8
      return
    end

    i32.const 0
  )

  (func $clamp4f32lxh (param $l f32) (param $x f32) (param $h f32) (result f32)
    local.get $l
    local.get $x
    f32.max
    local.get $h
    f32.min
  )

  (func $clampf (export "clampf")
    (param $x f32) (param $l f32) (param $h f32) (result f32)
    local.get $l
    local.get $x
    local.get $h
    call $clamp4f32lxh
  )

  (func $signf (export "signf") (param $x f32) (result f32)
    f32.const 1.0
    local.get $x
    f32.copysign
  )

  ;; logistic func: l(x) = 1 / (1 + exp(-x))
  ;;   l(0) = 1 / (1+1) = 0.5
  ;; approx 2: a2(x) = axx + bx + c | x: 0~4
  ;;   a2(0) = c = 0.5
  ;;   a2(x) = axx + bx + 0.5 = x(ax + b) + 0.5
  ;;   a2'(x) = 2ax + b
  ;;   a2'(4) ~ 0 = 2a 4 + b = 8a + b
  ;;   b = -8a
  ;;   a2(x) = x(ax - 8a) + 0.5 = ax(x-8) + 0.5
  ;;   a2(4) ~ 1 = 4a(4-8) + 0.5 = -16a + 0.5
  ;;           0 = -16a - 0.5
  ;;           0 = 16a + 0.5
  ;;           0 = 32a + 1
  ;;           a = -1/32
  ;;   a2(x) = -x(x-8)/32 + 0.5 = x(8-x)/32 + 0.5
  ;;         = 8x/32 - xx/32 + 0.5
  ;;         = 0.25x - 0.03125xx + 0.5
  ;;
  ;; l(x) = 1 / (1 + exp(-x))
  ;; (1+exp(-x))l(x) = 1
  ;; 1+exp(-x) = 1/l(x)
  ;; exp(-x) = 1/l(x)-1
  ;;
  ;; l(-x) = 1 / (1 + exp(-(-x)))
  ;;       = 1 / (1 + exp(x)))
  ;;       = exp(-x) / (exp(-x) + 1)
  ;;       = (1/l(x)-1) / (1/l(x)-1 + 1)
  ;;       = (1/l(x)-1) / (1/l(x))
  ;;       = l(x)(1/l(x)-1)
  ;;       = 1 - l(x) = -l(x) + 1
  ;;
  ;; l(0) = 0.5
  ;; l(x) |  0<x<=4 ~ a2(x)
  ;; l(x) | -4<x< 0 ~ 1-a2(-x) = 1-a2(abs(x))
  ;; A2(x) := a2(abs(x))
  ;; l(x) | -4<=x<=4 ~ ((x>0)*1)a2(abs(x)) + ((x<0)*1)(1-a2(abs(x)))
  ;;                 = 0.5(1+sign(x))A2(x) + 0.5(1-sign(x))(1-A2(x))
  ;;                 = 0.5a2(x) + 0.5sign(x)A2(x) + 0.5(1-A2(x)) - 0.5sign(x)(1-A2(x))
  ;;                 = sign(x)(0.5a2(x) - 0.5(1-A2(x))) + 0.5a2(x) + 0.5 - 0.5a2(x)
  ;;                 = sign(x)(0.5a2(x) - 0.5 + 0.5a2(x)) + 0.5
  ;;                 = sign(x)(A2(x)-0.5) + 0.5

  (func $logistic4f (export "logit4") (param $x f32) (result f32)
    (local $cx f32) ;; clamped x(-4<=x<=4)
    (local $ax f32) ;; abs cx
    (local $sx f32) ;; sign x

    local.get $x
    call $signf
    local.set $sx

    local.get $x
    f32.const -4.0
    f32.const 4.0
    call $clampf
    local.tee $cx
    f32.abs
    local.tee $ax

    f32.const 0.25
    f32.mul
    f32.const 0.5
    f32.add
    local.get $ax
    local.get $ax
    f32.mul
    f32.const -0.03125
    f32.mul
    f32.add
    f32.const -0.5
    f32.add
    local.get $sx
    f32.mul
    f32.const 0.5
    f32.add
  )

  (func $io_fd_read_mock_empty
    (param $fd i32)
    (param $iovec_ptr i32)
    (param $num_vecs i32)
    (param $bread_ptr i32)
    (result i32)

    local.get $iovec_ptr
    i32.load offset=4
    i32.const 4
    i32.ne
    if
      unreachable
    end

    local.get $bread_ptr
    i32.const 0
    i32.store

    i32.const 0
  )

  (func $io_fd_read_mock_3bytes
    (param $fd i32)
    (param $iovec_ptr i32)
    (param $num_vecs i32)
    (param $bread_ptr i32)
    (result i32)

    local.get $iovec_ptr
    i32.load offset=4
    i32.const 4
    i32.ne
    if
      unreachable
    end

    local.get $bread_ptr
    i32.const 3
    i32.store

    i32.const 0
  )

  (func $io_fd_read_mock_4bytes
    (param $fd i32)
    (param $iovec_ptr i32)
    (param $num_vecs i32)
    (param $bread_ptr i32)
    (result i32)

    local.get $iovec_ptr
    i32.load offset=4
    i32.const 4
    i32.ne
    if
      unreachable
    end

    local.get $bread_ptr
    i32.const 4
    i32.store

    local.get $iovec_ptr i32.load offset=0
    f32.const 299792458.0
    f32.store

    i32.const 0
  )

  (table $fd_read_table (export "table") 3 funcref)

  (elem
    (table $fd_read_table)
    (i32.const 0)

    $io_fd_read_mock_empty
    $io_fd_read_mock_3bytes
    $io_fd_read_mock_4bytes
  )

  (global $IO_FD_READ_MOCK_EMPTY  i32 (i32.const 0))
  (global $IO_FD_READ_MOCK_3BYTES i32 (i32.const 1))
  (global $IO_FD_READ_MOCK_4BYTES i32 (i32.const 2))

  (global $STDIN i32 (i32.const 0))
  (global $STDOUT i32 (i32.const 1))
  (global $STDERR i32 (i32.const 2))

  (global $FD_READ_IOVEC_PTR i32 (i32.const 0x0001_0000))
  (global $FD_READ_IOBUF_PTR i32 (i32.const 0x0002_0000))
  (global $FD_READ_BREAD_PTR i32 (i32.const 0x0003_0000))

  (global $FD_WRIT_IOVEC_PTR i32 (i32.const 0x0004_0000))
  (global $FD_WRIT_IOBUF_PTR i32 (i32.const 0x0005_0000))
  (global $FD_WRIT_BWRIT_PTR i32 (i32.const 0x0006_0000))

  (type $io_fd_read_type (func (param i32 i32 i32 i32) (result i32)))

  (func $fd2float
    (param $tab i32)
    (param $fd i32)
    (param $iovec_ptr i32)
    (param $iobuf_ptr i32)
    (param $bread_ptr i32)
    (result f32 i32)

    (local $ret i32)

    ;; setup the iovec
    local.get $iovec_ptr
    local.get $iobuf_ptr
    i32.store
    local.get $iovec_ptr
    i32.const 4 ;; float = 4 bytes
    i32.store offset=4

    local.get $fd
    local.get $iovec_ptr
    i32.const 1 ;; single buffer
    local.get $bread_ptr
    local.get $tab
    call_indirect $fd_read_table (type $io_fd_read_type)
    local.tee $ret
    i32.const 0
    i32.ne
    if
      f32.const 0.0
      local.get $ret
      return
    end

    local.get $iobuf_ptr
    local.get $bread_ptr
    i32.load
    call $buf2float
  )

  (func $t10 (export "t10_fd2float_empty") (result i32)
    (local $valid i32)
    (local $value f32)

    global.get $IO_FD_READ_MOCK_EMPTY
    global.get $STDIN
    global.get $FD_READ_IOVEC_PTR
    global.get $FD_READ_IOBUF_PTR
    global.get $FD_READ_BREAD_PTR
    call $fd2float
    local.set $valid
    local.set $value

    local.get $valid
    i32.const 0
    i32.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t11 (export "t11_fd2float_3bytes") (result i32)
    (local $valid i32)
    (local $value f32)

    global.get $IO_FD_READ_MOCK_3BYTES
    global.get $STDIN
    global.get $FD_READ_IOVEC_PTR
    global.get $FD_READ_IOBUF_PTR
    global.get $FD_READ_BREAD_PTR
    call $fd2float
    local.set $valid
    local.set $value

    local.get $valid
    i32.const 0
    i32.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

  (func $t12 (export "t12_fd2float_4bytes") (result i32)
    (local $valid i32)
    (local $value f32)

    global.get $IO_FD_READ_MOCK_4BYTES
    global.get $STDIN
    global.get $FD_READ_IOVEC_PTR
    global.get $FD_READ_IOBUF_PTR
    global.get $FD_READ_BREAD_PTR
    call $fd2float
    local.set $valid
    local.set $value

    local.get $valid
    i32.eqz
    if
      i32.const 1
      return
    end

    local.get $value
    f32.const 299792458.0
    f32.ne
    if
      i32.const 1
      return
    end

    i32.const 0
  )

)

(assert_return (invoke $tests "clampf"
  (f32.const  0.0) (f32.const  0.0) (f32.const 0.0)) (f32.const  0.0))
(assert_return (invoke $tests "clampf"
  (f32.const  1.0) (f32.const  0.0) (f32.const 1.0)) (f32.const  1.0))
(assert_return (invoke $tests "clampf"
  (f32.const  9.0) (f32.const  0.0) (f32.const 1.0)) (f32.const  1.0))
(assert_return (invoke $tests "clampf"
  (f32.const -1.0) (f32.const  0.0) (f32.const 1.0)) (f32.const  0.0))
(assert_return (invoke $tests "clampf"
  (f32.const -1.0) (f32.const  0.5) (f32.const 1.0)) (f32.const  0.5))
(assert_return (invoke $tests "clampf"
  (f32.const  8.0) (f32.const  0.5) (f32.const 1.0)) (f32.const  1.0))

(assert_return (invoke $tests "signf" (f32.const  8.0)) (f32.const  1.0))
(assert_return (invoke $tests "signf" (f32.const -8.0)) (f32.const -1.0))

(assert_return (invoke $tests "logit4" (f32.const -8.0)) (f32.const 0.0))
(assert_return (invoke $tests "logit4" (f32.const -4.0)) (f32.const 0.0))
(assert_return (invoke $tests "logit4" (f32.const -2.0)) (f32.const 0.125))
(assert_return (invoke $tests "logit4" (f32.const  0.0)) (f32.const 0.5))
(assert_return (invoke $tests "logit4" (f32.const  2.0)) (f32.const 0.875))
(assert_return (invoke $tests "logit4" (f32.const  4.0)) (f32.const 1.0))
(assert_return (invoke $tests "logit4" (f32.const  8.0)) (f32.const 1.0))

(assert_return (invoke $tests "t0a_buf2float_empty") (i32.const 0))
(assert_return (invoke $tests "t0b_buf2float_too_small") (i32.const 0))
(assert_return (invoke $tests "t0c_buf2float_single") (i32.const 0))

(assert_return (invoke $tests "t10_fd2float_empty") (i32.const 0))
(assert_return (invoke $tests "t11_fd2float_3bytes") (i32.const 0))
(assert_return (invoke $tests "t12_fd2float_4bytes") (i32.const 0))
