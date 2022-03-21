<!--
# Lifetimes
-->

# ライフタイム

<!--
Rust enforces these rules through *lifetimes*. Lifetimes are effectively
just names for scopes somewhere in the program. Each reference,
and anything that contains a reference, is tagged with a lifetime specifying
the scope it's valid for.
-->

Rust は今まで説明してきたルールを*ライフタイム*を使って強制します。
ライフタイムとは、要するにプログラム中のスコープの名前です。
参照と、参照を含むものとは、有効なスコープを示すライフタイムでタグ付けられています。

<!--
Within a function body, Rust generally doesn't let you explicitly name the
lifetimes involved. This is because it's generally not really necessary
to talk about lifetimes in a local context; Rust has all the information and
can work out everything as optimally as possible. Many anonymous scopes and
temporaries that you would otherwise have to write are often introduced to
make your code Just Work.
-->

通常、関数本体では、関係するライフタイムの名前を明示することは求められません。
一般に、ローカルコンテキストにおいてライフタイムを気にする必要はまずないからです。
Rust はすべての情報を持っていて、可能な限りすべてを最適にできます。
省略可能な無名スコープや一時変数は、コードがきちんと動くように自動的に導入されます。

<!--
However once you cross the function boundary, you need to start talking about
lifetimes. Lifetimes are denoted with an apostrophe: `'a`, `'static`. To dip
our toes with lifetimes, we're going to pretend that we're actually allowed
to label scopes with lifetimes, and desugar the examples from the start of
this chapter.
-->

しかし関数の境界を超えると、ライフタイムについて気にしなくてはいけなくなります。
ライフタイムは、`'a` や `'static` などアポストロフィーつきの名前を持ちます。
ライフタイムの世界に足を踏み入れるために、
スコープにライフタイムのラベルをつけられるとして、この章の最初のサンプルコードを
「脱糖 (desugar)」してみましょう。

<!--
Originally, our examples made use of *aggressive* sugar -- high fructose corn
syrup even -- around scopes and lifetimes, because writing everything out
explicitly is *extremely noisy*. All Rust code relies on aggressive inference
and elision of "obvious" things.
-->

もともとのサンプルコードは、スコープとライフタイムについて、
果糖がたくさん含まれたコーンシロップのように*強烈に*甘い書き方でした。
（訳注：ライフタイムを省略できることは syntax sugar で、元のコードは大量の syntax sugar を使っているので、「甘い」と言っている）
なぜなら、すべてを明示的に書くのは*極めて煩わしい*からです。
Rust のコードは、積極的な推論と「明らかな」ことの省略とを当てにしています。

<!--
One particularly interesting piece of sugar is that each `let` statement implicitly
introduces a scope. For the most part, this doesn't really matter. However it
does matter for variables that refer to each other. As a simple example, let's
completely desugar this simple piece of Rust code:
-->

`let` 文が、スコープを暗黙的に導入するというのは、興味深いシンタックスシュガーでしょう。
ほとんどの場合、これは問題になりません。
しかし、複数の変数がお互いを参照している場合は問題になります。
簡単な例として、この単純な Rust コードを脱糖してみましょう。

```rust
let x = 0;
let y = &x;
let z = &y;
```

<!--
The borrow checker always tries to minimize the extent of a lifetime, so it will
likely desugar to the following:
-->

借用チェッカは、ライフタイムの長さを最小にしようとするので、
これは次のように脱糖されるでしょう。

```rust,ignore
// `'a: {` と `&'b x` は正当な構文ではないことに注意してください!
'a: {
    let x: i32 = 0;
    'b: {
        // ここで使用されるライフタイムは 'b です。なぜなら 'b で十分だからです。
        let y: &'b i32 = &'b x;
        'c: {
            // 'c も同様
            let z: &'c &'b i32 = &'c y;
        }
    }
}
```

<!--
Wow. That's... awful. Let's all take a moment to thank Rust for making this easier.
-->

おっと。こんなふうに書かなければいけないとしたら・・・これはひどいですね。
ここでしばらく時間をとって、簡単な構文を許してくれる Rust に感謝の意を表しましょう。

