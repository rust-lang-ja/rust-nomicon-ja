<!-- # Meet Safe and Unsafe -->

# 安全と危険のご紹介

<!--
Programmers in safe "high-level" languages face a fundamental dilemma. On one
hand, it would be *really* great to just say what you want and not worry about
how it's done. On the other hand, that can lead to unacceptably poor
performance. It may be necessary to drop down to less clear or idiomatic
practices to get the performance characteristics you want. Or maybe you just
throw up your hands in disgust and decide to shell out to an implementation in
a less sugary-wonderful *unsafe* language.
-->

安全な「高級」言語のプログラマは、本質的なジレンマに直面します。何が欲しいかをただ伝えるだけで、
それがどのように実現されるかを悩む必要がないのは *本当に* 素晴らしいのですが、それが許容できないほどの
ひどいパフォーマンスをもたらすこともあります。
期待するパフォーマンスを得るために、明瞭で慣用的なやり方を断念しなくてはいけないかもしれないし、
または、どうしようもないと諦めて、それほど心地よくない *危険な* 言語で実装することを決心するかもしれません。

<!--
Worse, when you want to talk directly to the operating system, you *have* to
talk to an unsafe language: *C*. C is ever-present and unavoidable. It's the
lingua-franca of the programming world.
Even other safe languages generally expose C interfaces for the world at large!
Regardless of why you're doing it, as soon as your program starts talking to
C it stops being safe.
-->

もっと悪いことに、オペレーティングシステムと直接話したい時には、*C 言語* という危険な言語で
会話を *しなくてはなりません*。C 言語はつねに存在し、逃れることはできないのです。
C 言語はプログラミングの世界での橋渡し言語だからです。
他の安全な言語も、たいてい C 言語のインターフェースを世界中に野放しでさらしています。
理由の如何にかかわらず、あなたのプログラムが C 言語と会話した瞬間に、安全ではなくなるのです。

<!--
With that said, Rust is *totally* a safe programming language.
-->

とはいえ、Rust は *完全に* 安全なプログラミング言語です。

<!--
Well, Rust *has* a safe programming language. Let's step back a bit.
-->

・・・いえ、Rust は安全なプログラミング言語を*もっている*と言えます。一歩下がって考えてみましょう。

<!--
Rust can be thought of as being composed of two programming languages: *Safe
Rust* and *Unsafe Rust*. Safe Rust is For Reals  Totally Safe. Unsafe Rust,
unsurprisingly, is *not* For Reals Totally Safe.  In fact, Unsafe Rust lets you
do some really, *really* unsafe things.
-->

Rust は 2 つのプログラミング言語から成り立っていると言えます。*安全な Rust* と *危険な Rust* です。
安全な Rust は、本当に全く安全ですが、危険な Rust は、当然ですが、本当に全く安全では*ありません*。
実際、危険な Rust では本当に*本当に*危険な事ができるのです。


<!--
Safe Rust is the *true* Rust programming language. If all you do is write Safe
Rust, you will never have to worry about type-safety or memory-safety. You will
never endure a null or dangling pointer, or any of that Undefined Behavior
nonsense.
-->

安全な Rust は真の Rust プログラミング言語です。もしあなたが安全な Rust だけでコードを書くなら、
型安全やメモリ安全性などを心配する必要はないでしょう。
ヌルポインタやダングリングポインタ、馬鹿げた「未定義な挙動」などに我慢する必要はないのです。


<!--
*That's totally awesome.*
-->

*なんて素晴らしいんだ。*

<!--
The standard library also gives you enough utilities out-of-the-box that you'll
be able to write awesome high-performance applications and libraries in pure
idiomatic Safe Rust.
-->

また、標準ライブラリにはすぐに使える十分なユーティリティが揃っています。
それを使えば、ハイパフォーマンスでかっこいいアプリケーションやライブラリを、
正当で慣用的な安全な Rust で書けるでしょう。


<!--
But maybe you want to talk to another language. Maybe you're writing a
low-level abstraction not exposed by the standard library. Maybe you're
*writing* the standard library (which is written entirely in Rust). Maybe you
need to do something the type-system doesn't understand and just *frob some dang
bits*. Maybe you need Unsafe Rust.
-->

でも、もしかしたらあなたは他の言語と話したいかもしれません。もしかしたら標準ライブラリが提供していない
低レイヤを抽象化しようとしているのかもしれないし、もしかしたら標準ライブラリを*書いている*
（標準ライブラリは Rust で書かれています）のかもしれないし、もしかしたらあなたがやりたい事は、
型システムが理解できない、*ぎょっとするようなこと*かもしれません。
もしかしたらあなたには*危険な Rust* が必要かもしれません。


