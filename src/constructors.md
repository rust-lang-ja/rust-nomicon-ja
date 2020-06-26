<!--
# Constructors
-->

# コンストラクタ

<!--
There is exactly one way to create an instance of a user-defined type: name it,
and initialize all its fields at once:
-->

ユーザが定義した型のインスタンスを作る方法はただ一つしかありません: 型名を決めて、
全てのフィールドをいっぺんに初期化することです。

```rust
struct Foo {
    a: u8,
    b: u32,
    c: bool,
}

enum Bar {
    X(u32),
    Y(bool),
}

struct Unit;

let foo = Foo { a: 0, b: 1, c: false };
let bar = Bar::X(0);
let empty = Unit;
```

<!--
That's it. Every other way you make an instance of a type is just calling a
totally vanilla function that does some stuff and eventually bottoms out to The
One True Constructor.
-->

以上。これ以外の型のインスタンスを作る方法は皆、単にいくつかのことを行なう全く普通の
関数を呼び、結局 1 つの真のコンストラクタに辿り着くのです。

<!--
Unlike C++, Rust does not come with a slew of built-in kinds of constructor.
There are no Copy, Default, Assignment, Move, or whatever constructors. The
reasons for this are varied, but it largely boils down to Rust's philosophy of
*being explicit*.
-->

C++ と違い、 Rust は沢山の組み込みコンストラクタを備えていません。
 Rust には、 Copy、 Default、 Assignment、 Moveやその他諸々のコンストラクタが
ありません。理由は様々ですが、大体 Rust の考え方である、*明確であること*、という事に
落ち着きます。

<!--
Move constructors are meaningless in Rust because we don't enable types to
"care" about their location in memory. Every type must be ready for it to be
blindly memcopied to somewhere else in memory. This means pure on-the-stack-but-
still-movable intrusive linked lists are simply not happening in Rust (safely).
-->
Move コンストラクタは Rust においては意味がありません。なぜなら、型が、自身の
メモリ上の場所を "気にする" ようにはしないからです。すべての型は何もしなくても、
メモリ中のどこか別の場所にコピー出来るよう準備されなければなりません。
これは、純粋な、スタック上にあるけれどもそれでも動かすことの出来る、
あるノードの次のノードへのポインタをそのノード自身が保持する線形リストは (安全には) 存在し得ない
事を意味します。

<!--
Assignment and copy constructors similarly don't exist because move semantics
are the only semantics in Rust. At most `x = y` just moves the bits of y into
the x variable. Rust does provide two facilities for providing C++'s copy-
oriented semantics: `Copy` and `Clone`. Clone is our moral equivalent of a copy
constructor, but it's never implicitly invoked. You have to explicitly call
`clone` on an element you want to be cloned. Copy is a special case of Clone
where the implementation is just "copy the bits". Copy types *are* implicitly
cloned whenever they're moved, but because of the definition of Copy this just
means not treating the old copy as uninitialized -- a no-op.
-->

Assignment コンストラクタや Copy コンストラクタも同様に存在しません。
なぜなら、ムーブセマンティクスは Rust における唯一のセマンティクスだからです。
せいぜい `x = y` が単に y のビットを変数 x に移すくらいです。 Rust では C++ の
コピー指向のセマンティクスを提供する、 2 つの機能があります。 `Copy` と `Clone` です。 Clone は Copy コンストラクタと
同じようなものですが、暗黙に呼び出されることは一切ありません。クローンを生成したい要素に対して、
明示的に `clone` を呼び出す必要があります。 Copy は Clone の特別なケースで、
実装は単純に "ビットをコピーする" ことです。 Copy を実装する型は、
ムーブが発生すると毎回クローンを生成*します*。しかし、 Copy の定義によって、
これは、古いコピーを初期化されていないとは扱わない事を単に意味します。つまり no-op なのです。

<!--
While Rust provides a `Default` trait for specifying the moral equivalent of a
default constructor, it's incredibly rare for this trait to be used. This is
because variables [aren't implicitly initialized][uninit]. Default is basically
only useful for generic programming. In concrete contexts, a type will provide a
static `new` method for any kind of "default" constructor. This has no relation
to `new` in other languages and has no special meaning. It's just a naming
convention.
-->

Rust は Default コンストラクタと同等のものを指定する、 `Default` トレイトを
提供していますが、このトレイトが使用されるのは驚くほど稀です。なぜなら、
変数は[暗黙には初期化されない][uninit]からです。 Default は、
基本的にはジェネリックプログラミングでのみ有用です。具体例では、
あらゆる種類の "デフォルトの" コンストラクタに対して、このトレイトを実装する型が静的な `new` メソッドを
提供します。これは他の言語における `new` とは関係がなく、特に意味はありません。
これはただの命名規則です。

<!--
TODO: talk about "placement new"?
-->

TODO: "placement new" について話す?

[uninit]: uninitialized.html
