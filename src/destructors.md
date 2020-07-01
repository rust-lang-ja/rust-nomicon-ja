<!--
# Destructors
-->

# デストラクタ

<!--
What the language *does* provide is full-blown automatic destructors through the
`Drop` trait, which provides the following method:
-->

言語が*実際に*提供しているものは、 `Drop` トレイトを通じた完全に自動的な
デストラクタで、以下のメソッドを提供しています。

```rust,ignore
fn drop(&mut self);
```

<!--
This method gives the type time to somehow finish what it was doing.
-->

このメソッドは、型が行なっていたことをなんとか終わらせるための時間を、型に
与えます。

<!--
**After `drop` is run, Rust will recursively try to drop all of the fields
of `self`.**
-->

**`drop` が実行された後、 Rust は `self` の全てのフィールドのドロップを再帰的に実行しようとします。**

<!--
This is a convenience feature so that you don't have to write "destructor
boilerplate" to drop children. If a struct has no special logic for being
dropped other than dropping its children, then it means `Drop` doesn't need to
be implemented at all!
-->

これは便利な機能で、子フィールドをドロップするための "デストラクタの決まり文句" を
書く必要がありません。もし構造体に、子フィールドをドロップする以外の、ドロップされる際の
特別なロジックが存在しなければ、 `Drop` を実装する必要が全くありません!

<!--
**There is no stable way to prevent this behavior in Rust 1.0.**
-->

**この振る舞いを防ぐステーブルな方法は、 Rust 1.0 の時点で存在しません**

<!--
Note that taking `&mut self` means that even if you could suppress recursive
Drop, Rust will prevent you from e.g. moving fields out of self. For most types,
this is totally fine.
-->

`&mut self` を受け取ることは、再帰ドロップを防ぐことが出来たとしても、例えば self から
フィールドをムーブすることが妨げられることに注意してください。
ほとんどの型にとっては、全く問題ありません。

<!--
For instance, a custom implementation of `Box` might write `Drop` like this:
-->

例えば `Box` のカスタム実装では、以下のような `Drop` を書くかもしれません。

```rust
#![feature(alloc, heap_api, unique)]

extern crate alloc;

use std::ptr::{drop_in_place, Unique};
use std::mem;

use alloc::heap;

struct Box<T>{ ptr: Unique<T> }

impl<T> Drop for Box<T> {
    fn drop(&mut self) {
        unsafe {
            drop_in_place(*self.ptr);
            heap::deallocate((*self.ptr) as *mut u8,
                             mem::size_of::<T>(),
                             mem::align_of::<T>());
        }
    }
}
# fn main() {}
```

<!--
and this works fine because when Rust goes to drop the `ptr` field it just sees
a [Unique] that has no actual `Drop` implementation. Similarly nothing can
use-after-free the `ptr` because when drop exits, it becomes inaccessible.
-->

そしてこれは、 Rust が `ptr` フィールドをドロップする際、単に、実際の `Drop` 実装が
ない [Unique] に着目するため、このコードは問題なく動くのです。
同様に、解放後は `ptr` を使用することが出来ません。なぜならドロップが存在する場合、
そのドロップ実装にアクセス不可能となるからです。

<!--
However this wouldn't work:
-->

しかし、このコードは動かないでしょう。

```rust
#![feature(alloc, heap_api, unique)]

extern crate alloc;

use std::ptr::{drop_in_place, Unique};
use std::mem;

use alloc::heap;

struct Box<T>{ ptr: Unique<T> }

impl<T> Drop for Box<T> {
    fn drop(&mut self) {
        unsafe {
            drop_in_place(*self.ptr);
            heap::deallocate((*self.ptr) as *mut u8,
                             mem::size_of::<T>(),
                             mem::align_of::<T>());
        }
    }
}

struct SuperBox<T> { my_box: Box<T> }

impl<T> Drop for SuperBox<T> {
    fn drop(&mut self) {
        unsafe {
            // 超最適化: Box の内容を `drop` せずに
            // 内容をデアロケートします
            heap::deallocate((*self.my_box.ptr) as *mut u8,
                             mem::size_of::<T>(),
                             mem::align_of::<T>());
        }
    }
}
# fn main() {}
```

<!--
After we deallocate the `box`'s ptr in SuperBox's destructor, Rust will
happily proceed to tell the box to Drop itself and everything will blow up with
use-after-frees and double-frees.
-->

