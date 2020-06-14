<!--
# Drop Check
-->

# ドロップチェック

<!--
We have seen how lifetimes provide us some fairly simple rules for ensuring
that we never read dangling references. However up to this point we have only ever
interacted with the *outlives* relationship in an inclusive manner. That is,
when we talked about `'a: 'b`, it was ok for `'a` to live *exactly* as long as
`'b`. At first glance, this seems to be a meaningless distinction. Nothing ever
gets dropped at the same time as another, right? This is why we used the
following desugaring of `let` statements:
-->

タングリング参照を絶対に読み込まないよう、ライフタイムが提供しているいくつかのかなり単純な規則を
確認してきました。しかしここまで、片方のライフタイムが*より長生きする*関係についてのみ、包括的な方法で取り組んできました。
つまり、 `'a: 'b` についてお話したとき、 `'a` が `'b` と*全く*同じだけ生きても問題なかったのです。
ひと目見ただけでも、これは無意味な区別のように感じます。
他のものと同時にドロップされるものって今まで存在していないですよね?
これが、以下の `let` 文の脱糖を使用した理由です:

```rust,ignore
let x;
let y;
```

```rust,ignore
{
    let x;
    {
        let y;
    }
}
```

<!--
Each creates its own scope, clearly establishing that one drops before the
other. However, what if we do the following?
-->

それぞれがスコープを生成しているので、明らかに片方がもう片方よりも先にドロップすることが確認できます。
しかし、次の場合はどうでしょう?

```rust,ignore
let (x, y) = (vec![], vec![]);
```

<!--
Does either value strictly outlive the other? The answer is in fact *no*,
neither value strictly outlives the other. Of course, one of x or y will be
dropped before the other, but the actual order is not specified. Tuples aren't
special in this regard; composite structures just don't guarantee their
destruction order as of Rust 1.0.
-->

片方が厳密にもう片方よりも長生きするのでしょうか? 実は、答えは*いいえ*です。つまり、
どちらの値も厳密に、他方より長生きしません。勿論、 x と y のどちらかが他方よりも
先にドロップするでしょうが、実際の順番は定められていません。
タプルはこの点において特別ではありません。 Rust 1.0 の時点で、
複合構造体は単にデストラクションの順番を保証していないだけです。

<!--
We *could* specify this for the fields of built-in composites like tuples and
structs. However, what about something like Vec? Vec has to manually drop its
elements via pure-library code. In general, anything that implements Drop has
a chance to fiddle with its innards during its final death knell. Therefore
the compiler can't sufficiently reason about the actual destruction order
of the contents of any type that implements Drop.
-->

タプルや構造体といった組み込み複合体のフィールドに、デストラクションの順番を
定めることは*出来ました*。しかし、 Vec のようなものの場合どうでしょうか? Vec は
純粋なライブラリのコードを通してその要素を手動でドロップする必要があります。
一般に、 Drop を実装しているものは、最後にその内部をいじくる機会があります。
それゆえに、コンパイラは Drop を実装しているいかなる型の内容の、実際の
デストラクションの順番を十分に推論できないのです。

<!--
So why do we care? We care because if the type system isn't careful, it could
accidentally make dangling pointers. Consider the following simple program:
-->

ではなぜこれを気にするのでしょうか? 型システムが丁寧でない場合、誤ってダングリングポインタを
生成しうるからです。次の単純なプログラムを考えてみましょう。

```rust
struct Inspector<'a>(&'a u8);

fn main() {
    let (inspector, days);
    days = Box::new(1);
    inspector = Inspector(&days);
}
```

<!--
This program is totally sound and compiles today. The fact that `days` does
not *strictly* outlive `inspector` doesn't matter. As long as the `inspector`
is alive, so is days.
-->

このプログラムは今日完全に問題なく、コンパイルすることが出来ます。 `days` が
*厳密に* `inspector` より長くは生きないということは問題ではありません。
`inspector` が生きている限り、 `days` も生きています。

<!--
However if we add a destructor, the program will no longer compile!
-->

しかし、もしデストラクタを追加したら、プログラムはもうコンパイルできないでしょう!

