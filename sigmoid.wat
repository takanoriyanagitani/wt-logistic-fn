(module

  (import "wasi_snapshot_preview1" "proc_exit" (func $proc_exit (param i32)))

  (import "wasi_snapshot_preview1" "fd_read"
    (func $fd_read (param i32 i32 i32 i32) (result i32)))

  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))

  (global $STDIN i32 (i32.const 0))
  (global $STDOUT i32 (i32.const 1))
  (global $STDERR i32 (i32.const 2))

  (global $FD_READ_IOVEC_PTR i32 (i32.const 0x0001_0000))
  (global $FD_READ_IOBUF_PTR i32 (i32.const 0x0002_0000))
  (global $FD_READ_BREAD_PTR i32 (i32.const 0x0003_0000))

  (global $FD_WRIT_IOVEC_PTR i32 (i32.const 0x0004_0000))
  (global $FD_WRIT_IOBUF_PTR i32 (i32.const 0x0005_0000))
  (global $FD_WRIT_BWRIT_PTR i32 (i32.const 0x0006_0000))

  (memory (export "memory") 9)

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

  (table $fd_read_table (export "table") 1 funcref)
  (elem (table $fd_read_table) (i32.const 0) $fd_read)

  (global $IO_FD_READ_IMPURE i32 (i32.const 0))

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

  (func $fd2float_default (result f32 i32)
    global.get $IO_FD_READ_IMPURE
    global.get $STDIN
    global.get $FD_READ_IOVEC_PTR
    global.get $FD_READ_IOBUF_PTR
    global.get $FD_READ_BREAD_PTR
    call $fd2float
  )

  (func $f2stdout (param $f f32)
    global.get $FD_WRIT_IOVEC_PTR
    global.get $FD_WRIT_IOBUF_PTR
    i32.store
    global.get $FD_WRIT_IOVEC_PTR
    i32.const 4 ;; 32-bit float = 4 bytes
    i32.store offset=4

    global.get $FD_WRIT_IOBUF_PTR
    local.get $f
    f32.store

    global.get $STDOUT
    global.get $FD_WRIT_IOVEC_PTR
    i32.const 1 ;; one buf
    global.get $FD_WRIT_BWRIT_PTR
    call $fd_write
    i32.const 0
    i32.ne
    if
      i32.const 1
      call $proc_exit
    end

    global.get $FD_WRIT_BWRIT_PTR
    i32.load
    i32.const 4
    i32.ne
    if
      i32.const 1
      call $proc_exit
    end
  )

  (func $main (export "_start")
    (local $f f32)
    (local $ret i32)
    call $fd2float_default
    local.set $ret
    local.set $f

    local.get $ret
    i32.eqz
    if
      i32.const 2
      call $proc_exit
    end

    local.get $f
    call $logistic4f
    call $f2stdout
  )

)
