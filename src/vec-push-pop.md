<!--
# Push and Pop
-->

# プッシュとポップ

<!--
Alright. We can initialize. We can allocate. Let's actually implement some
functionality! Let's start with `push`. All it needs to do is check if we're
full to grow, unconditionally write to the next index, and then increment our
length.
-->

よし、初期化出来ました。アロケート出来ます。それでは実際にいくつか機能を
実装しましょう! まず `push` 。必要なことは、 grow をするべきか確認し、
状況によらず、次のインデックスの場所に書き込み、そして長さをインクリメント
します。

<!--
To do the write we have to be careful not to evaluate the memory we want to write
to. At worst, it's truly uninitialized memory from the allocator. At best it's the
bits of some old value we popped off. Either way, we can't just index to the memory
and dereference it, because that will evaluate the memory as a valid instance of
T. Worse, `foo[idx] = x` will try to call `drop` on the old value of `foo[idx]`!
-->

書き込みの際、書き込みたいメモリの値を評価しないよう、注意深く行なう必要が
あるます。最悪、そのメモリはアロケータが全く初期化していません。良くても、
ポップした古い値のビットが残っています。いずれにせよ、そのメモリをインデックス指定し、
単に参照外しをするわけにはいきません。なぜならそれによって、メモリ上の値を、 T の
正しいインスタンスとして評価してしまうからです。もっと悪いと `foo[idx] = x` によって、
`foo[idx]` の古い値に対して `drop` を呼ぼうとしてしまいます!

<!--
The correct way to do this is with `ptr::write`, which just blindly overwrites the
target address with the bits of the value we provide. No evaluation involved.
-->

正しい方法は、 `ptr::write` を使う方法です。これは、ターゲットのアドレスを、
与えた値のビットでそのまま上書きします。何の評価も起こりません。

<!--
For `push`, if the old len (before push was called) is 0, then we want to write
to the 0th index. So we should offset by the old len.
-->

`push` においては、もし古い (push が呼ばれる前の) len が 0 であるなら、 0 番目の
インデックスに書き込むようにしたいです。ですから古い len の値によるオフセットを使うべきです。

```rust,ignore
pub fn push(&mut self, elem: T) {
    if self.len == self.cap { self.grow(); }

    unsafe {
        ptr::write(self.ptr.offset(self.len as isize), elem);
    }

    // 絶対成功します。 OOM はこの前に起こるからです。
    self.len += 1;
}
```

<!--
Easy! How about `pop`? Although this time the index we want to access is
initialized, Rust won't just let us dereference the location of memory to move
the value out, because that would leave the memory uninitialized! For this we
need `ptr::read`, which just copies out the bits from the target address and
interprets it as a value of type T. This will leave the memory at this address
logically uninitialized, even though there is in fact a perfectly good instance
of T there.
-->

簡単です! では `pop` はどうでしょうか? この場合、アクセスしたいインデックスにある
値は初期化されていますが、 Rust はメモリ上の値をムーブするために、その場所への
参照外しをする事を許可しません。なぜならこれによって、メモリを未初期化のままにするからです!
これに関しては、 `ptr::read` を必要とします。これは、単にターゲットのアドレスから
ビットをコピーし、それを型 `T` の値として解釈します。これによって、実際には
そのアドレスのメモリにある値は完全に T のインスタンスであるけれども、
値を論理的には未初期化の状態のままにします。

<!--
For `pop`, if the old len is 1, we want to read out of the 0th index. So we
should offset by the new len.
-->

`pop` に関しては、もし古い len の値が 1 の場合、 0 番目のインデックスにある値を
読み出したいです。ですから新しい len によるオフセットを使うべきです。

```rust,ignore
pub fn pop(&mut self) -> Option<T> {
    if self.len == 0 {
        None
    } else {
        self.len -= 1;
        unsafe {
            Some(ptr::read(self.ptr.offset(self.len as isize)))
        }
    }
}
```
