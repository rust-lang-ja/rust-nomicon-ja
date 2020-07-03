<!--
# Send and Sync
-->

# Send と Sync

<!--
Not everything obeys inherited mutability, though. Some types allow you to
multiply alias a location in memory while mutating it. Unless these types use
synchronization to manage this access, they are absolutely not thread safe. Rust
captures this through the `Send` and `Sync` traits.
-->

すべてのものが継承可変性に従っているわけではありません。が、いくつかの型においては、
メモリ上の場所の値を変更している間に、複数のエイリアスを生成することが可能です。
これらの型が、このアクセスを管理するために同期を行なわない限り、これらは絶対スレッドセーフでは
ありません。 Rust ではこれを、 `Send` トレイトと `Sync` トレイトでキャプチャしています。

<!--
* A type is Send if it is safe to send it to another thread.
* A type is Sync if it is safe to share between threads (`&T` is Send).
-->

* ある型を他のスレッドに安全に送信できる場合、その型は Send を実装します。
* ある型をスレッド間で安全に共有できる場合、その型は Sync を実装します (`&T` は Send を実装します) 。

<!--
Send and Sync are fundamental to Rust's concurrency story. As such, a
substantial amount of special tooling exists to make them work right. First and
foremost, they're [unsafe traits]. This means that they are unsafe to
implement, and other unsafe code can assume that they are correctly
implemented. Since they're *marker traits* (they have no associated items like
methods), correctly implemented simply means that they have the intrinsic
properties an implementor should have. Incorrectly implementing Send or Sync can
cause Undefined Behavior.
-->

Send と Sync は Rust の並行性の基本です。したがって、これらが正しく動作するように、
かなりの量の、特別なツールが存在します。まず真っ先に、これらは[アンセーフなトレイト][unsafe traits]です。
これはつまり、これらを実装する事はアンセーフで、他のアンセーフなコードが、これらのトレイトが正しく
実装されていると見なすことができます。これらのトレイトは*マーカートレイト*
(これらのトレイトは、メソッドなどの関連情報を備えていません) ですので、正しく実装することは、
これらのトレイトが、型を実装するものが持っているべき intrinsic な特性を持っているということを
単に意味します。 Send や Sync が正しく実装されていないと、未定義動作を引き起こすことがあります。

<!--
Send and Sync are also automatically derived traits. This means that, unlike
every other trait, if a type is composed entirely of Send or Sync types, then it
is Send or Sync. Almost all primitives are Send and Sync, and as a consequence
pretty much all types you'll ever interact with are Send and Sync.
-->

Send や Sync はまた、自動的に継承されるトレイトでもあります。これはつまり、他のすべてのトレイトとは
違い、もしある型が Send や Sync を実装している型だけで構成されている場合、その型は Send や
Sync を実装しています。ほとんどすべてのプリミティブ型は Send や Sync を実装しています。
そして結果的に、あなたが扱うかなり多くの型は、 Send や Sync を実装しています。

<!--
Major exceptions include:
-->

これの主な例外には、このようなものがあります。

<!--
* raw pointers are neither Send nor Sync (because they have no safety guards).
* `UnsafeCell` isn't Sync (and therefore `Cell` and `RefCell` aren't).
* `Rc` isn't Send or Sync (because the refcount is shared and unsynchronized).
-->

* 生ポインタは Send も Sync も実装していません (なぜなら生ポインタには安全性に関するガードが存在しないからです) 。
* `UnsafeCell` は Sync を実装していません (そしてそれ故に `Cell` も `RefCell` も同様です) 。
* `Rc` は Send も Sync も実装していません (なぜなら参照カウントが共有され、これは同期されないからです) 。

<!--
`Rc` and `UnsafeCell` are very fundamentally not thread-safe: they enable
unsynchronized shared mutable state. However raw pointers are, strictly
speaking, marked as thread-unsafe as more of a *lint*. Doing anything useful
with a raw pointer requires dereferencing it, which is already unsafe. In that
sense, one could argue that it would be "fine" for them to be marked as thread
safe.
-->

