<!--
# Layout
-->

# レイアウト

<!--
First off, we need to come up with the struct layout. A Vec has three parts:
a pointer to the allocation, the size of the allocation, and the number of
elements that have been initialized.
-->

まず、構造体のレイアウトを考える必要があります。 Vec は 3 つの部品を
持っています。アロケーションへのポインタと、アロケーションの大きさ、
そして初期化した要素の数です。

<!--
Naively, this means we just want this design:
-->

愚直に考えると、これは以下の設計で良いということになります。

```rust
pub struct Vec<T> {
    ptr: *mut T,
    cap: usize,
    len: usize,
}
# fn main() {}
```

<!--
And indeed this would compile. Unfortunately, it would be incorrect. First, the
compiler will give us too strict variance. So a `&Vec<&'static str>`
couldn't be used where an `&Vec<&'a str>` was expected. More importantly, it
will give incorrect ownership information to the drop checker, as it will
conservatively assume we don't own any values of type `T`. See [the chapter
on ownership and lifetimes][ownership] for all the details on variance and
drop check.
-->

そして実際に、このコードはコンパイルできます。残念ながら、この設計は正しくありません。
まず、コンパイラはあまりに厳密すぎる変性を与えることになります。ですから
`&Vec<&'a str>` が予期されているところで `&Vec<&'static str>` を使う事が
出来ません。もっと重要なことに、この設計によって正しくない所有権の情報が
ドロップチェッカに渡されてしまいます。型 `T` のいかなる値も所有していないと、
ドロップチェッカが保守的に判断してしまうからです。変性やドロップチェックに
関する全ての詳細は、[所有権とライフタイムの章][ownership]を参照してください。

<!--
As we saw in the ownership chapter, we should use `Unique<T>` in place of
`*mut T` when we have a raw pointer to an allocation we own. Unique is unstable,
so we'd like to not use it if possible, though.
-->

所有権の章で見てきたように、所有するアロケーションに対するポインタを持つ場合、
`*mut T` の代わりに `Unique<T>` を使用するべきです。 Unique はアンステーブルなため、
可能なら使いませんが。

<!--
As a recap, Unique is a wrapper around a raw pointer that declares that:
-->

繰り返しになりますが、 Unique は生ポインタのラッパで、以下のことを宣言
します。

<!--
* We are variant over `T`
* We may own a value of type `T` (for drop check)
* We are Send/Sync if `T` is Send/Sync
* We deref to `*mut T` (so it largely acts like a `*mut` in our code)
* Our pointer is never null (so `Option<Vec<T>>` is null-pointer-optimized)
-->

* `T` に対して変性
* 型 `T` の値を所有する可能性がある (ドロップチェックのため)
* `T` が Send/Sync を実装している場合、継承される
* `*mut T` に参照外しする (つまりコード内では専ら `*mut` のように振る舞う)
* ポインタはヌルにはならない (つまり `Option<Vec<T>>` はヌルポインタ最適化される)

<!--
We can implement all of the above requirements except for the last
one in stable Rust:
-->

上記の最後以外の項は、安定版の Rust で実装可能です。

```rust
use std::marker::PhantomData;
use std::ops::Deref;
use std::mem;

struct Unique<T> {
    ptr: *const T,              // 変性のために *const です
    _marker: PhantomData<T>,    // ドロップチェッカ対策
}

// Send と Sync を継承することは安全です。なぜならこのデータの
// Unique を所有しているからです。 Unique<T> は "単なる" T のようなものです。
unsafe impl<T: Send> Send for Unique<T> {}
unsafe impl<T: Sync> Sync for Unique<T> {}

impl<T> Unique<T> {
    pub fn new(ptr: *mut T) -> Self {
        Unique { ptr: ptr, _marker: PhantomData }
    }
}

impl<T> Deref for Unique<T> {
    type Target = *mut T;
    fn deref(&self) -> &*mut T {
        // 参照も受け取っている時に、 *const を *mut に
        // キャストする方法はありません。
        // これらは全て "ただのポインタ" ですのでトランスミュートします。
        unsafe { mem::transmute(&self.ptr) }
    }
}
# fn main() {}
```

<!--
Unfortunately the mechanism for stating that your value is non-zero is
unstable and unlikely to be stabilized soon. As such we're just going to
take the hit and use std's Unique:
-->

残念ながら、値が非 0 であると述べるメカニズムはアンステーブルで、すぐには
安定版はならないでしょう。ですから単に std の Unique を使うことにします。


```rust
#![feature(unique)]

use std::ptr::{Unique, self};

pub struct Vec<T> {
    ptr: Unique<T>,
    cap: usize,
    len: usize,
}

# fn main() {}
```

<!--
If you don't care about the null-pointer optimization, then you can use the
stable code. However we will be designing the rest of the code around enabling
the optimization. In particular, `Unique::new` is unsafe to call, because
putting `null` inside of it is Undefined Behavior. Our stable Unique doesn't
need `new` to be unsafe because it doesn't make any interesting guarantees about
its contents.
-->

もしヌルポインタ最適化を気にしないなら、安定版のコードを使用することもできます。
しかしながら、残りのコードでは、最適化を有効にするような設計していきます。
特に、 `Unique::new` を呼ぶことはアンセーフです。なぜなら `null` を中に突っ込む
ことは、未定義動作を引き起こしてしまうからです。安定版のコードの `new` はアンセーフに
する必要はありません。中身についての興味深い保証をしないからです。

[ownership]: ownership.html