```rust,ignore
struct Inspector<'a>(&'a u8);

impl<'a> Drop for Inspector<'a> {
    fn drop(&mut self) {
        // 退職からたった{}日でした!
        println!("I was only {} days from retirement!", self.0);
    }
}

fn main() {
    let (inspector, days);
    days = Box::new(1);
    inspector = Inspector(&days);
    // `days` が先にドロップするとしましょう。
    // すると、 Inspector がドロップされる時、解放されたメモリを読もうとします!
}
```

```text
<anon>:12:28: 12:32 error: `days` does not live long enough
(エラー: `days` は十分長生きしません)
<anon>:12     inspector = Inspector(&days);
                                     ^~~~
<anon>:9:11: 15:2 note: reference must be valid for the block at 9:10...
(注釈: 参照は 9:10 にあるブロックに対して有効でなければなりません)
<anon>:9 fn main() {
<anon>:10     let (inspector, days);
<anon>:11     days = Box::new(1);
<anon>:12     inspector = Inspector(&days);
<anon>:13     // `days` が先にドロップするとしましょう。
<anon>:14     // すると、 Inspector がドロップされる時、解放されたメモリを読もうとします!
          ...
<anon>:10:27: 15:2 note: ...but borrowed value is only valid for the block suffix following statement 0 at 10:26
(注釈: ...しかし、借用された値は 10:26 にある、文 0 に続くブロックサフィックスに対してのみ有効です)
<anon>:10     let (inspector, days);
<anon>:11     days = Box::new(1);
<anon>:12     inspector = Inspector(&days);
<anon>:13     // `days` が先にドロップするとしましょう。
<anon>:14     // すると、 Inspector がドロップされる時、解放されたメモリを読もうとします!
<anon>:15 }
```

<!--
Implementing Drop lets the Inspector execute some arbitrary code during its
death. This means it can potentially observe that types that are supposed to
live as long as it does actually were destroyed first.
-->

Drop トレイトを実装することで、 Inspector が最後に任意のコードを実行するようにできます。
これは、 Inspector と同じだけ生きる型が、実際には先に破棄されると潜在的に認識できます。

<!--
Interestingly, only generic types need to worry about this. If they aren't
generic, then the only lifetimes they can harbor are `'static`, which will truly
live *forever*. This is why this problem is referred to as *sound generic drop*.
Sound generic drop is enforced by the *drop checker*. As of this writing, some
of the finer details of how the drop checker validates types is totally up in
the air. However The Big Rule is the subtlety that we have focused on this whole
section:
-->

興味深いことに、ジェネリックな型だけがこれを気に掛ける必要があります。
もし型がジェネリックでなければ、型が隠蔽できる唯一のライフタイムは `'static` です。
このライフタイムは本当に*永遠に*生き続けます。これが、この問題が*健全ジェネリックドロップ*として
呼ばれている理由です。健全ジェネリックドロップは*ドロップチェッカ*によって実行されます。
Rust nomicon の英語版のこの章が書かれた時点で、ドロップチェッカがどのように型の有効性を
確かめるかについてのより細かい部分については全く決まっていません。しかし、大まかな規則は、
この章全体で注目してきた僅かなものです。

<!--
**For a generic type to soundly implement drop, its generics arguments must
strictly outlive it.**
-->

**ジェネリックな型に、健全なドロップを実装するためには、そのジェネリックな引数は厳密に
ジェネリックな型よりも長生きしなければなりません**

<!--
Obeying this rule is (usually) necessary to satisfy the borrow
checker; obeying it is sufficient but not necessary to be
sound. That is, if your type obeys this rule then it's definitely
sound to drop.
-->

この規則に従うことは、 (通常) 借用チェッカを満足させるために必要です。
この規則に従うことは十分条件ですが、健全であるためには不必要です。
つまり、もし型がこの規則に則っている場合、その型は疑いなく安全にドロップできます。

<!--
The reason that it is not always necessary to satisfy the above rule
is that some Drop implementations will not access borrowed data even
though their type gives them the capability for such access.
-->

