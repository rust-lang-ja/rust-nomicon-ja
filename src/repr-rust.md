# repr(Rust)

<!--
First and foremost, all types have an alignment specified in bytes. The
alignment of a type specifies what addresses are valid to store the value at. A
value of alignment `n` must only be stored at an address that is a multiple of
`n`. So alignment 2 means you must be stored at an even address, and 1 means
that you can be stored anywhere. Alignment is at least 1, and always a power of
2. Most primitives are generally aligned to their size, although this is
platform-specific behavior. In particular, on x86 `u64` and `f64` may be only
aligned to 32 bits.
-->

最初に重要なこととして、すべての型はバイト単位で指定されたアラインメントに従います。
ある型のアラインメントは、値を格納する有効なアドレスを規定します。
アラインメント `n` の値は、`n` の倍数のアドレスにのみ格納できます。
つまりアラインメント 2 は、偶数アドレスにのみ格納できることを意味し、
アラインメント 1 はどこにでも格納できることになります。
アラインメントの最小値は 1 で、常に 2 のべき乗になります。
ほとんどのプリミティブ型はそのサイズにアラインメントされますが、
これはプラットフォーム依存の挙動です。
特に x86 では `u64` と `f64` は 32ビットにアラインされるかもしれません。

<!--
A type's size must always be a multiple of its alignment. This ensures that an
array of that type may always be indexed by offsetting by a multiple of its
size. Note that the size and alignment of a type may not be known
statically in the case of [dynamically sized types][dst].
-->

型のサイズは、常にそのアラインメントの倍数でなくてはなりません。
こうすることで、サイズの倍数をオフセットすることで、その型の配列のインデックスアクセスになります。
[動的にサイズが決まる型][dst] の場合、型のサイズとアラインメントは静的にはわからない場合があることに注意してください。

<!--
Rust gives you the following ways to lay out composite data:
-->

Rust では次の方法で複合データのメモリレイアウトを制御することができます。

<!--
* structs (named product types)
* tuples (anonymous product types)
* arrays (homogeneous product types)
* enums (named sum types -- tagged unions)
-->

* 構造体（名前付き直積型）
* タプル（名前なし直積型）
* 配列（同じ種類の型の直積型）
* enum（名前付き直交型。またはタグ付き共用体）

<!--
An enum is said to be *C-like* if none of its variants have associated data.
-->

enum のすべての要素が関連データを持たない場合、その enum は *C-like* と呼ばれます。

<!--
Composite structures will have an alignment equal to the maximum
of their fields' alignment. Rust will consequently insert padding where
necessary to ensure that all fields are properly aligned and that the overall
type's size is a multiple of its alignment. For instance:
-->

複合データのアラインメントは、その要素のうち最大のアラインメントと同じです。
そのために、Rust は必要なときにはパディングを挿入して、
すべてのフィールドが適切にアラインされ、
また全体のサイズがアラインメントの倍数になるようにします。
例えば、

```rust
struct A {
    a: u8,
    b: u32,
    c: u16,
}
```

<!--
will be 32-bit aligned on an architecture that aligns these primitives to their
respective sizes. The whole struct will therefore have a size that is a multiple
of 32-bits. It will potentially become:
-->

この構造体は、メンバーのプリミティブ型が対応するサイズにアラインされるアーキテクチャでは、
32ビットにアラインされます。そのため全体の構造体のサイズも 32ビットの倍数になります。
このようになるでしょう。

```rust
struct A {
    a: u8,
    _pad1: [u8; 3], // `b` のアラインメントのため
    b: u32,
    c: u16,
    _pad2: [u8; 2], // 全体のサイズを 4バイトの倍数にするため
}
```

<!--
There is *no indirection* for these types; all data is stored within the struct,
as you would expect in C. However with the exception of arrays (which are
densely packed and in-order), the layout of data is not by default specified in
Rust. Given the two following struct definitions:
-->

この構造体には *間接参照はありません*。C と同様に、すべてのデータは構造体の内部に格納されます。
しかし、配列は例外（配列は隙間なく順にパックされます）ですが、Rust ではデータレイアウトは
デフォルトでは規定されていません。以下の 2 つの構造体の定義を見てみましょう。

```rust
struct A {
    a: i32,
    b: u64,
}

struct B {
    a: i32,
    b: u64,
}
```

<!--
Rust *does* guarantee that two instances of A have their data laid out in
exactly the same way. However Rust *does not* currently guarantee that an
instance of A has the same field ordering or padding as an instance of B, though
in practice there's no reason why they wouldn't.
-->

Rust は A の 2 つのインスタンスが同じようにレイアウトされることを*保証します*。
しかし、A のインスタンスと B のインスタンスとが同じフィールド順や、同じパディングを持つことを
*保証しません*。（現実的には同じにならない理由はないのですが）

