<!--
# Deallocating
-->

# デアロケーティング

<!--
Next we should implement Drop so that we don't massively leak tons of resources.
The easiest way is to just call `pop` until it yields None, and then deallocate
our buffer. Note that calling `pop` is unneeded if `T: !Drop`. In theory we can
ask Rust if `T` `needs_drop` and omit the calls to `pop`. However in practice
LLVM is *really* good at removing simple side-effect free code like this, so I
wouldn't bother unless you notice it's not being stripped (in this case it is).
-->

次に、大量のリソースをリークしてしまわないよう、 Drop を実装するべきです。
簡単な方法は、単に `pop` を、 None が返されるまで呼び出し、そして、
バッファをデアロケートする方法です。もし `T: !Drop` である場合、 `pop` を
呼ぶことは必要ない事に注意してください。理論的には、`T` をドロップする必要が
あるかを `needs_drop` で確かめ、 `pop` の呼び出しを省略することが出来ます。
しかし実践的には、 LLVM は*本当に*このような副作用のない単純なコードを
取り除くことに優れているため、 (今回の場合のように) コードが取り除かれてしまい、
悩みの原因となってしまいます。

<!--
We must not call `heap::deallocate` when `self.cap == 0`, as in this case we
haven't actually allocated any memory.
-->

`self.cap == 0` である場合、 `heap::deallocate` を呼んではいけません。
この時、実際にはメモリをアロケートしていないからです。


```rust,ignore
impl<T> Drop for Vec<T> {
    fn drop(&mut self) {
        if self.cap != 0 {
            while let Some(_) = self.pop() { }

            let align = mem::align_of::<T>();
            let elem_size = mem::size_of::<T>();
            let num_bytes = elem_size * self.cap;
            unsafe {
                heap::deallocate(*self.ptr as *mut _, num_bytes, align);
            }
        }
    }
}
```