`Rc` と `UnsafeCell` は本当に根本的にスレッドセーフではありません。すなわち、
これらは、同期されていない共有可変状態を実現できてしまうからです。しかしながら、
生ポインタは、厳密に言えば、*リント*において、より一層スレッドアンセーフです。
生ポインタで何か有益なことをしようとすれば、参照外しをする必要があるため、
もう既にアンセーフです。その意味で、これらをスレッドセーフとしてマークしても
"問題ない" と論じることも可能と言えるでしょう。

<!--
However it's important that they aren't thread safe to prevent types that
contain them from being automatically marked as thread safe. These types have
non-trivial untracked ownership, and it's unlikely that their author was
necessarily thinking hard about thread safety. In the case of Rc, we have a nice
example of a type that contains a `*mut` that is definitely not thread safe.
-->

しかしながら、これらの型を含んでいる型が、自動的にスレッドセーフとしてマークされないようにするために、
これらがスレッドセーフではないということは重要です。これらの型は、些細ではない、そして追跡されない
所有権を持ち、これらを書いた人が、本当にスレッドセーフについて熟考することは考えにくいです。
Rc の場合においては、 `*mut` を含んでいる型が絶対にスレッドセーフではない、ということに関する
素晴らしい例があります。

<!--
Types that aren't automatically derived can simply implement them if desired:
-->

自動的に継承されない型に関しても、必要ならば単純に実装することが可能です。

```rust
struct MyBox(*mut u8);

unsafe impl Send for MyBox {}
unsafe impl Sync for MyBox {}
```

<!--
In the *incredibly rare* case that a type is inappropriately automatically
derived to be Send or Sync, then one can also unimplement Send and Sync:
-->

*驚くほどに稀*な場合ですが、 Send や Sync が不適切かつ自動的に継承されてしまう
場合があります。このような場合、 Send や Sync の実装を取り払うことも可能です。

```rust
#![feature(optin_builtin_traits)]

// プリミティブな型を同期する何か魔法のようなセマンティクスがある!
struct SpecialThreadToken(u8);

impl !Send for SpecialThreadToken {}
impl !Sync for SpecialThreadToken {}
```

<!--
Note that *in and of itself* it is impossible to incorrectly derive Send and
Sync. Only types that are ascribed special meaning by other unsafe code can
possible cause trouble by being incorrectly Send or Sync.
-->

*それ自体では* Send や Sync を不正に継承してしまうことはありえないということに注意
してください。他のアンセーフなコードによって特別な意味を持ってしまった型のみが、
不正な Send や Sync によって問題を引き起こしてしまう可能性があります。

<!--
Most uses of raw pointers should be encapsulated behind a sufficient abstraction
that Send and Sync can be derived. For instance all of Rust's standard
collections are Send and Sync (when they contain Send and Sync types) in spite
of their pervasive use of raw pointers to manage allocations and complex ownership.
Similarly, most iterators into these collections are Send and Sync because they
largely behave like an `&` or `&mut` into the collection.
-->

生ポインタの使用者のほとんどは、 Send や Sync を継承できるよう、十分な抽象化の裏に
生ポインタをカプセル化するべきです。例えば Rust の全ての標準コレクションは、
アロケーションや複雑な所有権を操るために至るところで生ポインタを使用しているのにも関わらず、
Send と Sync を実装しています (これらの型が Send と Sync を実装している型を保持している場合) 。
同じように、これらのコレクションのほとんどのイテレータは、イテレータがコレクションに対して
`&` や `&mut` のように振る舞っているために、 Send や Sync を実装しています。

<!--
TODO: better explain what can or can't be Send or Sync. Sufficient to appeal
only to data races?
-->

TODO: 何が Send や Sync を実装できるか、あるいは実装できないかについてのもっと良い
説明。データ競合について述べるだけでも十分?

[unsafe traits]: safe-unsafe-meaning.html