<!--
With A and B as written, this point would seem to be pedantic, but several other
features of Rust make it desirable for the language to play with data layout in
complex ways.
-->

この A, B の例では、レイアウトが保証されないなんて融通が利かないと思うかもしれませんが、
他の機能を考えると、Rust がデータレイアウトを複雑にいじくれるようにするのは好ましいのです。

<!--
For instance, consider this struct:
-->

例えば、次の構造体を見てみましょう。

```rust
struct Foo<T, U> {
    count: u16,
    data1: T,
    data2: U,
}
```

<!--
Now consider the monomorphizations of `Foo<u32, u16>` and `Foo<u16, u32>`. If
Rust lays out the fields in the order specified, we expect it to pad the
values in the struct to satisfy their alignment requirements. So if Rust
didn't reorder fields, we would expect it to produce the following:
-->

さて、単体化した `Foo<u32, u16>` と `Foo<u16, u32>` とを考えてみます。
もし Rust が指定された順にフィールドをレイアウトしなくてはならないとすると、
アラインメントの要求を満たすために、パディングしなくてはなりません。
つまりもし Rust がフィールドを並び替えられないとすると、次のような型を生成すると思われます。

```rust,ignore
struct Foo<u16, u32> {
    count: u16,
    data1: u16,
    data2: u32,
}

struct Foo<u32, u16> {
    count: u16,
    _pad1: u16,
    data1: u32,
    data2: u16,
    _pad2: u16,
}
```

<!--
The latter case quite simply wastes space. An optimal use of space therefore
requires different monomorphizations to have *different field orderings*.
-->

後者の例ははっきり言ってスペースの無駄遣いです。
したがって、スペースを最適に使うには、異なる単体化には*異なるフィールド順序*が必要になります。

<!--
**Note: this is a hypothetical optimization that is not yet implemented in Rust
1.0**
-->

**これは仮定の最適化で、Rust 1.0 ではまた実装されていないことに注意してください。**

<!--
Enums make this consideration even more complicated. Naively, an enum such as:
-->

Enum については、もっと複雑な検討が必要になります。つまり、この enum

```rust
enum Foo {
    A(u32),
    B(u64),
    C(u8),
}
```

<!--
would be laid out as:
-->

は、次のようにレイアウトされるでしょう。

```rust
struct FooRepr {
    data: u64, // `tag` によって、u64, u32, u8 のいずれかになります
    tag: u8,   // 0 = A, 1 = B, 2 = C
}
```

<!--
And indeed this is approximately how it would be laid out in general (modulo the
size and position of `tag`).
-->

実際にこれが、データが一般的にどのようにレイアウトされるかの大体の説明となります。

<!--
However there are several cases where such a representation is inefficient. The
classic case of this is Rust's "null pointer optimization": an enum consisting
of a single outer unit variant (e.g. `None`) and a (potentially nested) non-
nullable pointer variant (e.g. `&T`) makes the tag unnecessary, because a null
pointer value can safely be interpreted to mean that the unit variant is chosen
instead. The net result is that, for example, `size_of::<Option<&T>>() ==
size_of::<&T>()`.
-->

ところが、このような表現が非効率な場合もあります。
わかりやすい例としては、Rust の "null ポインタ最適化" があります。
これは、ある enum がデータを持たないメンバー（たとえば `None`）と、（ネストしてるかもしれない）null を取らないメンバー（たとえば `&T`）から構成される場合、null ポインタをデータを持たないメンバーと解釈することができるので、タグが不要になります。
その結果、たとえば `size_of::<Optiona<&T>>() == size_of::<&T>()` となります。

<!--
There are many types in Rust that are, or contain, non-nullable pointers such as
`Box<T>`, `Vec<T>`, `String`, `&T`, and `&mut T`. Similarly, one can imagine
nested enums pooling their tags into a single discriminant, as they are by
definition known to have a limited range of valid values. In principle enums could
use fairly elaborate algorithms to cache bits throughout nested types with
special constrained representations. As such it is *especially* desirable that
we leave enum layout unspecified today.
-->

Rust には、null ポインタになりえない型や、null ポインタを含まない型がたくさんあります。
例えば `Box<T>`, `Vec<T>`, `String`, `&T`, `&mut T` などです。
同様に、ネストした複数の enum が、タグを単一の判別子に押し込めることも考えられます。
タグが取り得る値は、定義により限られているからです。
原理的には、enum はとても複雑なアルゴリズムを使って、ネストした型を特別な制約のもとで表現し、
bit を隠すことができるでしょう。
このため、enum のレイアウトを規定しないでおくことは、現状では *特に* 好ましいのです。


[dst]: exotic-sizes.html#dynamically-sized-types-dsts
