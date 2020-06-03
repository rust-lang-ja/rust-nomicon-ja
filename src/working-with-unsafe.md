<!--
# Working with Unsafe
-->

# Unsafe と連携する

<!--
Rust generally only gives us the tools to talk about Unsafe Rust in a scoped and
binary manner. Unfortunately, reality is significantly more complicated than
that. For instance, consider the following toy function:
-->

たいていの場合、アンセーフな Rust を扱うツールは、限定された状況やバイナリでしか使えないようになっています。
残念なことに、現実はそれよりも極めて複雑です。例えば、以下の簡単な関数を見てみましょう。

```rust
fn index(idx: usize, arr: &[u8]) -> Option<u8> {
    if idx < arr.len() {
        unsafe {
            Some(*arr.get_unchecked(idx))
        }
    } else {
        None
    }
}
```

<!--
Clearly, this function is safe. We check that the index is in bounds, and if it
is, index into the array in an unchecked manner. But even in such a trivial
function, the scope of the unsafe block is questionable. Consider changing the
`<` to a `<=`:
-->

この関数は明らかに安全です。インデックスが範囲内である事をチェックし、
範囲内であれば未チェックで配列をインデックス参照します。
しかしこのような自明な関数でさえも、unsafe ブロックのスコープには疑問が残ります。
`<` を `<=` に変えてみましょう。

```rust
fn index(idx: usize, arr: &[u8]) -> Option<u8> {
    if idx <= arr.len() {
        unsafe {
            Some(*arr.get_unchecked(idx))
        }
    } else {
        None
    }
}
```

<!--
This program is now unsound, and yet *we only modified safe code*. This is the
fundamental problem of safety: it's non-local. The soundness of our unsafe
operations necessarily depends on the state established by otherwise
"safe" operations.
-->

*安全なコードを変更しただけなのに*、今やこのプログラムは安全ではなくなりました。
これが安全性の本質的な問題です。局所的ではないのです。
アンセーフな操作の健全性は、通常 "安全" な操作によって構築された状態に依存しているのです。

<!--
Safety is modular in the sense that opting into unsafety doesn't require you
to consider arbitrary other kinds of badness. For instance, doing an unchecked
index into a slice doesn't mean you suddenly need to worry about the slice being
null or containing uninitialized memory. Nothing fundamentally changes. However
safety *isn't* modular in the sense that programs are inherently stateful and
your unsafe operations may depend on arbitrary other state.
-->

安全性は、アンセーフな操作をしたからといってあらゆる他の悪い事を考慮する必要はない、という意味ではモジュール化されています。
例えば、スライスに対して未チェックのインデックスアクセスをしても、スライスがヌルだったらどうしようとか、
スライスが未初期化のメモリを含んでいるかもといった心配をする必要はありません。基本的には何も変わりません。
しかし、プログラムは本質的にステートフルであり、アンセーフな操作はその他の任意の状態に依存しているかもしれない、
という意味で、安全性はモジュール化*されてはいない*のです。


<!--
Trickier than that is when we get into actual statefulness. Consider a simple
implementation of `Vec`:
-->

実際にステートフルな状況を考えると、事態はもっと厄介になります。
`Vec` の簡単な実装を見てみましょう。

```rust
use std::ptr;

// この定義は不完全であることに注意してください。Vec の実装に関するセクションをみてください。
pub struct Vec<T> {
    ptr: *mut T,
    len: usize,
    cap: usize,
}

// この実装ではサイズが 0 の型を正しく扱えないことに注意してください。
// ここでは、すべてが 0 以上の固定サイズの型しか存在しない素敵な仮想的な世界を仮定します。
impl<T> Vec<T> {
    pub fn push(&mut self, elem: T) {
        if self.len == self.cap {
            // この例では重要ではありません。
            self.reallocate();
        }
        unsafe {
            ptr::write(self.ptr.offset(self.len as isize), elem);
            self.len += 1;
        }
    }

    # fn reallocate(&mut self) { }
}

# fn main() {}
```

<!--
This code is simple enough to reasonably audit and verify. Now consider
adding the following method:
-->

このコードはとてもシンプルなので、それなりに監査して検証できるでしょう。
それでは次のメソッドを追加してみましょう。


```rust,ignore
fn make_room(&mut self) {
    // キャパシティを大きくする
    self.cap += 1;
}
```

<!--
This code is 100% Safe Rust but it is also completely unsound. Changing the
capacity violates the invariants of Vec (that `cap` reflects the allocated space
in the Vec). This is not something the rest of Vec can guard against. It *has*
to trust the capacity field because there's no way to verify it.
-->

このコードは 100% 安全な Rust ですが、同時に完全に不健全です。
キャパシティの変更は、Vec の普遍条件（`cap` は Vec にアロケートされたスペースを表している）を破ることになります。
Vec の他のコードはこれを防げません。
Vec は `cap` フィールドを検証できないので、*信頼しなくてはならない* のです。

<!--
`unsafe` does more than pollute a whole function: it pollutes a whole *module*.
Generally, the only bullet-proof way to limit the scope of unsafe code is at the
module boundary with privacy.
-->

`unsafe` は関数そのものを汚染するだけでなく、*モジュール* 全体を汚染します。
一般的に、危険なコードのスコープを制限する唯一で完全無欠の方法は、モジュール境界での非公開性を利用することです。

<!--
However this works *perfectly*. The existence of `make_room` is *not* a
problem for the soundness of Vec because we didn't mark it as public. Only the
module that defines this function can call it. Also, `make_room` directly
accesses the private fields of Vec, so it can only be written in the same module
as Vec.
-->

しかしこれは *完璧な* やり方です。
`make_room` は、public メソッドではないので、Vec の健全性の問題にはなりません。
この関数を定義しているモジュールだけがこの関数を呼べるのです。
また、`make_room` は Vec の private フィールドを直接アクセスしているので、
Vec と同じモジュールでのみ定義できます。

<!--
It is therefore possible for us to write a completely safe abstraction that
relies on complex invariants. This is *critical* to the relationship between
Safe Rust and Unsafe Rust. We have already seen that Unsafe code must trust
*some* Safe code, but can't trust *generic* Safe code. It can't trust an
arbitrary implementor of a trait or any function that was passed to it to be
well-behaved in a way that safe code doesn't care about.
-->

このように、複雑な普遍条件に依存した安全な抽象化を提供することは可能なのです。
これは安全な Rust と危険な Rust の関係において決定的に重要です。
すでに見たように、危険なコードは *特定* の安全なコードを信頼しなくてはなりませんが、
安全なコード *一般* を信頼することはできません。
安全なコードを書くときには気にする必要はないのですが、危険なコードでは、
trait の任意の実装や渡された任意の関数が行儀よく振る舞うことを期待することはできないのです。


However if unsafe code couldn't prevent client safe code from messing with its
state in arbitrary ways, safety would be a lost cause. Thankfully, it *can*
prevent arbitrary code from messing with critical state due to privacy.

しかし、安全なコードが状態をあらゆる方法でぐちゃぐちゃにすることを、危険なコードが防げないのだとしたら、
安全性とは絵に描いた餅かもしれません。
ありがたいことに、非公開性を利用することで、
任意のコードが重要な状態をめちゃくちゃにしないよう防ぐことができるのです。

<!--
Safety lives!
-->

安全性は無事です!

