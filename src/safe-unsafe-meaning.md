<!-- # How Safe and Unsafe Interact -->

# 安全と危険の相互作用


<!-- What's the relationship between Safe Rust and Unsafe Rust? How do they
interact? -->
安全な Rust と危険な Rust とはどう関係しているのでしょうか? どのように影響し合うのでしょうか?

<!-- The separation between Safe Rust and Unsafe Rust is controlled with the
`unsafe` keyword, which acts as an interface from one to the other. This is
why we can say Safe Rust is a safe language: all the unsafe parts are kept
exclusively behind the boundary. -->

`unsafe` キーワードがインターフェースとなり、安全な Rust と危険な Rust とを分離します。
このため、安全な Rust は安全な言語で、危険な部分は完全に境界外に管理されている、と言うことができるのです。

<!--
The `unsafe` keyword has two uses: to declare the existence of contracts the
compiler can't check, and to declare that the adherence of some code to
those contracts has been checked by the programmer.
-->

`unsafe` は 2 つの目的に使われます。コンパイラがチェックできない契約が存在する事を宣言することと、
コードが契約に準拠していることがプログラマによってチェックされた事を宣言する事です。

<!--
You can use `unsafe` to indicate the existence of unchecked contracts on
_functions_ and on _trait declarations_. On functions, `unsafe` means that
users of the function must check that function's documentation to ensure
they are using it in a way that maintains the contracts the function
requires. On trait declarations, `unsafe` means that implementors of the
trait must check the trait documentation to ensure their implementation
maintains the contracts the trait requires.
-->

_関数_ と _トレイトの宣言_ に未チェックな契約が存在する事を、`unsafe` を使って示すことができます。
関数に `unsafe` を使うと、ドキュメントを読んで、
要求された契約を守るように関数を使うことを、その関数のユーザーに要請することになります。
トレイトの宣言に `unsafe` を使うと、そのトレイトを実装するユーザーに対し、ドキュメントをチェックして契約を守るよう要請します。

<!--
You can use `unsafe` on a block to declare that all constraints required
by an unsafe function within the block have been adhered to, and the code
can therefore be trusted. You can use `unsafe` on a trait implementation
to declare that the implementation of that trait has adhered to whatever
contracts the trait's documentation requires.
-->

コードブロックに使われた `unsafe` は、そのブロックで呼ばれている危険な関数が要求する契約は守られていて、コードが信頼出来る事を意味します。`unsafe` をトレイトの実装に使うと、その実装がトレイトのドキュメントに書かれている契約に準拠している事を示します。

<!--
The standard library has a number of unsafe functions, including:
-->

標準ライブラリにはいくつもの危険な関数があります。例えば、

<!--
* `slice::get_unchecked`, which performs unchecked indexing, allowing
  memory safety to be freely violated.
* `mem::transmute` reinterprets some value as having a given type, bypassing
  type safety in arbitrary ways (see [conversions] for details).
* Every raw pointer to a sized type has an intrinstic `offset` method that
  invokes Undefined Behavior if the passed offset is not "in bounds" as
  defined by LLVM.
* All FFI functions are `unsafe` because the other language can do arbitrary
  operations that the Rust compiler can't check.
-->

* `slice::get_unchecked` は未チェックのインデックス参照を実行します。自由自在にメモリ安全性に違反できます。
* `mem::transmute` は、型安全の仕組みを好きなようにすり抜けて、ある値が特定の型であると再解釈します（詳細は [変換] をみてください）。
* サイズが確定している型の生ポインタには、固有の `offset` メソッドがあります。渡されたオフセットが LLVM が定める "境界内" になければ、未定義の挙動を引き起こします。
* すべての FFI 関数は `unsafe` です。なぜなら Rust コンパイラは、他の言語が実行するどんな操作もチェックできないからです。

<!--
As of Rust 1.0 there are exactly two unsafe traits:
-->

Rust 1.0 現在、危険な traits は 2 つしかありません。