この規則を必ずしも満足させる必要がない理由は、借用されたデータにアクセス
できるにも関わらず、データにアクセスしない Drop の実装が存在するからです。

<!--
For example, this variant of the above `Inspector` example will never
access borrowed data:
-->

例えばこの、上記の `Inspector` の変種の例では、借用されたデータにアクセスしません。

```rust,ignore
struct Inspector<'a>(&'a u8, &'static str);

impl<'a> Drop for Inspector<'a> {
    fn drop(&mut self) {
        // Inspector(_, {}) はいつ調査を*しない*かを知っています。
        println!("Inspector(_, {}) knows when *not* to inspect.", self.1);
    }
}

fn main() {
    let (inspector, days);
    days = Box::new(1);
    inspector = Inspector(&days, "gadget");
    // `days` が先にドロップするとしましょう。
    // Inspector がドロップしたとしても、デストラクタは
    // 借用された `days` にアクセスしません。
}
```

<!--
Likewise, this variant will also never access borrowed data:
-->

同様に、この変種も、借用されたデータにアクセスしません。

```rust,ignore
use std::fmt;

struct Inspector<T: fmt::Display>(T, &'static str);

impl<T: fmt::Display> Drop for Inspector<T> {
    fn drop(&mut self) {
        // Inspector(_, {}) はいつ調査を*しない*かを知っています。
        println!("Inspector(_, {}) knows when *not* to inspect.", self.1);
    }
}

fn main() {
    let (inspector, days): (Inspector<&u8>, Box<u8>);
    days = Box::new(1);
    inspector = Inspector(&days, "gadget");
    // `days` が先にドロップするとしましょう。
    // Inspector がドロップしたとしても、デストラクタは
    // 借用された `days` にアクセスしません
}
```

<!--
However, *both* of the above variants are rejected by the borrow
checker during the analysis of `fn main`, saying that `days` does not
live long enough.
-->

しかしながら、上記の*両方の*変種は、 `fn main` の分析中に、 `days` が
十分長生きしないと言われ、借用チェッカに弾かれるでしょう。

<!--
The reason is that the borrow checking analysis of `main` does not
know about the internals of each Inspector's Drop implementation.  As
far as the borrow checker knows while it is analyzing `main`, the body
of an inspector's destructor might access that borrowed data.
-->

理由は、 `main` の借用チェックの際、 借用チェッカはそれぞれの Inspector の Drop の実装の
内部については知らないからです。借用チェッカが `main` の分析をしている間、 inspector の
デストラクタの本体が借用されたデータにアクセスするかもしれないと借用チェッカが認識しているからです。

<!--
Therefore, the drop checker forces all borrowed data in a value to
strictly outlive that value.
-->

それゆえにドロップチェッカは、ある値の中の全ての借用されたデータが、
その値よりも厳密に長生きするよう強制するのです。

<!--
# An Escape Hatch
-->

# 脱出口

<!--
The precise rules that govern drop checking may be less restrictive in
the future.
-->

ドロップチェックを制御する正確な規則は、将来緩和される可能性があります。

<!--
The current analysis is deliberately conservative and trivial; it forces all
borrowed data in a value to outlive that value, which is certainly sound.
-->

現在の分析方法は、わざと控えめで、自明なものにしています。
ある値の中の全ての借用されたデータが、その値よりも長生きするよう強制するのです。
これは明らかに健全です。

<!--
Future versions of the language may make the analysis more precise, to
reduce the number of cases where sound code is rejected as unsafe.
This would help address cases such as the two Inspectors above that
know not to inspect during destruction.
-->

将来の Rust のバージョンでは、健全なコードがアンセーフとして弾かれるケースの
数を減らすため、分析がより正確になるかもしれません。
これは、デストラクションの際にデータにアクセスしないと分かっている、
上記の 2 つの Inspector のようなケースに対処するのを手助けしてくれるでしょう。

<!--
In the meantime, there is an unstable attribute that one can use to
assert (unsafely) that a generic type's destructor is *guaranteed* to
not access any expired data, even if its type gives it the capability
to do so.
-->