<!--
Actually passing references to outer scopes will cause Rust to infer
a larger lifetime:
-->

参照を外のスコープに返す場合は、Rust はより大きいライフタイムを推論することになります。

```rust
let x = 0;
let z;
let y = &x;
z = y;
```

```rust,ignore
'a: {
    let x: i32 = 0;
    'b: {
        let z: &'b i32;
        'c: {
            // ここでは 'b を使う必要があります。なぜならこの参照は
            // スコープ `b に渡されるからです。
            let y: &'b i32 = &'b x;
            z = y;
        }
    }
}
```


<!--
# Example: references that outlive referents
-->

# 例：参照先より長く生きる参照

<!--
Alright, let's look at some of those examples from before:
-->

それでは、以前に出した例を見てみましょう。

```rust,ignore
fn as_str(data: &u32) -> &str {
    let s = format!("{}", data);
    &s
}
```

<!--
desugars to:
-->

は次のように脱糖されます。

```rust,ignore
fn as_str<'a>(data: &'a u32) -> &'a str {
    'b: {
        let s = format!("{}", data);
        return &'a s;
    }
}
```

<!--
This signature of `as_str` takes a reference to a u32 with *some* lifetime, and
promises that it can produce a reference to a str that can live *just as long*.
Already we can see why this signature might be trouble. That basically implies
that we're going to find a str somewhere in the scope the reference
to the u32 originated in, or somewhere *even earlier*. That's a bit of a tall
order.
-->

`as_str` のシグネチャは、*ある*ライフタイムを持つ u32 への参照をとり、
その参照と*同じ長さだけ*生きる str への参照を生成することを約束します。
このシグネチャが問題になるかもしれないと、すでに話しました。
このシグネチャは、引数の u32 を指す参照が生成されたスコープか、もしくは*それより以前のスコープ*で、str を探すことを意味します。これはなかなか難しい注文です。

<!--
We then proceed to compute the string `s`, and return a reference to it. Since
the contract of our function says the reference must outlive `'a`, that's the
lifetime we infer for the reference. Unfortunately, `s` was defined in the
scope `'b`, so the only way this is sound is if `'b` contains `'a` -- which is
clearly false since `'a` must contain the function call itself. We have therefore
created a reference whose lifetime outlives its referent, which is *literally*
the first thing we said that references can't do. The compiler rightfully blows
up in our face.
-->

それから文字列 `s` を計算し、その参照を返します。
この関数は、返される参照が `'a` より長生きすることを約束しているので、この参照のライフタイムとして `'a` を使うことを推論します。
残念なことに、`s` はスコープ `'b` の中で定義されているので、
この推論が妥当になるためには、`'b` が `'a` を含んでいなくてはなりません。
ところがこれは明らかに成立しません。`'a` はこの関数呼び出しそのものを含んでいるからです。
結局、この関数は参照先より長生きする参照を生成してしまいました。
そしてこれは*文字通り*、参照がやってはいけないことの一番目でした。
コンパイラは正当に怒りだします。

<!--
To make this more clear, we can expand the example:
-->

よりわかりやすくするために、この例を拡張してみます。

```rust,ignore
fn as_str<'a>(data: &'a u32) -> &'a str {
    'b: {
        let s = format!("{}", data);
        return &'a s
    }
}

fn main() {
    'c: {
        let x: u32 = 0;
        'd: {
            // この x の借用は、x が有効な全期間より短くて良いので、無名スコープが導入されます。
            // as_str は、この呼び出しより前のどこかにある str を見つけなければいけませんが、
            // そのような str が無いのはあきらかです。
            println!("{}", as_str::<'d>(&'d x));
        }
    }
}
```

<!--
Shoot!
-->

ちくしょう！

<!--
Of course, the right way to write this function is as follows:
-->

この関数を正しく書くと、当然次のようになります。

```rust
fn to_string(data: &u32) -> String {
    format!("{}", data)
}
```

<!--
We must produce an owned value inside the function to return it! The only way
we could have returned an `&'a str` would have been if it was in a field of the
`&'a u32`, which is obviously not the case.
-->