<!--
* `Send` is a marker trait (a trait with no API) that promises implementors are
  safe to send (move) to another thread.
* `Sync` is a marker trait that promises threads can safely share implementors
  through a shared reference.
  -->

* `Send` は API を持たないマーカートレイトで、実装された型が他のスレッドに安全に送れる（ムーブできる）ことを約束します。
* `Sync` もマーカートレイトで、このトレイトを実装した型は、共有された参照を使って安全に複数のスレッドで共有できる事を約束します。

<!--
Much of the Rust standard library also uses Unsafe Rust internally, although
these implementations are rigorously manually checked, and the Safe Rust
interfaces provided on top of these implementations can be assumed to be safe.
-->

また、多くの Rust 標準ライブラリは内部で危険な Rust を使っています。ただ、標準ライブラリの
実装はプログラマが徹底的にチェックしているので、危険な Rust の上に実装された安全な Rust は安全であると仮定して良いでしょう。

<!--
The need for all of this separation boils down a single fundamental property
of Safe Rust:

**No matter what, Safe Rust can't cause Undefined Behavior.**
-->

このように分離する目的は、結局のところ、安全な Rust のたった一つの基本的な性質にあります。

**どうやっても、安全な Rust では未定義な挙動を起こせない。**

<!--
The design of the safe/unsafe split means that Safe Rust inherently has to
trust that any Unsafe Rust it touches has been written correctly (meaning
the Unsafe Rust actually maintains whatever contracts it is supposed to
maintain). On the other hand, Unsafe Rust has to be very careful about
trusting Safe Rust.
-->

このように安全と危険を分けると、安全な Rust は、自分が利用する危険な Rust が正しく書かれている事、
つまり危険な Rust がそれが守るべき契約を実際に守っている事、を本質的に信頼しなくてはいけません。
逆に、危険な Rust は安全な Rust を注意して信頼しなくてはいけません。

<!--
As an example, Rust has the `PartialOrd` and `Ord` traits to differentiate
between types which can "just" be compared, and those that provide a total
ordering (where every value of the type is either equal to, greater than,
or less than any other value of the same type). The sorted map type
`BTreeMap` doesn't make sense for partially-ordered types, and so it
requires that any key type for it implements the `Ord` trait. However,
`BTreeMap` has Unsafe Rust code inside of its implementation, and this
Unsafe Rust code cannot assume that any `Ord` implementation it gets makes
sense. The unsafe portions of `BTreeMap`'s internals have to be careful to
maintain all necessary contracts, even if a key type's `Ord` implementation
does not implement a total ordering.
-->

例えば、Rust には `PartialOrd` trait と `Ord` trait があり、単に比較可能な型と全順序が
定義されている型（任意の値が同じ型の他の値と比べて等しいか、大きいか、小さい）とを区別します。
順序つきマップの `BTreeMap` は半順序の型には使えないので、キーとして使われる型が `Ord` trait を
実装している事を要求します。
しかし `BTreeMap` の実装は危険な Rust が使っていて、危険な Rust は渡された `Ord` の実装が
適切であるとは仮定できません。
`BTreeMap` 内部の危険な部分は、キー型の `Ord` の実装が全順序ではない場合でも、必要な契約が
すべて守られるよう注意深く書かれなくてはいけません。

<!--
Unsafe Rust cannot automatically trust Safe Rust. When writing Unsafe Rust,
you must be careful to only rely on specific Safe Rust code, and not make
assumptions about potential future Safe Rust code providing the same
guarantees.
-->

危険な Rust は安全な Rust を無意識には信頼できません。危険な Rust コードを書くときには、
安全な Rust の特定のコードのみに依存する必要があり、
安全な Rust が将来にわたって同様の安全性を提供すると仮定してはいけません。

<!--
This is the problem that `unsafe` traits exist to resolve. The `BTreeMap`
type could theoretically require that keys implement a new trait called
`UnsafeOrd`, rather than `Ord`, that might look like this:
-->