<!--
Unsafe Rust is exactly like Safe Rust with all the same rules and semantics.
However Unsafe Rust lets you do some *extra* things that are Definitely Not Safe.
-->

危険な Rust のルールとセマンティクスは、安全な Rust と同じです。
ただし、危険な Rust ではちょっと*多くの*事ができ、それは間違いなく安全ではありません。

<!--
The only things that are different in Unsafe Rust are that you can:
-->

危険な Rust であなたができる事は、たったこれだけです。

<!--
* Dereference raw pointers
* Call `unsafe` functions (including C functions, intrinsics, and the raw allocator)
* Implement `unsafe` traits
* Mutate statics
-->

* 生ポインタが指す値を得る
* `unsafe` な関数を呼ぶ（C 言語で書かれた関数や、intrinsic、生のアロケータなど）
* `unsafe` なトレイトを実装する
* 静的な構造体を変更する

<!--
That's it. The reason these operations are relegated to Unsafe is that misusing
any of these things will cause the ever dreaded Undefined Behavior. Invoking
Undefined Behavior gives the compiler full rights to do arbitrarily bad things
to your program. You definitely *should not* invoke Undefined Behavior.
-->

これだけです。これらの操作がなぜ「危険」と分類されているかというと、
間違って使うととても恐ろしい「未定義な挙動」を引き起こすからです。
「未定義な挙動」が起きると、コンパイラは、あなたのプログラムにとってどんな悪いことでもできるようになります。
何があっても「未定義な挙動」を起こす*べきではない*です。

<!--
Unlike C, Undefined Behavior is pretty limited in scope in Rust. All the core
language cares about is preventing the following things:
-->

C 言語と違って、Rust では「未定義な挙動」は限定されています。
言語コアは次のような事が起きるのを防ぎます。

<!--
* Dereferencing null or dangling pointers
* Reading [uninitialized memory]
* Breaking the [pointer aliasing rules]
* Producing invalid primitive values:
    * dangling/null references
    * a `bool` that isn't 0 or 1
    * an undefined `enum` discriminant
    * a `char` outside the ranges [0x0, 0xD7FF] and [0xE000, 0x10FFFF]
    * A non-utf8 `str`
* Unwinding into another language
* Causing a [data race][race]
-->

* ヌルポインタやダングリングポインタの参照外し
* [未初期化のメモリ][uninitialized memory] を読む
* [ポインタエイリアスルール][pointer aliasing rules] を破る
* 不正なプリミティブな値を生成する
    * ダングリング参照、ヌル参照
    * 0 でも 1 でもない `bool` 値
    * 未定義な `enum` 判別式
    * [0x0, 0xD7FF] と [0xE000, 0x10FFFF] 範囲外の `char` 値
    * utf8 ではない `str` 値
* 他の言語に巻き戻す
* [データ競合][race] を引き起こす

<!--
That's it. That's all the causes of Undefined Behavior baked into Rust. Of
course, unsafe functions and traits are free to declare arbitrary other
constraints that a program must maintain to avoid Undefined Behavior. However,
generally violations of these constraints will just transitively lead to one of
the above problems. Some additional constraints may also derive from compiler
intrinsics that make special assumptions about how code can be optimized.
-->

これだけです。これが、Rust が防ぐ「未定義な挙動」の原因です。
もちろん、危険な関数やトレイトが「未定義な挙動」を起こさないための他の制約を作り出す事は可能ですが、
そういった制約が破られた場合、たいてい上の問題のどれかを引き起こします。
コンパイラ intrinsic がその他の制約を生み出し、コードの最適化に関する特別な仮定をすることもあります。


<!--
Rust is otherwise quite permissive with respect to other dubious operations.
Rust considers it "safe" to:
-->

Rust はその他の疑わしい操作については、とても寛容です。
Rust は次の操作を「安全」だと判断します。

<!--
* Deadlock
* Have a [race condition][race]
* Leak memory
* Fail to call destructors
* Overflow integers
* Abort the program
* Delete the production database
-->

* デッドロック
* [競合状態][race]
* メモリリーク
* デストラクタを呼ぶことに失敗する
* 整数のオーバーフロー
* プログラムの異常終了
* 本番環境のデータベースを削除してしまう事


<!--
However any program that actually manages to do such a thing is *probably*
incorrect. Rust provides lots of tools to make these things rare, but
these problems are considered impractical to categorically prevent.
-->

とはいえ、こういうことをできてしまうプログラムは*恐らく*間違っていると言えるでしょう。
Rust はこういった事をおきにくくするためのツールをたくさん提供します。
しかし、これらの問題を完全に防ぐのは現実的ではないと考えられています。


[pointer aliasing rules]: references.html
[uninitialized memory]: uninitialized.html
[race]: races.html
