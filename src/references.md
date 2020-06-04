<!--
# References
-->

# 参照

<!--
This section gives a high-level view of the memory model that *all* Rust
programs must satisfy to be correct. Safe code is statically verified
to obey this model by the borrow checker. Unsafe code may go above
and beyond the borrow checker while still satisfying this model. The borrow
checker may also be extended to allow more programs to compile, as long as
this more fundamental model is satisfied.
-->

このセクションでは、*すべての* Rust プログラムが満たさなくてはならないメモリモデルを
ざっくりと見ていきます。
安全なコードは、借用チェッカによってこのモデルを満たしていることが静的に検証されます。
アンセーフなコードは、借用チェッカの裏をかくかもしれませんが、このモデルを満たします。
この基本的なモデルを満たしている限り、より多くのプログラムがコンパイルに通るように
借用チェッカを拡張することも可能です。

<!--
There are two kinds of reference:
-->

参照には 2 種類あります。

<!--
* Shared reference: `&`
* Mutable reference: `&mut`
-->

* 共有参照: `&`
* 可変参照: `&mut`

<!--
Which obey the following rules:
-->

参照は次のルールに従います。

<!--
* A reference cannot outlive its referent
* A mutable reference cannot be aliased
-->

* 参照のライフタイムが、参照先のライフタイムより長くなることはできません。
* 可変参照は、別名を持つことができません。

<!--
That's it. That's the whole model. Of course, we should probably define
what *aliased* means. To define aliasing, we must define the notion of
*paths* and *liveness*.
-->

これだけです。これがモデルの全てです。
もちろん、*別名を持つ*とはどういうことかを定義するべきでしょう。
別名を定義するには、*パス*と*生存*という概念を定義しなくてはなりません。

<!--
**NOTE: The model that follows is generally agreed to be dubious and have
issues. It's ok-ish as an intuitive model, but fails to capture the desired
semantics. We leave this here to be able to use notions introduced here in later
sections. This will be significantly changed in the future. TODO: do that.**
-->

**これから説明するモデルは疑わしく、問題があるという点に、多くの人が同意しています。
直感的なモデルとして使うにはたぶん大丈夫ですが、望むような意味論を捉えることはできないでしょう。
ここではその点にこだわらず、のちの節で使うための概念を紹介することにします。
将来的にはこの構成は大きく変わるでしょう。TODO: 構成を変える。**


<!--
# Paths
-->

# パス

<!--
If all Rust had were values (no pointers), then every value would be uniquely
owned by a variable or composite structure. From this we naturally derive a
*tree* of ownership. The stack itself is the root of the tree, with every
variable as its direct children. Each variable's direct children would be their
fields (if any), and so on.
-->

もし、Rust が扱うのが値だけ（ポインタはない）であれば、
すべての値はただ一つの変数か複合型に所有されることになります。
ここから所有権の*木構造*が自然に導かれます。
スタック自身が木のルートになり、変数が直接の子になります。
変数がフィールドを持つのであれば、それは変数の直接の子になるでしょう。

<!--
From this view, every value in Rust has a unique *path* in the tree of
ownership. Of particular interest are *ancestors* and *descendants*: if `x` owns
`y`, then `x` is an ancestor of `y`, and `y` is a descendant of `x`. Note
that this is an inclusive relationship: `x` is a descendant and ancestor of
itself.
-->

このように見ると、Rust におけるすべての値は、所有権を表す木構造の*パス*を持つことになります。
特に重要なのは、*先祖*と*子孫*です。`x` が `y` が所有しているとき、`x` は `y` の先祖で、
`y` は `x` の子孫です。この関係は内包的であることに注意してください。
`x` はそれ自身の先祖であり子孫です。

<!--
We can then define references as simply *names* for paths. When you create a
reference, you're declaring that an ownership path exists to this address
of memory.
-->

参照は、単純にパスの*名前*と定義できます。
参照を作成するということは、あるメモリアドレスに所有権の
パスが存在することを宣言するということです。

<!--
Tragically, plenty of data doesn't reside on the stack, and we must also
accommodate this. Globals and thread-locals are simple enough to model as
residing at the bottom of the stack (though we must be careful with mutable
globals). Data on the heap poses a different problem.
-->

悲惨なことに、スタックに存在しないデータはたくさんあり、この点も考慮しなくてはいけません。
グローバル変数やスレッドローカル変数は、単純にスタックの底に存在すると考えることができます。
（ただし、可変なグローバル変数に注意が必要です）。
ヒープにあるデータは別の問題を提起します。

<!--
If all Rust had on the heap was data uniquely owned by a pointer on the stack,
then we could just treat such a pointer as a struct that owns the value on the
heap. Box, Vec, String, and HashMap, are examples of types which uniquely
own data on the heap.
-->

