<!--
# Alternative representations
-->

# 代替メモリレイアウト

<!--
Rust allows you to specify alternative data layout strategies from the default.
-->

Rust では、デフォルトとは異なる、代替のデータレイアウトを指定することができます。


# repr(C)

<!--
This is the most important `repr`. It has fairly simple intent: do what C does.
The order, size, and alignment of fields is exactly what you would expect from C
or C++. Any type you expect to pass through an FFI boundary should have
`repr(C)`, as C is the lingua-franca of the programming world. This is also
necessary to soundly do more elaborate tricks with data layout such as
reinterpreting values as a different type.
-->

これは最も重要な `repr` です。意味はとても単純で、「C がやるようにやれ」です。
フィールドの順序、サイズ、アラインメントが、C や C++ に期待するのと全く同じになります。
FFI 境界を超えるであろう型は、すべて `repr(C)` になるべきです。
C はプログラミング界の共通言語なのですから。
また、値を別の型として再解釈する、といった複雑なトリックをやる場合にも `repr(C)` は必須です。

<!--
However, the interaction with Rust's more exotic data layout features must be
kept in mind. Due to its dual purpose as "for FFI" and "for layout control",
`repr(C)` can be applied to types that will be nonsensical or problematic if
passed through the FFI boundary.
-->

しかし、Rust の風変わりなデータレイアウト機能との相互作用も忘れてはいけません。
「FFI のため」と「データレイアウトのため」という二つの目的があるため、
FFI 境界を超えることが無意味または問題になるような型にも `repr(C)` は適用されます。

<!--
* ZSTs are still zero-sized, even though this is not a standard behavior in
C, and is explicitly contrary to the behavior of an empty type in C++, which
still consumes a byte of space.

* DSTs, tuples, and tagged unions are not a concept in C and as such are never
FFI safe.

* Tuple structs are like structs with regards to `repr(C)`, as the only
  difference from a struct is that the fields aren’t named.

* **If the type would have any [drop flags], they will still be added**

* This is equivalent to one of `repr(u*)` (see the next section) for enums. The
chosen size is the default enum size for the target platform's C ABI. Note that
enum representation in C is implementation defined, so this is really a "best
guess". In particular, this may be incorrect when the C code of interest is
compiled with certain flags.
-->

* ZST のサイズはやはり 0 になります。これは C の標準的な挙動ではないし、C++ の挙動
（空の型も 1 byte を消費します）とは明確に異なります。

* DST, タプル, タグ付き共用体という概念は C には存在しないため、FFI では安全に使えません。

* `repr(C)` を適用した状況では、タプルは構造体と似ています。構造体との違いは、フィールドに名前がないことだけです。

* **型に [drop flags] が付いていても、その型は追加されます。**

* enum については、`repr(u*)` （次のセクションで説明します）と同等です。選んだサイズが、対象となるプラットフォームの C ABI でのデフォルトの enum のサイズとなります。C での enum のデータ表現は実装依存なので、これはベストの推測でしかないことに注意してください。とくに、対象の C コードが特定のフラグつきでコンパイルされた場合に、正しく動かないかもしれません。

<!--
# repr(u8), repr(u16), repr(u32), repr(u64)
-->

# repr(u8), repr(u16), repr(u32), repr(u64)

<!--
These specify the size to make a C-like enum. If the discriminant overflows the
integer it has to fit in, it will produce a compile-time error. You can manually
ask Rust to allow this by setting the overflowing element to explicitly be 0.
However Rust will not allow you to create an enum where two variants have the
same discriminant.
-->

これらは、enum を C っぽくレイアウトするように指示します。
enum の要素が指定した整数をオーバーフローする場合、コンパイルエラーとなります。
オーバーフローする値を 0 に設定するよう Rust に指定することもできますが、
2 つの異なる enum 要素が同じ値を取ることはできません。

<!--
On non-C-like enums, this will inhibit certain optimizations like the null-
pointer optimization.
-->

C っぽくない enum （訳注：要素がパラメタをとるような enum）に `repr(u*)` を適用すると、
null ポインタ最適化のようなある種の最適化ができなくなります。

<!--
These reprs have no effect on a struct.
-->

この repr を構造体につかっても効果はありません。


<!--
# repr(packed)
-->

# repr(packed)

<!--
`repr(packed)` forces Rust to strip any padding, and only align the type to a
byte. This may improve the memory footprint, but will likely have other negative
side-effects.
-->

`repr(packed)` を使うと Rust はパディングを一切取り除き、すべてを byte 単位にアラインします。
メモリ使用量は改善しますが、悪い副作用を引き起こす可能性が高いです。

<!--
In particular, most architectures *strongly* prefer values to be aligned. This
may mean the unaligned loads are penalized (x86), or even fault (some ARM
chips). For simple cases like directly loading or storing a packed field, the
compiler might be able to paper over alignment issues with shifts and masks.
However if you take a reference to a packed field, it's unlikely that the
compiler will be able to emit code to avoid an unaligned load.
-->

特にほとんどのアークテクチャは、値がアラインされていることを*強く*望んでいます。
つまりアラインされていないデータの読み込みにはペナルティがある（x86）かもしれませんし、
失敗する（いくつかの ARM チップ）かもしれません。
パックされたフィールドを直接読んだり書いたりするという単純なケースでは、
コンパイラがシフトやマスクを駆使してアラインメントの問題を隠してくれるかもしれません。
しかし、パックされたフィールドへのリファレンスを扱う場合には、アラインされてない読み込みを避けるような
コードをコンパイラが生成することは期待できないでしょう。

<!--
**[As of Rust 1.0 this can cause undefined behavior.][ub loads]**

`repr(packed)` is not to be used lightly. Unless you have extreme requirements,
this should not be used.

This repr is a modifier on `repr(C)` and `repr(rust)`.
-->

**[Rust 1.0 時点では、これは未定義な挙動です。][ub loads]**

`repr(packed)` は気軽に使えるものではありません。
極端な要求に応えようとしているのでない限り、使うべきではありません。

この repr は `repr(C)` や `repr(rust)` の就職誌として使えます。

[drop flags]: drop-flags.md
[ub loads]: https://github.com/rust-lang/rust/issues/27060
