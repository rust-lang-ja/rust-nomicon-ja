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
型がこのアクセスを管理するために同期を行なわない限り、これは絶対スレッドセーフでは
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
これはつまり、これらを実装するのはアンセーフで、他のアンセーフなコードが、これらのトレイトが正しく
実装されていると見なすことができます。これらのトレイトは*マーカートレイト*
(これらのトレイトは、メソッドなどの関連情報を備えていません) ですので、正しく実装することは、
これらのトレイトが、型を実装するものが持っているべき intrinsic の特性を持っているということを
単に意味します。 Send や Sync が正しく実装されていないと、未定義動作を引き起こします。

Send and Sync are also automatically derived traits. This means that, unlike
every other trait, if a type is composed entirely of Send or Sync types, then it
is Send or Sync. Almost all primitives are Send and Sync, and as a consequence
pretty much all types you'll ever interact with are Send and Sync.

Major exceptions include:

* raw pointers are neither Send nor Sync (because they have no safety guards).
* `UnsafeCell` isn't Sync (and therefore `Cell` and `RefCell` aren't).
* `Rc` isn't Send or Sync (because the refcount is shared and unsynchronized).

`Rc` and `UnsafeCell` are very fundamentally not thread-safe: they enable
unsynchronized shared mutable state. However raw pointers are, strictly
speaking, marked as thread-unsafe as more of a *lint*. Doing anything useful
with a raw pointer requires dereferencing it, which is already unsafe. In that
sense, one could argue that it would be "fine" for them to be marked as thread
safe.

However it's important that they aren't thread safe to prevent types that
contain them from being automatically marked as thread safe. These types have
non-trivial untracked ownership, and it's unlikely that their author was
necessarily thinking hard about thread safety. In the case of Rc, we have a nice
example of a type that contains a `*mut` that is definitely not thread safe.

Types that aren't automatically derived can simply implement them if desired:

```rust
struct MyBox(*mut u8);

unsafe impl Send for MyBox {}
unsafe impl Sync for MyBox {}
```

In the *incredibly rare* case that a type is inappropriately automatically
derived to be Send or Sync, then one can also unimplement Send and Sync:

```rust
#![feature(optin_builtin_traits)]

// I have some magic semantics for some synchronization primitive!
struct SpecialThreadToken(u8);

impl !Send for SpecialThreadToken {}
impl !Sync for SpecialThreadToken {}
```

Note that *in and of itself* it is impossible to incorrectly derive Send and
Sync. Only types that are ascribed special meaning by other unsafe code can
possible cause trouble by being incorrectly Send or Sync.

Most uses of raw pointers should be encapsulated behind a sufficient abstraction
that Send and Sync can be derived. For instance all of Rust's standard
collections are Send and Sync (when they contain Send and Sync types) in spite
of their pervasive use of raw pointers to manage allocations and complex ownership.
Similarly, most iterators into these collections are Send and Sync because they
largely behave like an `&` or `&mut` into the collection.

TODO: better explain what can or can't be Send or Sync. Sufficient to appeal
only to data races?

[unsafe traits]: safe-unsafe-meaning.html
