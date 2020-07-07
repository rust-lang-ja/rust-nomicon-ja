<!--
# Deref
-->

# 参照外し

<!--
Alright! We've got a decent minimal stack implemented. We can push, we can
pop, and we can clean up after ourselves. However there's a whole mess of
functionality we'd reasonably want. In particular, we have a proper array, but
none of the slice functionality. That's actually pretty easy to solve: we can
implement `Deref<Target=[T]>`. This will magically make our Vec coerce to, and
behave like, a slice in all sorts of conditions.
-->

よし! 満足できる最小限のスタックを実装しました。プッシュ、ポップができ、
そして最後に自身を片付けることができます。しかし、我々が欲しい
沢山のコマンドがあります。特に、適切な配列はあるけれども、スライスの
機能がありません。これは実際結構簡単に解決することができます。すなわち、
`Deref<Target=[T]>` を実装すればよいのです。これによって、 Vec に
あらゆる状況において、参照外しをさせたり、スライスのように振る舞わせる
ことができるようになります。

<!--
All we need is `slice::from_raw_parts`. It will correctly handle empty slices
for us. Later once we set up zero-sized type support it will also Just Work
for those too.
-->

必要なのは `slice::from_raw_parts` です。これによって、正しく空の
スライスを扱えます。サイズが 0 の型をサポートしたあとは、
これらも同様に扱えるようになります。

```rust,ignore
use std::ops::Deref;

impl<T> Deref for Vec<T> {
    type Target = [T];
    fn deref(&self) -> &[T] {
        unsafe {
            ::std::slice::from_raw_parts(*self.ptr, self.len)
        }
    }
}
```

<!--
And let's do DerefMut too:
-->

では DerefMut も実装しましょう。

```rust,ignore
use std::ops::DerefMut;

impl<T> DerefMut for Vec<T> {
    fn deref_mut(&mut self) -> &mut [T] {
        unsafe {
            ::std::slice::from_raw_parts_mut(*self.ptr, self.len)
        }
    }
}
```

<!--
Now we have `len`, `first`, `last`, indexing, slicing, sorting, `iter`,
`iter_mut`, and all other sorts of bells and whistles provided by slice. Sweet!
-->

これで、 `len`、 `first`、 `last`、 インデックス参照、スライス、ソート、
`iter`、 `iter_mut`、そして他のスライスによって提供される、あらゆる
魅力的なツールを手に入れました。やったね!