それまでは、 (アンセーフではあるが) ジェネリックな型のデストラクタが、
たとえ破棄されたデータにアクセス出来るとしても、そのようなアクセスをしないと*保証する*と見なす、
アンステーブルなアトリビュートを使用することが出来ます。

<!--
That attribute is called `may_dangle` and was introduced in [RFC 1327]
(https://github.com/rust-lang/rfcs/blob/master/text/1327-dropck-param-eyepatch.md).
To deploy it on the Inspector example from above, we would write:
-->

そのアトリビュートは `may_dangle` と呼ばれ、 [RFC 1327](https://github.com/rust-lang/rfcs/blob/master/text/1327-dropck-param-eyepatch.md) で
導入されました。上記の Inspector の例でこのアトリビュートを使用する場合、以下のように書きます。

```rust,ignore
struct Inspector<'a>(&'a u8, &'static str);

unsafe impl<#[may_dangle] 'a> Drop for Inspector<'a> {
    fn drop(&mut self) {
        // Inspector(_, {}) はいつ調査を*しない*かを知っています。
        println!("Inspector(_, {}) knows when *not* to inspect.", self.1);
    }
}
```

<!--
Use of this attribute requires the `Drop` impl to be marked `unsafe` because the
compiler is not checking the implicit assertion that no potentially expired data
(e.g. `self.0` above) is accessed.
-->

このアトリビュートを使用する場合、 `Drop` の impl が `unsafe` でマークされる必要があります。
なぜならコンパイラは、いかなる既に破棄されているかもしれないデータ (例えば上記の `self.0`) にアクセスしないという
暗黙の主張について検査しないからです。

The attribute can be applied to any number of lifetime and type parameters. In
the following example, we assert that we access no data behind a reference of
lifetime `'b` and that the only uses of `T` will be moves or drops, but omit
the attribute from `'a` and `U`, because we do access data with that lifetime
and that type:

```rust,ignore
use std::fmt::Display;

struct Inspector<'a, 'b, T, U: Display>(&'a u8, &'b u8, T, U);

unsafe impl<'a, #[may_dangle] 'b, #[may_dangle] T, U: Display> Drop for Inspector<'a, 'b, T, U> {
    fn drop(&mut self) {
        println!("Inspector({}, _, _, {})", self.0, self.3);
    }
}
```

It is sometimes obvious that no such access can occur, like the case above.
However, when dealing with a generic type parameter, such access can
occur indirectly. Examples of such indirect access are:

 * invoking a callback,
 * via a trait method call.

(Future changes to the language, such as impl specialization, may add
other avenues for such indirect access.)

Here is an example of invoking a callback:

```rust,ignore
struct Inspector<T>(T, &'static str, Box<for <'r> fn(&'r T) -> String>);

impl<T> Drop for Inspector<T> {
    fn drop(&mut self) {
        // The `self.2` call could access a borrow e.g. if `T` is `&'a _`.
        println!("Inspector({}, {}) unwittingly inspects expired data.",
                 (self.2)(&self.0), self.1);
    }
}
```

Here is an example of a trait method call:

```rust,ignore
use std::fmt;

struct Inspector<T: fmt::Display>(T, &'static str);

impl<T: fmt::Display> Drop for Inspector<T> {
    fn drop(&mut self) {
        // There is a hidden call to `<T as Display>::fmt` below, which
        // could access a borrow e.g. if `T` is `&'a _`
        println!("Inspector({}, {}) unwittingly inspects expired data.",
                 self.0, self.1);
    }
}
```

And of course, all of these accesses could be further hidden within
some other method invoked by the destructor, rather than being written
directly within it.

In all of the above cases where the `&'a u8` is accessed in the
destructor, adding the `#[may_dangle]`
attribute makes the type vulnerable to misuse that the borrower
checker will not catch, inviting havoc. It is better to avoid adding
the attribute.

# Is that all about drop checker?

It turns out that when writing unsafe code, we generally don't need to
worry at all about doing the right thing for the drop checker. However there
is one special case that you need to worry about, which we will look at in
the next section.

