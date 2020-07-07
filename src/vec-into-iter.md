# IntoIter

<!--
Let's move on to writing iterators. `iter` and `iter_mut` have already been
written for us thanks to The Magic of Deref. However there's two interesting
iterators that Vec provides that slices can't: `into_iter` and `drain`.
-->

イテレータに移行しましょう。 Deref の魔法のおかげで、 `iter` と `iter_mut` は
既に書かれています。しかし、 Vec が提供できて、スライスが提供できない 2 つの
興味深いイテレータがあります。 `into_iter` と `drain` です。

<!--
IntoIter consumes the Vec by-value, and can consequently yield its elements
by-value. In order to enable this, IntoIter needs to take control of Vec's
allocation.
-->

IntoIter は Vec を値として消費します。その結果、その要素を値で返します。
これを有効にするために、 IntoIter が Vec のアロケーションを操作する
必要があります。

<!--
IntoIter needs to be DoubleEnded as well, to enable reading from both ends.
Reading from the back could just be implemented as calling `pop`, but reading
from the front is harder. We could call `remove(0)` but that would be insanely
expensive. Instead we're going to just use ptr::read to copy values out of
either end of the Vec without mutating the buffer at all.
-->

IntoIter は始端と終端の量から読み出せるように、両頭である必要があります。
後ろから読み込むのは単に `pop` を呼び出すよう実装すればよいのですが、
前から読み出すのはもっと難しいです。 `remove(0)` を呼び出してもよいのですが、
そのコストは馬鹿馬鹿しい位大きいです。その代わりに、バッファを全く変化させずに、
ptr::read を使って両端から値をコピーするようにします。

<!--
To do this we're going to use a very common C idiom for array iteration. We'll
make two pointers; one that points to the start of the array, and one that
points to one-element past the end. When we want an element from one end, we'll
read out the value pointed to at that end and move the pointer over by one. When
the two pointers are equal, we know we're done.
-->

これをするために、 C のごく普通の配列のイテレーションのイディオムを使います。
2 つのポインタを生成します。 1 つは配列の最初を指し、もう 1 つは配列の最後の
1 つ後ろの要素を指します。終端から要素を 1 つ取得したい場合は、ポインタが
指している値を読み出して、ポインタを 1 だけ動かします。もし 2 つのポインタが
等価な場合、全要素が読み出されたことを意味します。

<!--
Note that the order of read and offset are reversed for `next` and `next_back`
For `next_back` the pointer is always after the element it wants to read next,
while for `next` the pointer is always at the element it wants to read next.
To see why this is, consider the case where every element but one has been
yielded.
-->

読み出しとオフセットの操作の順序は `next` と `next_back` とで逆転することに
注意してください。 `next_back` では、ポインタは次に読みたい要素の直後の
要素をいつも指しています。対して `next` では、ポインタは次に読みたい
要素をいつも指しています。なぜこうなのか、 1 つを除いて全ての要素が
既に返された例を見てみましょう。

<!--
The array looks like this:
-->

配列は以下のようになっています。

```text
          S  E
[X, X, X, O, X, X, X]
```

<!--
If E pointed directly at the element it wanted to yield next, it would be
indistinguishable from the case where there are no more elements to yield.
-->

もし E が、次に返したい値を直接指していたら、返す値が既に存在しない場合と
区別がつかなくなっているでしょう。

<!--
Although we don't actually care about it during iteration, we also need to hold
onto the Vec's allocation information in order to free it once IntoIter is
dropped.
-->

イテレーションの途中では気にしないのですが、 IntoIter がドロップされたら Vec を
ドロップするため、 Vec のアロケーションの情報を保持する必要もあります。

<!--
So we're going to use the following struct:
-->

ですから以下のような構造体を使っていきます。

```rust,ignore
struct IntoIter<T> {
    buf: Unique<T>,
    cap: usize,
    start: *const T,
    end: *const T,
}
```

<!--
And this is what we end up with for initialization:
-->

そしてこれが初期化のコードです。

```rust,ignore
impl<T> Vec<T> {
    fn into_iter(self) -> IntoIter<T> {
        // Vec がドロップされてしまうため、 Vec をデストラクト出来ません。
        let ptr = self.ptr;
        let cap = self.cap;
        let len = self.len;

        // Vec をドロップするとバッファを解放してしまうので、ドロップしないようにします。
        mem::forget(self);

        unsafe {
            IntoIter {
                buf: ptr,
                cap: cap,
                start: *ptr,
                end: if cap == 0 {
                    // このポインタのオフセットを取ることが出来ません。アロケートされていないからです!
                    *ptr
                } else {
                    ptr.offset(len as isize)
                }
            }
        }
    }
}
```

<!--
Here's iterating forward:
-->

前方へのイテレーションのコードです。

```rust,ignore
impl<T> Iterator for IntoIter<T> {
    type Item = T;
    fn next(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                let result = ptr::read(self.start);
                self.start = self.start.offset(1);
                Some(result)
            }
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let len = (self.end as usize - self.start as usize)
                  / mem::size_of::<T>();
        (len, Some(len))
    }
}
```

<!--
And here's iterating backwards.
-->

そして後方へのイテレーションのコードです。

```rust,ignore
impl<T> DoubleEndedIterator for IntoIter<T> {
    fn next_back(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                self.end = self.end.offset(-1);
                Some(ptr::read(self.end))
            }
        }
    }
}
```

<!--
Because IntoIter takes ownership of its allocation, it needs to implement Drop
to free it. However it also wants to implement Drop to drop any elements it
contains that weren't yielded.
-->

IntoIter はアロケーションの所有権を受け取るので、それを解放するために Drop を
実装する必要があります。しかし、イテレーションの最中に返されなかった要素を
ドロップするための Drop も実装する必要があります。


```rust,ignore
impl<T> Drop for IntoIter<T> {
    fn drop(&mut self) {
        if self.cap != 0 {
            // drop any remaining elements
            for _ in &mut *self {}

            let align = mem::align_of::<T>();
            let elem_size = mem::size_of::<T>();
            let num_bytes = elem_size * self.cap;
            unsafe {
                heap::deallocate(*self.buf as *mut _, num_bytes, align);
            }
        }
    }
}
```