この関数が所有する値を関数内で生成し、それを返さなくてはいけません！
str が `&'a u32` のフィールドだとしたら、`&'a str` を返せるのですが、
もちろんそれはありえません。

<!--
(Actually we could have also just returned a string literal, which as a global
can be considered to reside at the bottom of the stack; though this limits
our implementation *just a bit*.)
-->

（そういえば、単に文字列リテラルを返すこともできたかもしれません。
文字列リテラルはグローバルで、スタックの底に存在すると解釈できますから。
ただこれはこの関数の実装を*ほんの少しだけ*制限してしまいますね。）

<!--
# Example: aliasing a mutable reference
-->

# 例：可変参照の別名付け

<!--
How about the other example:
-->

もう一つの例はどうでしょう。

```rust,ignore
let mut data = vec![1, 2, 3];
let x = &data[0];
data.push(4);
println!("{}", x);
```

```rust,ignore
'a: {
    let mut data: Vec<i32> = vec![1, 2, 3];
    'b: {
        // スコープ 'b は次の貸し出しに必要なだけ大きくなります。
        // （`println!` を含むまで大きくなります）
        let x: &'b i32 = Index::index::<'b>(&'b data, 0);
        'c: {
            // &mut は長生きする必要が無いので、一時的なスコープ 'c が作られます。
            Vec::push(&'c mut data, 4);
        }
        println!("{}", x);
    }
}
```

<!--
The problem here is a bit more subtle and interesting. We want Rust to
reject this program for the following reason: We have a live shared reference `x`
to a descendant of `data` when we try to take a mutable reference to `data`
to `push`. This would create an aliased mutable reference, which would
violate the *second* rule of references.
-->

これは、すこし分かりにくいですが面白い問題です。
私たちは、Rust が次のような理由で、このプログラムを拒否するだろうと思っています。
つまり、`push` するために `data` への可変参照を取ろうとするとき、
`data` の子孫への共有参照 `x` が生存中です。
これは可変参照の別名となり、参照の*二番目*のルールに違反します。

<!--
However this is *not at all* how Rust reasons that this program is bad. Rust
doesn't understand that `x` is a reference to a subpath of `data`. It doesn't
understand Vec at all. What it *does* see is that `x` has to live for `'b` to
be printed. The signature of `Index::index` subsequently demands that the
reference we take to `data` has to survive for `'b`. When we try to call `push`,
it then sees us try to make an `&'c mut data`. Rust knows that `'c` is contained
within `'b`, and rejects our program because the `&'b data` must still be live!
-->

ところが、Rust がこのプログラムを悪いと推論するやり方は*全く違う*のです。
Rust は、`x` が `data` の部分パスへの参照であることは理解しません。
Rust は Vec のことなど何も知らないのです。
Rust に*見えている*のは、`x` は println! のためにスコープ `'b` の中で生存しなくてはならないことです。
さらに、`Index::index` のシグネチャは、`data` を参照する参照が
スコープ `'b` の中で生存することを要求します。
`push` を呼び出すときに、`&'c mut data` を取ろうとすることを Rust は理解します。
Rust はスコープ `'c` が スコープ `'b` に含まれていることを知っているので、
このプログラムを拒否します。
なぜなら、`&'b data` はまだ生きているからです。


<!--
Here we see that the lifetime system is much more coarse than the reference
semantics we're actually interested in preserving. For the most part, *that's
totally ok*, because it keeps us from spending all day explaining our program
to the compiler. However it does mean that several programs that are totally
correct with respect to Rust's *true* semantics are rejected because lifetimes
are too dumb.
-->

ここでは、ライフタイムをチェックするシステムは、私たちが維持したい参照の意味論に比べて
とても粗いことを見てきました。
ほとんどの場合、*これで全く大丈夫*です。
私たちが書いたコードをコンパイラに説明するために丸一日費やさなくてもいいからです。
しかし、ライフタイムのチェックがとてもバカなために、Rust の*真の*意味論的には全く正しいプログラムでも拒否されることがあるのです。
