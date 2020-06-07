<!--
# Subtyping and Variance
-->

# 派生型と変性

<!--
Although Rust doesn't have any notion of structural inheritance, it *does*
include subtyping. In Rust, subtyping derives entirely from lifetimes. Since
lifetimes are scopes, we can partially order them based on the *contains*
(outlives) relationship. We can even express this as a generic bound.
-->

Rust には構造継承の概念はありませんが、派生型の概念は*あります*。
Rust では、派生型は完全にライフタイムに由来します。ライフタイムはスコープですので、
包含関係によって部分的にライフタイムを定めることが出来ます。
ジェネリック境界として表現することも可能です。

<!--
Subtyping on lifetimes is in terms of that relationship: if `'a: 'b` ("a contains
b" or "a outlives b"), then `'a` is a subtype of `'b`. This is a large source of
confusion, because it seems intuitively backwards to many: the bigger scope is a
*subtype* of the smaller scope.
-->

ライフタイムにおける派生型を、ライフタイムの関係から見ます。
もし `'a: 'b` （「 a は b を含む」あるいは「 a は b より長生きする」）ならば、
`'a` は `'b` の派生型です。これは混乱の大きな原因です。というのも、
多くの人にとっては、
この関係は直感的に逆のように感じるからです: より大きいスコープは小さい方のスコープの*派生型*となる。

<!--
This does in fact make sense, though. The intuitive reason for this is that if
you expect an `&'a u8`, then it's totally fine for me to hand you an `&'static
u8`, in the same way that if you expect an Animal in Java, it's totally fine for
me to hand you a Cat. Cats are just Animals *and more*, just as `'static` is
just `'a` *and more*.
-->

それでもこれは実際、理にかなっています。
 Java において、 Animal が期待される場合に Cat を渡しても問題ないのと全く同じように、
もし `&'a u8` が期待されるとき、 `&'static u8` を渡しても問題ないということが
これに対する直感的な理由になります。  `'static` が `'a` *以上*のものであるように、
Cat も Animal *以上*のものであるからです。

<!--
(Note, the subtyping relationship and typed-ness of lifetimes is a fairly
arbitrary construct that some disagree with. However it simplifies our analysis
to treat lifetimes and types uniformly.)
-->

（派生型の関係とライフタイムの型付けはかなり無理やりな構成で、これに反対する人もいることに注意してください。
しかしながら、この構成によって分析が単純となり、ライフタイムと型を同じように扱えます。）

<!--
Higher-ranked lifetimes are also subtypes of every concrete lifetime. This is
because taking an arbitrary lifetime is strictly more general than taking a
specific one.
-->

高階ライフタイムもまた、あらゆる具象ライフタイムの派生型です。
これは、任意のライフタイムを受け取ることは、
ある特定のライフタイムを受け取ることよりも厳密により一般的であるからです。

<!--
# Variance
-->

# 変性

<!--
Variance is where things get a bit complicated.
-->

変性はちょっと複雑です。

<!--
Variance is a property that *type constructors* have with respect to their
arguments. A type constructor in Rust is a generic type with unbound arguments.
For instance `Vec` is a type constructor that takes a `T` and returns a
`Vec<T>`. `&` and `&mut` are type constructors that take two inputs: a
lifetime, and a type to point to.
-->

変性は、*型コンストラクタ*がその引数に関して持つ性質です。
 Rust において型コンストラクタは、無制限の引数を持つジェネリックな型です。
例えば、 `Vec` は `T` を受け取り `Vec<T>` を返す型コンストラクタです。
 `&` や `&mut` は 2 つの入力を受け取ります: ライフタイムと、指し示すための型です。

<!--
A type constructor's *variance* is how the subtyping of its inputs affects the
subtyping of its outputs. There are two kinds of variance in Rust:
-->

型コンストラクタの*変性*は、どのように型コンストラクタの入力の派生型が出力の派生型に
影響するかということです。 Rust では 2 種類の変性があります。

<!--
* F is *variant* over `T` if `T` being a subtype of `U` implies
  `F<T>` is a subtype of `F<U>` (subtyping "passes through")
* F is *invariant* over `T` otherwise (no subtyping relation can be derived)
-->

* もし `T` が `U` の派生型であるとき、 `F<T>` が `F<U>` の派生型であるならば、 F は
  `T` において*変性*です。（派生型の「パススルー」）
* それ以外の場合、 F は `T` において*非変性*です。（いかなる派生型の関係も継承されません）

<!--
(For those of you who are familiar with variance from other languages, what we
refer to as "just" variance is in fact *covariance*. Rust has *contravariance*
for functions. The future of contravariance is uncertain and it may be
scrapped. For now, `fn(T)` is contravariant in `T`, which is used in matching
methods in trait implementations to the trait definition. Traits don't have
inferred variance, so `Fn(T)` is invariant in `T`).
-->

（他の言語で変性に慣れている方にとって、この本で「単に」変性と言及しているものは実は*共変性*です。
 Rust では関数に*反変性*が存在します。将来的に反変性がどうなるかは未定で、
反変性が廃止されるかもしれません。今の所、 `fn(T)` は `T` の反変性で、これは
トレイトの定義に対してトレイトの実装内のメソッドをマッチさせるのに使われます。
トレイトは推論された変性を持たないため、 `fn(T)` は `T` において変性ではありません。）

<!--
Some important variances:
-->

いくつか重要な変性があります。

<!--
* `&'a T` is variant over `'a` and `T` (as is `*const T` by metaphor)
* `&'a mut T` is variant over `'a` but invariant over `T`
* `Fn(T) -> U` is invariant over `T`, but variant over `U`
* `Box`, `Vec`, and all other collections are variant over the types of
  their contents
* `UnsafeCell<T>`, `Cell<T>`, `RefCell<T>`, `Mutex<T>` and all other
  interior mutability types are invariant over T (as is `*mut T` by metaphor)
-->

* `&'a T` は `'a` と `T` において変性です（ `*const T` も同じということがわかるでしょう）
* `&'a mut T` は `'a` において変性ですが、 `T` においては非変性です
* `Fn(T) -> U` は `T` において非変性ですが、 `U` においては変性です
* `Box` や `Vec` や他の全てのコレクションは、要素の型において変性です
* `UnsafeCell<T>`、`Cell<T>`、`RefCell<T>`、`Mutex<T>` や他の内部可変性型は `T` において
  非変性です（ `*mut T` も同じということがわかるでしょう）

<!--
To understand why these variances are correct and desirable, we will consider
several examples.
-->

これらの変性がなぜ正しくそして望ましいかを理解するために、いくつかの例を考えましょう。

<!--
We have already covered why `&'a T` should be variant over `'a` when
introducing subtyping: it's desirable to be able to pass longer-lived things
where shorter-lived things are needed.
-->

派生型を導入するときに、なぜ `&'a T` が `'a` において変性であるべきか、既にカバーしました。
これは、短く生きるものが必要なときに、より長く生きるものを渡せるようにするために、
望ましいものなのです。

<!--
Similar reasoning applies to why it should be variant over T. It is reasonable
to be able to pass `&&'static str` where an `&&'a str` is expected. The
additional level of indirection does not change the desire to be able to pass
longer lived things where shorted lived things are expected.
-->

似た理由が、なぜ `&'a T` が T において変性であるべきかについて適用できます。
`&&'a str` が求められている場所で `&&'static str` を渡せるようにすることが
合理的であるからです。間接参照の段階が増えても、短く生きるものが求められている
場合により長く生きるものを渡せるようにするという要望は変わりません。

<!--
However this logic doesn't apply to `&mut`. To see why `&mut` should
be invariant over T, consider the following code:
-->

しかしながら、この論理は `&mut` には適用できません。
なぜ `&mut` が T において非変性であるべきかを確認するために、
次のコードを考えてみましょう。

```rust,ignore
fn overwrite<T: Copy>(input: &mut T, new: &mut T) {
    *input = *new;
}

fn main() {
    let mut forever_str: &'static str = "hello";
    {
        let string = String::from("world");
        overwrite(&mut forever_str, &mut &*string);
    }
    // しまった、解放されたメモリを出力しようとしている
    println!("{}", forever_str);
}
```

<!--
The signature of `overwrite` is clearly valid: it takes mutable references to
two values of the same type, and overwrites one with the other. If `&mut T` was
variant over T, then `&mut &'static str` would be a subtype of `&mut &'a str`,
since `&'static str` is a subtype of `&'a str`. Therefore the lifetime of
`forever_str` would successfully be "shrunk" down to the shorter lifetime of
`string`, and `overwrite` would be called successfully. `string` would
subsequently be dropped, and `forever_str` would point to freed memory when we
print it! Therefore `&mut` should be invariant.
-->

`overwrite` のシグネチャは明らかに文法的に正しいです。これは、同じ型の 2 つの値の
可変参照を受け取り、片方の値をもう一つの値で上書きします。
もし `&mut T` が T において変性だったなら、 `&mut &'static str` は `&mut &'a str` の
派生型だったでしょう。 `&'static str` が `&'a str` の派生型であるからです。
それ故に、 `forever_str` のライフタイムは、見事により短い `string` のライフタイムに
「縮まる」でしょう。そして、 `overwrite` の呼び出しは成功するでしょう。後に `string` は
ドロップされ、 `forever_str` は出力の際に解放されたメモリを指していたでしょう!
それ故に `&mut` は非変性である必要があるのです。

<!--
This is the general theme of variance vs invariance: if variance would allow you
to store a short-lived value into a longer-lived slot, then you must be
invariant.
-->

変性か非変性かの一般的な主題はこちらです: もし変性によって、短く生きる値がより長く生きる
スロットに保存されるようなことが起きてしまうならば、非変性でなければなりません。

<!--
However it *is* sound for `&'a mut T` to be variant over `'a`. The key difference
between `'a` and T is that `'a` is a property of the reference itself,
while T is something the reference is borrowing. If you change T's type, then
the source still remembers the original type. However if you change the
lifetime's type, no one but the reference knows this information, so it's fine.
Put another way: `&'a mut T` owns `'a`, but only *borrows* T.
-->

しかし、 `&'a mut T` は `'a` において変性のように*見えます*。 `&'a` と T の
重要な違いは、 `'a` は参照それ自体の性質ですが、 T は参照が借用しているものである、ということです。
もし T の型を変えても、借用元は元の型を記憶しています。
しかし、もしライフタイムの型を変えると、参照以外のものはこの情報を記憶していないので、
問題ないのです。
言い換えると、 `&'a mut T` は `'a` を所有しますが、 T は単に*借用している*だけなのです。

<!--
`Box` and `Vec` are interesting cases because they're variant, but you can
definitely store values in them! This is where Rust gets really clever: it's
fine for them to be variant because you can only store values
in them *via a mutable reference*! The mutable reference makes the whole type
invariant, and therefore prevents you from smuggling a short-lived type into
them.
-->

`Box` と `Vec` は興味深いケースです。なぜなら、これらは変性であるのに、
この中に値を保存できるからです! これは Rust が本当に賢いところです: これらにとって、
変性であることは問題ないのです。なぜなら値を*可変参照を通して*だけ
値を保存できるからです! 可変参照はすべての型を非変性にします。そしてそれ故に
短く生きる型をこっそり入れることを防ぐのです。

<!--
Being variant allows `Box` and `Vec` to be weakened when shared
immutably. So you can pass a `&Box<&'static str>` where a `&Box<&'a str>` is
expected.
-->

変性であることで、イミュータブルで共有されるときに `Box` や `Vec` を弱くすることができます。
よって `&Box<&'a str>` が期待される場合に `&Box<&'static str>` を渡すことができるのです。

<!--
However what should happen when passing *by-value* is less obvious. It turns out
that, yes, you can use subtyping when passing by-value. That is, this works:
-->

しかし、*値*渡しが起きるとき、何が起きるかはあまり明らかではありません。
ええ、値渡しされるときに派生型を使用することは可能だとわかります。
つまり、このコードは動作します。

```rust
fn get_box<'a>(str: &'a str) -> Box<&'a str> {
    // 文字列リテラルは `&'static str` です
    Box::new("hello")
}
```

<!--
Weakening when you pass by-value is fine because there's no one else who
"remembers" the old lifetime in the Box. The reason a variant `&mut` was
trouble was because there's always someone else who remembers the original
subtype: the actual owner.
-->

Box の古いライフタイムを「記憶」するものが他に存在しないので、値渡しの際に
弱くするのは問題ありません。変性の `&mut` が問題である理由は、元々の派生型を
記憶している他のものが存在するからです: 実際の所有者です。

<!--
The invariance of the cell types can be seen as follows: `&` is like an `&mut`
for a cell, because you can still store values in them through an `&`. Therefore
cells must be invariant to avoid lifetime smuggling.
-->

cell 型の非変性は次のように見ることが出来ます。すなわち、 `&` は cell における `&mut` のようになります。
なぜなら、 `&` を通して値を保存することも可能だからです。
したがって、ライフタイムをこっそり導入することがないよう、 cell は非変性でなければなりません。

<!--
`Fn` is the most subtle case because it has mixed variance. To see why
`Fn(T) -> U` should be invariant over T, consider the following function
signature:
-->

`Fn` はまぜこぜの変性を持っているので、最も見分けのつかないケースです。
なぜ `Fn(T) -> U` が T において非変性であるべきかを確認するために、
次の関数シグネチャを考えてみましょう。

```rust,ignore
// 'a はある親スコープから継承されます
fn foo(&'a str) -> usize;
```

<!--
This signature claims that it can handle any `&str` that lives at least as
long as `'a`. Now if this signature was variant over `&'a str`, that
would mean
-->

このシグネチャは、少なくとも `'a` は生きる、いかなる `&str` も扱うことができると
主張します。この時、もしシグネチャが `&'a str` において変性であるならば、これは
次のシグネチャ

```rust,ignore
fn foo(&'static str) -> usize;
```

<!--
could be provided in its place, as it would be a subtype. However this function
has a stronger requirement: it says that it can only handle `&'static str`s,
and nothing else. Giving `&'a str`s to it would be unsound, as it's free to
assume that what it's given lives forever. Therefore functions are not variant
over their arguments.
-->

が同じ場所に現れうるということを意味するでしょう。 `&'static str` が派生型だからです。
しかし、この関数にはより強い要件があります。 `&'static str` のみを扱い、他のものは
扱わないということです。 `&'a str` などを渡すと健全ではなくなるでしょう。
なぜなら、この関数シグネチャは自由に、渡されたものが永遠に生きると見なすことが
できるからです。
それゆえに、関数はその引数において、変性ではないのです。

<!--
To see why `Fn(T) -> U` should be variant over U, consider the following
function signature:
-->

なぜ `Fn(T) -> U` が U において変性であるべきかを確認するために、次の関数シグネチャを
考えてみましょう。

```rust,ignore
// 'a はある親スコープから継承されます
fn foo(usize) -> &'a str;
```

<!--
This signature claims that it will return something that outlives `'a`. It is
therefore completely reasonable to provide
-->

このシグネチャは、関数が `'a` より長生きする何かを返すと主張しています。
それゆえに、この場所に

```rust,ignore
fn foo(usize) -> &'static str;
```

<!--
in its place. Therefore functions are variant over their return type.
-->

が置かれても全く問題ありません。ゆえに、関数は、そのリターン型において変性なのです。

<!--
`*const` has the exact same semantics as `&`, so variance follows. `*mut` on the
other hand can dereference to an `&mut` whether shared or not, so it is marked
as invariant just like cells.
-->

`*const` は `&` と全く同じセマンティクスを持ちます。つまり変性も `&` に従います。
他方で、 `*mut` は、共有の有無に関わらず `&mut` に参照外し可能です。よって
`*mut` は cell と同じように非変性です。

<!--
This is all well and good for the types the standard library provides, but
how is variance determined for type that *you* define? A struct, informally
speaking, inherits the variance of its fields. If a struct `Foo`
has a generic argument `A` that is used in a field `a`, then Foo's variance
over `A` is exactly `a`'s variance. However this is complicated if `A` is used
in multiple fields.
-->

これは標準ライブラリが提供する型にとっては上手くいくのですが、
*あなたが*定義した型の変性はどのように決定されるのでしょうか? 簡単に言えば、
構造体はフィールドの変性を受け継ぎます。もし構造体 `Foo` が、フィールド `a` に使われる
ジェネリックな引数 `A` を持つならば、 Foo の `A` における変性は `a` の変性と全く同じです。
しかしながら、もし `A` が複数のフィールドで使用されている場合、これは複雑になります。

<!--
* If all uses of A are variant, then Foo is variant over A
* Otherwise, Foo is invariant over A
-->

* もし A を使用しているすべてのものが変性である場合、 Foo は A において変性です
* そうでなければ、 Foo は A において非変性です

```rust
use std::cell::Cell;

struct Foo<'a, 'b, A: 'a, B: 'b, C, D, E, F, G, H> {
    a: &'a A,     // 'a と A において変性
    b: &'b mut B, // 'b において変性、 B において非変性
    c: *const C,  // C において変性
    d: *mut D,    // D において非変性
    e: Vec<E>,    // E において変性
    f: Cell<F>,   // F において非変性
    g: G,         // G において変性
    h1: H,        // これも H において変性に見えるでしょうが...
    h2: Cell<H>,  // H において非変性です。非変性が勝つのです
}
```