SuperBox のデストラクタで `box` の ptr をデアロケートした後、 Rust は適切に box に、
自身をドロップするよう通達し、その結果、解放後の使用や二重解放によって全部消し飛びます。

<!--
Note that the recursive drop behavior applies to all structs and enums
regardless of whether they implement Drop. Therefore something like
-->

再帰ドロップは、構造体や列挙型が Drop を定義しているかしていないかによらず、
全ての構造体や列挙型に適用されることに注意してください。
ですから、以下のような

```rust
struct Boxy<T> {
    data1: Box<T>,
    data2: Box<T>,
    info: u32,
}
```

<!--
will have its data1 and data2's fields destructors whenever it "would" be
dropped, even though it itself doesn't implement Drop. We say that such a type
*needs Drop*, even though it is not itself Drop.
-->

ものは、それ自体が Drop を実装していなくても、それがドロップ*される*ときには毎回、 data1 と data2 の
フィールドをデストラクトします。これを、そのような型が *Drop を必要とする*と言います。型が Drop を
実装していなくてもです。

<!--
Similarly,
-->

同様に

```rust
enum Link {
    Next(Box<Link>),
    None,
}
```

<!--
will have its inner Box field dropped if and only if an instance stores the
Next variant.
-->

これは、インスタンスが Next を格納しているとき、そのときだけ内部の Box フィールドを
ドロップします。

<!--
In general this works really nicely because you don't need to worry about
adding/removing drops when you refactor your data layout. Still there's
certainly many valid usecases for needing to do trickier things with
destructors.
-->

一般に、これは非常に上手く動きます。なぜなら、データレイアウトをリファクタリングするときに、
ドロップを追加あるいは削除する心配が必要ないからです。もちろん、デストラクタで何か
トリッキーなことが必要になる妥当なケースは、たくさんあります。

<!--
The classic safe solution to overriding recursive drop and allowing moving out
of Self during `drop` is to use an Option:
-->

再帰ドロップを上書きし、 `drop` の最中に Self からのムーブを可能にする、
古典的で安全な解決策は、 Option を使うことです。

```rust
#![feature(alloc, heap_api, unique)]

extern crate alloc;

use std::ptr::{drop_in_place, Unique};
use std::mem;

use alloc::heap;

struct Box<T>{ ptr: Unique<T> }

impl<T> Drop for Box<T> {
    fn drop(&mut self) {
        unsafe {
            drop_in_place(*self.ptr);
            heap::deallocate((*self.ptr) as *mut u8,
                             mem::size_of::<T>(),
                             mem::align_of::<T>());
        }
    }
}

struct SuperBox<T> { my_box: Option<Box<T>> }

impl<T> Drop for SuperBox<T> {
    fn drop(&mut self) {
        unsafe {
            // 超最適化: Box の内容を `drop` せずに
            // 内容をデアロケートします
            // Rust が `box` フィールドをドロップしようとさせないために、
            // `box` フィールドを `None` と設定する必要があります
            let my_box = self.my_box.take().unwrap();
            heap::deallocate((*my_box.ptr) as *mut u8,
                             mem::size_of::<T>(),
                             mem::align_of::<T>());
            mem::forget(my_box);
        }
    }
}
# fn main() {}
```

<!--
However this has fairly odd semantics: you're saying that a field that *should*
always be Some *may* be None, just because that happens in the destructor. Of
course this conversely makes a lot of sense: you can call arbitrary methods on
self during the destructor, and this should prevent you from ever doing so after
deinitializing the field. Not that it will prevent you from producing any other
arbitrarily invalid state in there.
-->

しかしながら、これはかなり奇妙なセマンティクスです。すなわち、常に Some である*べき*
フィールドが、 None に*なりうる*と言っているからです。なぜならこれが、
デストラクタで起こっているからです。勿論、これは逆に大いに納得がいきます。
デストラクタ内で self に対して任意のメソッドを呼ぶことができ、同じことが、
フィールドが未初期化状態に戻されたあとに行われるのを防ぐはずですから。
だからといって、そこで何か他の不正状態を生成することを防ぐわけではありませんが。

<!--
On balance this is an ok choice. Certainly what you should reach for by default.
However, in the future we expect there to be a first-class way to announce that
a field shouldn't be automatically dropped.
-->

結局、これは大丈夫なのです。明らかに、デフォルトで到達すべきものなのです。
しかしながら将来、あるフィールドが自動的にドロップされるべきでないと知らせる、
素晴らしい方法が現れると我々は期待しています。

[Unique]: phantom-data.html
