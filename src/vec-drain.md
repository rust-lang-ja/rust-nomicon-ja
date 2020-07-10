# Drain

<!--
Let's move on to Drain. Drain is largely the same as IntoIter, except that
instead of consuming the Vec, it borrows the Vec and leaves its allocation
untouched. For now we'll only implement the "basic" full-range version.
-->

Drain に移行しましょう。 Drain は大体 IntoIter と同じですが、 Vec を消費
する代わりに、 Vec を借用し、アロケーションに触れないままにします。
とりあえず、 "基本的な" 全範囲のバージョンだけを実装しましょう。

```rust,ignore
use std::marker::PhantomData;

struct Drain<'a, T: 'a> {
    // ライフタイムの制限を課す必要があるため、 `&'a mut Vec<T>` という
    // ライフタイムを付与します。セマンティクス的に、これを含んでいるからです。
    // 単に `pop()` と `remove(0)` を呼び出しています。
    vec: PhantomData<&'a mut Vec<T>>
    start: *const T,
    end: *const T,
}

impl<'a, T> Iterator for Drain<'a, T> {
    type Item = T;
    fn next(&mut self) -> Option<T> {
        if self.start == self.end {
            None
```

<!--
-- wait, this is seeming familiar. Let's do some more compression. Both
IntoIter and Drain have the exact same structure, let's just factor it out.
-->

-- 待った、何か似ているな。もっと圧縮してみましょう。
IntoIter と Drain は両方同じ構造を持っています。抽出しましょう。

```rust
struct RawValIter<T> {
    start: *const T,
    end: *const T,
}

impl<T> RawValIter<T> {
    // 値のコンストラクトはアンセーフです。関連付けられているライフタイムが
    // 存在しないからです。 これは、RawValIter を、実際のアロケーションと同一の構造体に
    // 保存するため必要です。プライベートな実装詳細ですので問題ありません。
    unsafe fn new(slice: &[T]) -> Self {
        RawValIter {
            start: slice.as_ptr(),
            end: if slice.len() == 0 {
                // もし `len = 0` なら、実際にはメモリをアロケートしていません。
                // GEP を通して LLVM に間違った情報を渡してしまうため、
                // オフセットを避ける必要があります。
                slice.as_ptr()
            } else {
                slice.as_ptr().offset(slice.len() as isize)
            }
        }
    }
}

// Iterator と DoubleEndedIterator の impl は IntoIter と同一です。
```

<!--
And IntoIter becomes the following:
-->

そして IntoIter は以下のようになります。

```rust,ignore
pub struct IntoIter<T> {
    _buf: RawVec<T>, // これを扱うことはないのですが、その存在は必要です。
    iter: RawValIter<T>,
}

impl<T> Iterator for IntoIter<T> {
    type Item = T;
    fn next(&mut self) -> Option<T> { self.iter.next() }
    fn size_hint(&self) -> (usize, Option<usize>) { self.iter.size_hint() }
}

impl<T> DoubleEndedIterator for IntoIter<T> {
    fn next_back(&mut self) -> Option<T> { self.iter.next_back() }
}

impl<T> Drop for IntoIter<T> {
    fn drop(&mut self) {
        for _ in &mut self.iter {}
    }
}

impl<T> Vec<T> {
    pub fn into_iter(self) -> IntoIter<T> {
        unsafe {
            let iter = RawValIter::new(&self);

            let buf = ptr::read(&self.buf);
            mem::forget(self);

            IntoIter {
                iter: iter,
                _buf: buf,
            }
        }
    }
}
```

<!--
Note that I've left a few quirks in this design to make upgrading Drain to work
with arbitrary subranges a bit easier. In particular we *could* have RawValIter
drain itself on drop, but that won't work right for a more complex Drain.
We also take a slice to simplify Drain initialization.
-->

設計の中で、ちょっと奇妙なものを少し含めたことに注意してください。
これは、 Drain を任意の副範囲で動作させるのを、ちょっと簡単にするためです。
特に、 RawValIter がドロップの際に、自身をドレイン*出来る*でしょうが、
これは、もっと複雑な Drain に対しては正しく動作しません。
スライスも用いて、 Drain の初期化を単純にします。

<!--
Alright, now Drain is really easy:
-->

よし、これで Drain を本当に楽に実装できます。

```rust,ignore
use std::marker::PhantomData;

pub struct Drain<'a, T: 'a> {
    vec: PhantomData<&'a mut Vec<T>>,
    iter: RawValIter<T>,
}

impl<'a, T> Iterator for Drain<'a, T> {
    type Item = T;
    fn next(&mut self) -> Option<T> { self.iter.next() }
    fn size_hint(&self) -> (usize, Option<usize>) { self.iter.size_hint() }
}

impl<'a, T> DoubleEndedIterator for Drain<'a, T> {
    fn next_back(&mut self) -> Option<T> { self.iter.next_back() }
}

impl<'a, T> Drop for Drain<'a, T> {
    fn drop(&mut self) {
        for _ in &mut self.iter {}
    }
}

impl<T> Vec<T> {
    pub fn drain(&mut self) -> Drain<T> {
        unsafe {
            let iter = RawValIter::new(&self);

            // これは mem::forget の安全版です。もし Drain が forget されたら、
            // 単に Vec の内容全体がリークします。そして*結局*これをしなければ
            // なりません。なら今やっちゃいましょう。
            self.len = 0;

            Drain {
                iter: iter,
                vec: PhantomData,
            }
        }
    }
}
```

<!--
For more details on the `mem::forget` problem, see the
[section on leaks][leaks].
-->

`mem::forget` の詳細は、[リークの章][leaks]を参照してください。

[leaks]: leaking.html