もし、ヒープにある各データが、スタック上のただ一つのポインタに所有されているのだとすると、
そういうポインタを、ヒープ上の値を所有する構造体だと解釈すればよいだけです。
ヒープ上のデータを独占的に所有する型の例としては、Box, Vec, String, HashMap があります。

<!--
Unfortunately, data on the heap is not *always* uniquely owned. Rc for instance
introduces a notion of *shared* ownership. Shared ownership of a value means
there is no unique path to it. A value with no unique path limits what we can do
with it.
-->

残念ながら、ヒープ上のデータは*常に*独占的に所有されているわけではありません。
例えば Rc によって、*共有*所有権という概念がでてきます。
値が共有所有されると、その値への一意なパスが存在しないことになります。
一意なパスが存在しない値によって、いろいろな制約が発生します。

<!--
In general, only shared references can be created to non-unique paths. However
mechanisms which ensure mutual exclusion may establish One True Owner
temporarily, establishing a unique path to that value (and therefore all
its children). If this is done, the value may be mutated. In particular, a
mutable reference can be taken.
-->

一般に、一意ではないパスを参照できるのは、共有参照だけです。
しかし、相互排他を保証するメカニズムがあれば、一時的にその値（とそしてすべての子ども）への唯一のパスを確立し、
「唯一の真の所有者」を確立できるかもしれません。
もしこれが可能なら、その値を変更できるかもしれません。
とくに、可変参照を取ることができるようになります。

<!--
The most common way to establish such a path is through *interior mutability*,
in contrast to the *inherited mutability* that everything in Rust normally uses.
Cell, RefCell, Mutex, and RWLock are all examples of interior mutability types.
These types provide exclusive access through runtime restrictions.
-->

そのようなパスを確立するために、Rust で標準的に使われる*継承可変性*ではなく、
*内部可変性*がよく使われます。
内部可変性を持った型の例としては、Cell, RefCell, Mutex, RWLock があります。
これらの型は、実行時の制約を用いて、排他的アクセスを提供します。

<!--
An interesting case of this effect is Rc itself: if an Rc has refcount 1,
then it is safe to mutate or even move its internals. Note however that the
refcount itself uses interior mutability.
-->

この効果を使った興味深い例が Rc 自身です。もし Rc の参照カウントが 1 なら、
内部状態を変更したり、ムーブしたりしても安全です。
参照カウント自体も内部可変性を使っています。

<!--
In order to correctly communicate to the type system that a variable or field of
a struct can have interior mutability, it must be wrapped in an UnsafeCell. This
does not in itself make it safe to perform interior mutability operations on
that value. You still must yourself ensure that mutual exclusion is upheld.
-->

変数や構造体のフィールドに内部可変性があることを型システムに正しく伝えるには、
UnsafeCell を使います。
UnsafeCell 自身は、その値に対して内部可変の操作を安全にはしません。
正しく相互排他していることを、あなた自身が保証しなくてはなりません。

<!--
# Liveness
-->

# 生存性

<!--
Note: Liveness is not the same thing as a *lifetime*, which will be explained
in detail in the next section of this chapter.
-->

生存性 (liveness) は、この章の次の節でで詳しく説明する *ライフタイム (lifetime)* とは違うことに注意してください。

<!--
Roughly, a reference is *live* at some point in a program if it can be
dereferenced. Shared references are always live unless they are literally
unreachable (for instance, they reside in freed or leaked memory). Mutable
references can be reachable but *not* live through the process of *reborrowing*.
-->

大雑把に言うと、参照を参照外しできるとき、
その参照は、プログラム中のある時点で *生存している* といえます。
共有参照は、文字通り到達不可能な場合（たとえば、解放済みメモリやリークしてるメモリに
存在している場合）を除いて、常に生存しています。
可変参照には、*又貸し*というプロセスがあるので、到達できても生存して*いない*ことがあります。


<!--
A mutable reference can be reborrowed to either a shared or mutable reference to
one of its descendants. A reborrowed reference will only be live again once all
reborrows derived from it expire. For instance, a mutable reference can be
reborrowed to point to a field of its referent:
-->

可変参照は、その子孫を他の共有参照または可変参照に又貸しすることができます。
又貸しした参照は、派生したすべたの又貸しの有効期限が切れると、再び生存することになります。
例えば、可変参照は、その参照先の一つのフィールドを指す参照を又貸しすることができます。

```rust
let x = &mut (1, 2);
{
    // x のフィールドを又借りする
    let y = &mut x.0;
    // この時点で y は生存しているが、x は生存していない
    *y = 3;
}
// y がスコープ外に出たので、x が再び生存中になる
*x = (5, 7);
```

<!--
It is also possible to reborrow into *multiple* mutable references, as long as
they are *disjoint*: no reference is an ancestor of another. Rust
explicitly enables this to be done with disjoint struct fields, because
disjointness can be statically proven:
-->