この問題を解決するために `unsafe` な trait が存在します。理論上は、`BTreeMap` 型は
キーが `Ord` ではなく、新しい trait `UnsafeOrd` を実装する事を要求する事ができます。
このようなコードになるでしょう。

```rust
use std::cmp::Ordering;

unsafe trait UnsafeOrd {
    fn cmp(&self, other: &Self) -> Ordering;
}
```

<!--
Then, a type would use `unsafe` to implement `UnsafeOrd`, indicating that
they've ensured their implementation maintains whatever contracts the
trait expects. In this situation, the Unsafe Rust in the internals of
`BTreeMap` could trust that the key type's `UnsafeOrd` implementation is
correct. If it isn't, it's the fault of the unsafe trait implementation
code, which is consistent with Rust's safety guarantees.
-->

この場合、`UnsafeOrd` を実装する型は、この trait が期待する契約に準拠している事を示すために
`unsafe` キーワードを使うことになります。
この状況では、`BTreeMap` 内部の危険な Rust は、キー型が `UnsafeOrd` を正しく実装していると
信用する事ができます。もしそうで無ければ、それは trait の実装の問題であり、
これは Rust の安全性の保証と一致しています。

<!--
The decision of whether to mark a trait `unsafe` is an API design choice.
Rust has traditionally avoided marking traits unsafe because it makes Unsafe
Rust pervasive, which is not desirable. `Send` and `Sync` are marked unsafe
because thread safety is a *fundamental property* that unsafe code can't
possibly hope to defend against in the way it could defend against a bad
`Ord` implementation. The decision of whether to mark your own traits `unsafe`
depends on the same sort of consideration. If `unsafe` code cannot reasonably
expect to defend against a bad implementation of the trait, then marking the
trait `unsafe` is a reasonable choice.
-->

trait に `unsafe` をつけるかどうかは API デザインにおける選択です。
Rust では従来 `unsafe` な trait を避けてきました。そうしないと危険な Rust が
蔓延してしまい、好ましくないからです。
`Send` と `Sync` が `unsafe` となっているのは、スレッドの安全性が *基本的な性質* であり、
間違った `Ord` の実装に対して危険なコードが防衛できるのと同様の意味では防衛できないからです。
あなたが宣言した trait を `unsafe` とマークするかどうかも、同じようにじっくりと考えてください。
もし `unsafe` なコードがその trait の間違った実装から防御することが合理的に不可能であるなら、
その trait を `unsafe` とするのは合理的な選択です。

<!--
As an aside, while `Send` and `Sync` are `unsafe` traits, they are
automatically implemented for types when such derivations are provably safe
to do. `Send` is automatically derived for all types composed only of values
whose types also implement `Send`. `Sync` is automatically derived for all
types composed only of values whose types also implement `Sync`.
-->

余談ですが、`unsafe` な trait である `Send` と `Sync` は、それらを実装する事が安全だと
実証可能な場合には自動的に実装されます。
`Send` は、`Send` を実装した型だけから構成される型に対して、自動的に実装されます。
`Sync` は、`Sync` を実装した型だけから構成される型に対して、自動的に実装されます。

<!--
This is the dance of Safe Rust and Unsafe Rust. It is designed to make using
Safe Rust as ergonomic as possible, but requires extra effort and care when
writing Unsafe Rust. The rest of the book is largely a discussion of the sort
of care that must be taken, and what contracts it is expected of Unsafe Rust
to uphold.
-->

これが安全な Rust と危険な Rust のダンスです。
これは、安全な Rust をできるだけ快適に使えるように、しかし危険な Rust を書くには
それ以上の努力と注意深さが要求されるようなデザインになっています。
この本の残りでは、どういう点に注意しなくはいけないのか、
危険な Rust を維持するための契約とは何なのかを議論します。



[drop flags]: drop-flags.html
[変換]: conversions.html

