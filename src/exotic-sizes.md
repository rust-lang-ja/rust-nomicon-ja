<!--
# Exotically Sized Types
-->

# 奇妙なサイズの型

<!--
Most of the time, we think in terms of types with a fixed, positive size. This
is not always the case, however.
-->

私たちは、型は 0 以上の固定サイズを持つと通常考えます。でも常にそうであるとは限りません。


<!--
# Dynamically Sized Types (DSTs)
-->

# 動的サイズの型（DST: Dynamically Sized Type）

<!--
Rust in fact supports Dynamically Sized Types (DSTs): types without a statically
known size or alignment. On the surface, this is a bit nonsensical: Rust *must*
know the size and alignment of something in order to correctly work with it! In
this regard, DSTs are not normal types. Due to their lack of a statically known
size, these types can only exist behind some kind of pointer. Any pointer to a
DST consequently becomes a *fat* pointer consisting of the pointer and the
information that "completes" them (more on this below).
-->

実際に、Rust は動的にサイズが決まる型（DST）、静的にはサイズやアラインメントがわからない型、
をサポートしています。
一見すると、これは少し馬鹿げているようです。型をうまく扱うためには、
サイズや型を知らなければ*いけない*ですから。
こう考えると DST は通常の型ではありません。サイズが静的にわからないので、
ある種のポインタの裏にしか存在できないのです。
DST を指すポインタは結果的に、普通のポインタと DST を補完する情報（以下で詳しく説明します）から構成される、
*太った* ポインタになります。

<!--
There are two major DSTs exposed by the language: trait objects, and slices.
-->

言語が提供する DST のうち重要なものが 2 つあります。トレイトオブジェクトとスライスです。

<!--
A trait object represents some type that implements the traits it specifies.
The exact original type is *erased* in favor of runtime reflection
with a vtable containing all the information necessary to use the type.
This is the information that completes a trait object: a pointer to its vtable.
-->

トレイトオブジェクトは、それが指すトレイトを実装するある型を表現します。
元となった型は消去されますが、vtable とリフレクションとによって実行時にはその型を利用することができます。
つまり、Trait オブジェクトを補完する情報とは vtable へのポインタとなります。

<!--
A slice is simply a view into some contiguous storage -- typically an array or
`Vec`. The information that completes a slice is just the number of elements
it points to.
-->

スライスとは、単純にある連続したスペース（通常は配列か `Vec`）のビューです。
スライスを補完する情報とは、単にポインタが指す要素の数です。

<!--
Structs can actually store a single DST directly as their last field, but this
makes them a DST as well:
-->

構造体は、最後のフィールドとして DST を直接含むことができますが、その構造体自体も DST になります。

```rust
// 直接スタックには置けません。
struct Foo {
    info: u32,
    data: [u8],
}
```

<!--
**NOTE: [As of Rust 1.0 struct DSTs are broken if the last field has
a variable position based on its alignment][dst-issue].**
-->

**[Rust 1.0 時点では、最後のフィールドが正しくアラインメントされていない DST 構造体は正しく動きません][dst-issue]**


<!--
# Zero Sized Types (ZSTs)
-->

# サイズが 0 の型（ZST: Zero Sized Type）

<!--

Rust actually allows types to be specified that occupy no space:
-->

Rust ではなんと、スペースを持たない型を使うことができます。

```rust
struct Foo; // フィールドがない = サイズ 0

// すべてのフィールドのサイズがない = サイズ 0
struct Baz {
    foo: Foo,
    qux: (),      // empty tuple has no size
    baz: [u8; 0], // empty array has no size
}
```

<!--
On their own, Zero Sized Types (ZSTs) are, for obvious reasons, pretty useless.
However as with many curious layout choices in Rust, their potential is realized
in a generic context: Rust largely understands that any operation that  produces
or stores a ZST can be reduced to a no-op. First off, storing it  doesn't even
make sense -- it doesn't occupy any space. Also there's only one  value of that
type, so anything that loads it can just produce it from the  aether -- which is
also a no-op since it doesn't occupy any space.
-->

サイズ 0 の型（ZST）は、当然ながら、それ自体ではほとんど価値があありません。
しかし、多くの興味深いレイアウトの選択肢と組み合わせると、ZST が潜在的に役に立つことがいろいろな
ケースで明らかになります。Rust は、ZST を生成したり保存したりするオペレーションが no-op に
還元できることを理解しています。
そもそも、ZST はスペースを要求しないので、保存することには意味がありません。
また ZST は 1 つの値しかとらないので、ZST を読み込む操作は、
代わりに無から ZST を作り出すことができ、この操作もスペースを必要としないので no-op と同じです。

<!--
One of the most extreme example's of this is Sets and Maps. Given a
`Map<Key, Value>`, it is common to implement a `Set<Key>` as just a thin wrapper
around `Map<Key, UselessJunk>`. In many languages, this would necessitate
allocating space for UselessJunk and doing work to store and load UselessJunk
only to discard it. Proving this unnecessary would be a difficult analysis for
the compiler.
-->

