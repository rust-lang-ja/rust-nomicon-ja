<!--
# Ownership and Lifetimes
-->

# 所有権とライフタイム

<!--
Ownership is the breakout feature of Rust. It allows Rust to be completely
memory-safe and efficient, while avoiding garbage collection. Before getting
into the ownership system in detail, we will consider the motivation of this
design.
-->

所有権は Rust が爆発的に有名になるきっかけとなった機能です。
所有権により、Rust は完全にメモリ安全かつ、ガーベジコレクションがないため効率的になります。
所有権の詳細に立ち入る前に、この機能がなぜ必要なのかを考えてみましょう。

<!--
We will assume that you accept that garbage collection (GC) is not always an
optimal solution, and that it is desirable to manually manage memory in some
contexts. If you do not accept this, might I interest you in a different
language?
-->

ガーベジコレクション（GC）が常に最適なソリューションではないこと、
手動のメモリ管理の方が望ましいケースもあることには異論はないと思います。
もしそう思わないなら、別の言語に興味を持った方が良いですよ?

<!--
Regardless of your feelings on GC, it is pretty clearly a *massive* boon to
making code safe. You never have to worry about things going away *too soon*
(although whether you still wanted to be pointing at that thing is a different
issue...). This is a pervasive problem that C and C++ programs need to deal
with. Consider this simple mistake that all of us who have used a non-GC'd
language have made at one point:
-->

あなたが GC のことをどう思っていようとも、GC はコードを安全にするために*とてつもない*恩恵をもたらしました。
オブジェクトが*早すぎるタイミングで*消えてしまう心配が全く必要ないんです。
（とはいえ、そのオブジェクトへのポインタをその時点まで保有しておくべきかどうかというのは別の問題ですが・・・）
これは、C や C++ プログラムが対処しなければならない、広範囲に広がっている問題です。
GC の無い言語を使ったことのあるひとなら誰でも一度はやってしまった、この単純な間違いを見てみましょう。


```rust,ignore
fn as_str(data: &u32) -> &str {
    // 文字列を生成する
    let s = format!("{}", data);

    // しまった! この関数内でしか存在しないオブジェクトへの
    // 参照を返してしまった!
    // ダングリングポインタだ! メモリ解放後の参照だ! うわーー!
    // （このコードは Rust ではコンパイルエラーになります）
    &s
}
```

<!--
This is exactly what Rust's ownership system was built to solve.
Rust knows the scope in which the `&s` lives, and as such can prevent it from
escaping. However this is a simple case that even a C compiler could plausibly
catch. Things get more complicated as code gets bigger and pointers get fed through
various functions. Eventually, a C compiler will fall down and won't be able to
perform sufficient escape analysis to prove your code unsound. It will consequently
be forced to accept your program on the assumption that it is correct.
-->

これこそが、Rust の所有権システムが解決する問題なのです。
Rust は `&s` が生存するスコープを理解し、`&s` がそのスコープ外に逃げることを防ぎます。
しかし、この単純なケースは、C コンパイラですらうまいこと防ぐことができるでしょう。
コードが大きくなり、様々な関数にポインタが渡されるようになると、やっかいなことになります。
いずれ C コンパイラは、十分なエスケープ解析ができなくなり、コードが健全である証明に失敗し、屈服することになるのです。
結果的に、C コンパイラはあなたのプログラムが正しいと仮定して、それを受け入れることを強制されます。

<!--
This will never happen to Rust. It's up to the programmer to prove to the
compiler that everything is sound.
-->

これは Rust では決して起こりません。全てが健全であるとコンパイラに証明するのはプログラマの責任なのです。

<!--
Of course, Rust's story around ownership is much more complicated than just
verifying that references don't escape the scope of their referent. That's
because ensuring pointers are always valid is much more complicated than this.
For instance in this code,
-->

もちろん、参照が参照先のスコープから逃げ出していないことを検証することよりも
所有権に関する Rust の話はもっともっと複雑です。
ポインタが常に有効であることを証明するのは、もっともっと複雑だからです。
例えばこのコードを見てみましょう。

```rust,ignore
let mut data = vec![1, 2, 3];
// 内部データの参照を取る
let x = &data[0];

// しまった! `push` によって `data` の格納先が再割り当てされてしまった。
// ダングリングポインタだ! メモリ解放後の参照だ! うわーー!
// （このコードは Rust ではコンパイルエラーになります）
data.push(4);

println!("{}", x);
```

<!--
naive scope analysis would be insufficient to prevent this bug, because `data`
does in fact live as long as we needed. However it was *changed* while we had
a reference into it. This is why Rust requires any references to freeze the
referent and its owners.
-->

単純なスコープ解析では、このバグは防げません。
`data` のライフタイムは十分に長いからです。
問題は、その参照を保持している間に、参照先が*変わって*しまったことです。
Rust で参照を取ると、参照先とその所有者がフリーズされるのは、こういう理由なのです。
