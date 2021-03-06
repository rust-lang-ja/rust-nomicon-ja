<!--
# Casts
-->

# キャスト

<!--
Casts are a superset of coercions: every coercion can be explicitly
invoked via a cast. However some conversions require a cast.
While coercions are pervasive and largely harmless, these "true casts"
are rare and potentially dangerous. As such, casts must be explicitly invoked
using the `as` keyword: `expr as Type`.
-->

キャストは型強制のスーパーセットです。すなわち、全ての型強制は、キャストを通じて
明示的に引き起こすことが出来ます。しかし、いくつかの変換はキャストを必要とします。
型強制は普及していて、大体の場合、害はないのですが、これらの "真のキャスト" は稀で、
潜在的に危険です。ですから、キャストは `as` キーワードを用いて、明示的に
実行しなければなりません: `expr as Type`

<!--
True casts generally revolve around raw pointers and the primitive numeric
types. Even though they're dangerous, these casts are infallible at runtime.
If a cast triggers some subtle corner case no indication will be given that
this occurred. The cast will simply succeed. That said, casts must be valid
at the type level, or else they will be prevented statically. For instance,
`7u8 as bool` will not compile.
-->

真のキャストは一般的に、生ポインタやプリミティブ型の数値型に関係します。
真のキャストは危険ですが、これらのキャストは実行時に失敗しません。
もしキャストが何か微妙なコーナーケースを引き起こしたとしても、
何の指摘もされないでしょう。キャストは単に成功します。そうは言ったものの、
キャストは型レベルで正しくなければなりません。でなければそのキャストは静的に
防がれます。例えば、 `7u8 as bool` はコンパイルできません。

<!--
That said, casts aren't `unsafe` because they generally can't violate memory
safety *on their own*. For instance, converting an integer to a raw pointer can
very easily lead to terrible things. However the act of creating the pointer
itself is safe, because actually using a raw pointer is already marked as
`unsafe`.
-->

そうは言っていますが、キャストは `unsafe` ではありません。なぜなら、
キャストは一般的に、*それ自体で*メモリ安全性を侵害しないからです。
例えば、整数を生ポインタに変換すると、非常に簡単にひどい問題を引き起しうるでしょう。
しかしながら、ポインタを生成する事自体は安全です。なぜなら、実際に生ポインタを使用すること
が既に `unsafe` としてマークされているからです。

<!--
Here's an exhaustive list of all the true casts. For brevity, we will use `*`
to denote either a `*const` or `*mut`, and `integer` to denote any integral
primitive:
-->

これは、全ての真のキャストを網羅しているリストです。簡潔にするため、 `*` を `*const` か `*mut` の
どちらかとして使い、 `integer` を整数型プリミティブの何かとして用います。

<!--
 * `*T as *U` where `T, U: Sized`
 * `*T as *U` TODO: explain unsized situation
 * `*T as integer`
 * `integer as *T`
 * `number as number`
 * `C-like-enum as integer`
 * `bool as integer`
 * `char as integer`
 * `u8 as char`
 * `&[T; n] as *const T`
 * `fn as *T` where `T: Sized`
 * `fn as integer`
 -->

 * `*T as *U` 但し `T, U: Sized`
 * `*T as *U` TODO: サイズが不定の場合について説明する
 * `*T as integer`
 * `integer as *T`
 * `number as number`
 * `C-like-enum as integer`
 * `bool as integer`
 * `char as integer`
 * `u8 as char`
 * `&[T; n] as *const T`
 * `fn as *T` 但し `T: Sized`
 * `fn as integer`

 <!--
Note that lengths are not adjusted when casting raw slices -
`*const [u16] as *const [u8]` creates a slice that only includes
half of the original memory.
-->

生スライスをキャストする時、その長さは調整されないことに注意してください。 `*const [u16] as *const [u8]` は、
元のメモリの半分しか含まないスライスを生成します。

<!--
Casting is not transitive, that is, even if `e as U1 as U2` is a valid
expression, `e as U2` is not necessarily so.
-->

キャストは推移的ではありません。つまり、 `e as U1 as U2` が有効な式だとしても、 `e as U2` は
必ずしも有効とは限りません。

<!--
For numeric casts, there are quite a few cases to consider:
-->

数値のキャストに関しては、かなり多くの事項について考える必要があります。

<!--
* casting between two integers of the same size (e.g. i32 -> u32) is a no-op
* casting from a larger integer to a smaller integer (e.g. u32 -> u8) will
  truncate
* casting from a smaller integer to a larger integer (e.g. u8 -> u32) will
    * zero-extend if the source is unsigned
    * sign-extend if the source is signed
* casting from a float to an integer will round the float towards zero
    * **[NOTE: currently this will cause Undefined Behavior if the rounded
      value cannot be represented by the target integer type][float-int]**.
      This includes Inf and NaN. This is a bug and will be fixed.
* casting from an integer to float will produce the floating point
  representation of the integer, rounded if necessary (rounding strategy
  unspecified)
* casting from an f32 to an f64 is perfect and lossless
* casting from an f64 to an f32 will produce the closest possible value
  (rounding strategy unspecified)
    * **[NOTE: currently this will cause Undefined Behavior if the value
      is finite but larger or smaller than the largest or smallest finite
      value representable by f32][float-float]**. This is a bug and will
      be fixed.
-->

* 同じ大きさの 2 つの整数の間でのキャスト (例: i32 -> u32) は no-op です
* 大きい方の整数から小さい方の整数へのキャスト (例: u32 -> u8) は切り捨てが発生します
* 小さい方の整数から大きい方の整数へのキャスト (例: u8 -> u32) は
    * もし小さい方の整数が符号なしの場合、ゼロ拡張されます
    * もし小さい方の整数が符号ありの場合、符号拡張されます
* 浮動小数点数から整数へのキャストは、小数点以下が切り捨てられます
    * **[注意: 現在もし丸められた値が、キャスト先の整数型で表現できない場合、未定義動作を引き起こします][float-int]**。
    これはバグで、将来修正されます。
* 整数から浮動小数点数へのキャストは、整数を浮動小数点数で表現します。必要ならば丸められます (丸めの方針は指定されていません)
* f32 から f64 へのキャストは完全で、損失はありません
* f64 から f32 へのキャストは、最も近い表現可能な値となります (丸めの方針は指定されていません)
    * **[注意: 現在もし値が f32 で表現可能な最大の値より大きい、あるいは最小の値より小さい有限の値である場合、未定義動作を引き起こします][float-float]**。
    これはバグで、将来修正されます。


[float-int]: https://github.com/rust-lang/rust/issues/10184
[float-float]: https://github.com/rust-lang/rust/issues/15536
