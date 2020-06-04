<!--
# Unbounded Lifetimes
-->

# 無制限のライフタイム

<!--
Unsafe code can often end up producing references or lifetimes out of thin air.
Such lifetimes come into the world as *unbounded*. The most common source of this
is dereferencing a raw pointer, which produces a reference with an unbounded lifetime.
Such a lifetime becomes as big as context demands. This is in fact more powerful
than simply becoming `'static`, because for instance `&'static &'a T`
will fail to typecheck, but the unbound lifetime will perfectly mold into
`&'a &'a T` as needed. However for most intents and purposes, such an unbounded
lifetime can be regarded as `'static`.
-->

アンセーフなコードはときに、参照やライフタイムを何も無いところから生み出したりします。
そのようなライフタイムは、*無制限* なライフタイムとして世界に登場します。
最もよくあるのは、生ポインタの参照外しをし、無制限のライフタイムを持つ参照を作り出すというケースです。
このライフタイムは、そのコンテキストが必要とするだけ大きくなります。そしてこれは `'static` よりも強力なしくみです。
`&'static &'a T` は型チェックをパスしませんが、無制限のライフタイムを使うと必要に応じて `&'a &'a T` となるからです。
しかし、ほとんどの意図と目的においては、無制限のライフタイムを `'static` と解釈できます。

<!--
Almost no reference is `'static`, so this is probably wrong. `transmute` and
`transmute_copy` are the two other primary offenders. One should endeavor to
bound an unbounded lifetime as quickly as possible, especially across function
boundaries.
-->

参照が `'static` であることはまずありえないので、これはおそらく間違っていると言えるでしょう。
おもに `transmute` と `transmute_copy` とがこの状況を作り出します。
できるだけ速く、とくに関数の境界では、無制限のライフタイムに制限をつけるように気をつけて下さい。

<!--
Given a function, any output lifetimes that don't derive from inputs are
unbounded. For instance:
-->

関数の入力から導出されない出力のライフタイムは無制限となります。例えば、

```rust,ignore
fn get_str<'a>() -> &'a str;
```

<!--
will produce an `&str` with an unbounded lifetime. The easiest way to avoid
unbounded lifetimes is to use lifetime elision at the function boundary.
If an output lifetime is elided, then it *must* be bounded by an input lifetime.
Of course it might be bounded by the *wrong* lifetime, but this will usually
just cause a compiler error, rather than allow memory safety to be trivially
violated.
-->

このコードは無制限のライフタイムを持った `&str` を生成します。
無制限のライフタイムを避ける最も簡単な方法は、関数境界でライフタイムを省略することです。
出力ライフタイムが省略された場合、入力ライフタイムで制限されなくては*いけません*。
もちろん、*間違った*ライフタイムで制限されるかもしれませんが、たいていの場合は、メモリ安全性が侵されるのではなく、コンパイルエラーにつながります。

<!--
Within a function, bounding lifetimes is more error-prone. The safest and easiest
way to bound a lifetime is to return it from a function with a bound lifetime.
However if this is unacceptable, the reference can be placed in a location with
a specific lifetime. Unfortunately it's impossible to name all lifetimes involved
in a function.
-->

関数内部でライフタイムを制限することは、エラーを生みやすくなります。
ライフタイムを制限する安全で簡単な方法は、制限つきライフタイムの関数から返される値を使うことです。
しかし、これができない場合は、その参照を特定のライフタイムがついた場所に置くと良いでしょう。
残念ながら、関数内のすべてのライフタイムに名前をつけるのは不可能です。