究極の ZST の利用法として、Set と Map を考えてみましょう。
`Map<Key, Value>` があるときに、`Set<Key>` を `Map<Key, UselessJunk>` の
簡単なラッパーとして実装することはよくあります。
多くの言語では、UselessJunk のスペースを割り当てる必要があるでしょうし、
結果的に使わない UselessJunk を保存したり読み込んだりする必要もあるでしょう。
こういったことが不要であると示すのはコンパイラにとっては難しい仕事でしょう。

<!--
However in Rust, we can just say that  `Set<Key> = Map<Key, ()>`. Now Rust
statically knows that every load and store is useless, and no allocation has any
size. The result is that the monomorphized code is basically a custom
implementation of a HashSet with none of the overhead that HashMap would have to
support values.
-->

しかし Rust では、単に `Set<Key> = Map<Key, ()>` と言えばいいだけなのです。
Rust は静的な解析で、読み込みや保存が無意味であること、メモリ割当が必要ないことを理解します。
結果として単態化したコードは、HashSet のためにカスタマイズされ、
HashMap を使う場合のオーバーヘッドはなくなります。

<!--
Safe code need not worry about ZSTs, but *unsafe* code must be careful about the
consequence of types with no size. In particular, pointer offsets are no-ops,
and standard allocators (including jemalloc, the one used by default in Rust)
may return `nullptr` when a zero-sized allocation is requested, which is
indistinguishable from out of memory.
-->

安全なコードは ZST について心配する必要はありませんが、*危険な* コードは
サイズ 0 の型を使った時の結果について注意しなくてはなりません。
特に、ポインタのオフセットは no-op になることや、
（Rust のデフォルトである jemalloc を含む）標準的なメモリアロケータは、
サイズ 0 の割り当て要求には `nullptr` を返すこと
（これはメモリ不足と区別がつきません）に注意してください。

<!--
# Empty Types
-->

# 空の型

<!--
Rust also enables types to be declared that *cannot even be instantiated*. These
types can only be talked about at the type level, and never at the value level.
Empty types can be declared by specifying an enum with no variants:
-->

Rust では、*インスタンスを生成できない*型を宣言することもできます。
こういう型は、型レベルの話にのみ出てきて、値レベルには出てきません。
空の型は、識別子を持たない enum として宣言できます。

```rust
enum Void {} // 識別子なし = 空
```

<!--
Empty types are even more marginal than ZSTs. The primary motivating example for
Void types is type-level unreachability. For instance, suppose an API needs to
return a Result in general, but a specific case actually is infallible. It's
actually possible to communicate this at the type level by returning a
`Result<T, Void>`. Consumers of the API can confidently unwrap such a Result
knowing that it's *statically impossible* for this value to be an `Err`, as
this would require providing a value of type `Void`.
-->

空の型は、ZST よりもまれにしか使いません。
空の型がもっとも必要になる例としては、型レベルの到達不可能性を示す時です。
例えば、ある API は、一般に Result を返す必要がありますが、
特定のケースでは絶対に失敗しないことがわかっているとします。
`Result<T, Void>` を返すことで、この事実を型レベルで伝えることが可能です。
Void 型の値を提供することはできないので、この Result は Err に*なり得ないと静的にわかります*。
そのため、この API の利用者は、自信を持って Result を unwrap することができます。

<!--
In principle, Rust can do some interesting analyses and optimizations based
on this fact. For instance, `Result<T, Void>` could be represented as just `T`,
because the `Err` case doesn't actually exist. The following *could* also
compile:
-->

原理的に、Rust ではこの事実をもとに、興味深い解析と最適化が可能です。
たとえば、`Result<T, Void>` は `Err` にはなり得ないので、
`T` と表現することができます。以下のコードがコンパイルに通るようにも*できる*でしょう。

```rust,ignore
enum Void {}

let res: Result<u32, Void> = Ok(0);

// Err は存在しないので、Ok になることに疑問の余地はありません。
let Ok(num) = res;
```

<!--
But neither of these tricks work today, so all Void types get you is
the ability to be confident that certain situations are statically impossible.
-->

ただし、どちらの例も現時点では動きません。
つまり、Void 型による利点は、静的な解析によて、特定の状況が起こらないと確実に言えることだけです。

<!--
One final subtle detail about empty types is that raw pointers to them are
actually valid to construct, but dereferencing them is Undefined Behavior
because that doesn't actually make sense. That is, you could model C's `void *`
type with `*const Void`, but this doesn't necessarily gain anything over using
e.g. `*const ()`, which *is* safe to randomly dereference.
-->

最後に細かいことを一つ。空の型を指す生のポインタを構成することは有効ですが、
それをデリファレンスすることは、意味がないので、未定義の挙動となります。
つまり、C における `void *` と同じような意味で `*const Void` を使うこと出来ますが、
これは、*安全に*デリファレンスできる型（例えば `*const ()`）と比べて何も利点はありません。


[dst-issue]: https://github.com/rust-lang/rust/issues/26403