*複数の*可変参照に又貸しすることも可能ですが、その複数の参照は互いに素でなくてはいけません。
つまり、どの参照も他の参照の先祖であってはいけないということです。
Rust は、構造体のフィールドが互いに素であることを静的に証明できるので、
フィールドの又貸しが可能です。

```rust
let x = &mut (1, 2);
{
    // x を 2 つの互いに素なフィールドに又貸しする
    let y = &mut x.0;
    let z = &mut x.1;

    // y と z は生存しているが、x は生存していない
    *y = 3;
    *z = 4;
}
// y と z がスコープ外に出たので、x がふたたび生存中になる
*x = (5, 7);
```

<!--
However it's often the case that Rust isn't sufficiently smart to prove that
multiple borrows are disjoint. *This does not mean it is fundamentally illegal
to make such a borrow*, just that Rust isn't as smart as you want.
-->

ただし、多くの場合 Rust は十分に賢くないので、複数の借り手が互いに素であることを証明できません。
*これはそのような又貸しが禁じられているという意味ではなく*、
単に Rust が期待するほど賢くないというだけです。

<!--
To simplify things, we can model variables as a fake type of reference: *owned*
references. Owned references have much the same semantics as mutable references:
they can be re-borrowed in a mutable or shared manner, which makes them no
longer live. Live owned references have the unique property that they can be
moved out of (though mutable references *can* be swapped out of). This power is
only given to *live* owned references because moving its referent would of
course invalidate all outstanding references prematurely.
-->

話を単純にするために、変数を参照型の一種、*所有中*参照、と仮定してみましょう。
所有中参照は、可変参照とほとんど同じ意味を持ちます。
可変参照または共有参照に又貸しでき、それによって生存中ではなくなります。
生存中の所有中参照は、値を解放（ムーブアウト）できるという特殊な性質があります
（とはいえ、可変参照は値をスワップアウトできますが）。
この能力は、*生存中の* 所有中参照のみに与えられています。
そうでなければ、早すぎるタイミングでその他の参照を無効にすることになります。

<!--
As a local lint against inappropriate mutation, only variables that are marked
as `mut` can be borrowed mutably.
-->

不適切な値の変更を lint が検出するので、`mut` とマークされた変数だけが変更可能なように貸し出されます。

<!--
It is interesting to note that Box behaves exactly like an owned reference. It
can be moved out of, and Rust understands it sufficiently to reason about its
paths like a normal variable.
-->

Box がまさに所有中参照のように振る舞うというおとを覚えておくと良いでしょう。
Box は値を解放することができ、変数が解放された時と同様に Rust はそのパスについて推論するための
十分な情報を持っています。


<!--
# Aliasing
-->

# 別名付け

<!--
With liveness and paths defined, we can now properly define *aliasing*:
-->

生存性とパスを定義したので、ようやく*別名*を適切に定義できます。

<!--
**A mutable reference is aliased if there exists another live reference to one
of its ancestors or descendants.**
-->

**可変参照は、その先祖か子孫に他の参照が存在している時、別名を持つといいます。**

<!--
(If you prefer, you may also say the two live references alias *each other*.
This has no semantic consequences, but is probably a more useful notion when
verifying the soundness of a construct.)
-->

（二つの生存中の参照が互いの別名になっている、と言うこともできます。
意味上の違いは特にありませんが、プログラムの構造の健全性を検証する時には、
この考え方の方がわかりやすいでしょう。）

<!--
That's it. Super simple right? Except for the fact that it took us two pages to
define all of the terms in that definition. You know: Super. Simple.
-->

これだけです。すげーわかりやすいですよね? この定義に必要なすべての用語を定義するのに 2 ページ必要に
なりましたが・・・。すごく、分かりやすい。でしょ?

<!--
Actually it's a bit more complicated than that. In addition to references, Rust
has *raw pointers*: `*const T` and `*mut T`. Raw pointers have no inherent
ownership or aliasing semantics. As a result, Rust makes absolutely no effort to
track that they are used correctly, and they are wildly unsafe.
-->

実際には、もう少し複雑です。参照に加えて Rust には*生ポインタ*もあります。
`*const T` と `*mut T` のことです。
生ポインタには、継承可能な所有権も別名という概念もありません。
そのため、Rust は生ポインタを追跡する努力を一切しませんし、生ポインタは極めて危険です。

<!--
**It is an open question to what degree raw pointers have alias semantics.
However it is important for these definitions to be sound that the existence of
a raw pointer does not imply some kind of live path.**
-->

**生ポインタが別名という意味をどの程度持っているのか、というのはまだ答えの出てない問題です。
しかし、この節で出てきた定義が健全であるためには、生ポインタを使うとある種の生存パスが
わからなくなるということ重要です。**
