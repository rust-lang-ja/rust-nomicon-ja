<!--
# Leaking
-->

# リーク

<!--
Ownership-based resource management is intended to simplify composition. You
acquire resources when you create the object, and you release the resources when
it gets destroyed. Since destruction is handled for you, it means you can't
forget to release the resources, and it happens as soon as possible! Surely this
is perfect and all of our problems are solved.
-->

所有権に基づいたリソース管理は、構成を単純にすることを意図しています。
オブジェクトを生成すると、リソースを獲得します。そして、オブジェクトが
破棄されるとリソースを解放します。オブジェクトの破棄はプログラマの責任ですので、
リソースの解法を忘れることは出来ません。そしてできるだけ早く解放するのです!
確実にこれは完全で、我々の全ての問題は解決します。

<!--
Everything is terrible and we have new and exotic problems to try to solve.
-->

全ては最悪で、我々には新しくそして風変わりな問題があります。

<!--
Many people like to believe that Rust eliminates resource leaks. In practice,
this is basically true. You would be surprised to see a Safe Rust program
leak resources in an uncontrolled way.
-->

多くの人々は、 Rust はリソースのリークを取り除いたと信じることが好きです。
実際、これは基本的には正しいです。安全な Rust のプログラムが、制御不能なやり方で、
リソースをリークしたら驚かれるでしょう。

<!--
However from a theoretical perspective this is absolutely not the case, no
matter how you look at it. In the strictest sense, "leaking" is so abstract as
to be unpreventable. It's quite trivial to initialize a collection at the start
of a program, fill it with tons of objects with destructors, and then enter an
infinite event loop that never refers to it. The collection will sit around
uselessly, holding on to its precious resources until the program terminates (at
which point all those resources would have been reclaimed by the OS anyway).
-->

しかしながら理論的な観点から見れば、どのように見ても、これは全く真実ではありません。
最も厳密な意味では、 "リーク" は非常に抽象的で、防げるものではありません。
プログラムの始めでコレクションを初期化し、デストラクタと共に沢山のオブジェクトで
いっぱいにし、そしてこのコレクションを絶対に参照しない無限イベントループに
突入することは極めて些細なことです。コレクションはプログラムが終わるまで、
貴重な資源を保持し続けたまま、使われず無駄に浪費し続けます (そして OS によって
結局全ての資源は返還されますが) 。

<!--
We may consider a more restricted form of leak: failing to drop a value that is
unreachable. Rust also doesn't prevent this. In fact Rust *has a function for
doing this*: `mem::forget`. This function consumes the value it is passed *and
then doesn't run its destructor*.
-->

より厳密なリークの形式を考えたほうが良いかもしれません。到達できない値を
ドロップし損ねることです。 Rust はこれも防ぐことが出来ません。実際 Rust には、
*これを行なう関数があります*。 `mem::forget` です。この関数は渡された値を消費し、
*そしてその値のデストラクタを実行しません*。

<!--
In the past `mem::forget` was marked as unsafe as a sort of lint against using
it, since failing to call a destructor is generally not a well-behaved thing to
do (though useful for some special unsafe code). However this was generally
determined to be an untenable stance to take: there are many ways to fail to
call a destructor in safe code. The most famous example is creating a cycle of
reference-counted pointers using interior mutability.
-->

過去に `mem::forget` は、リントにおいてアンセーフとしてマークされていました。
デストラクタを呼ばないことは、通常行儀の良い方法ではないからです (いくつかの
特別なアンセーフのコードにおいては便利ですが) 。
しかしこれは、一般的に次の意見に対して擁護できない考えだと決定されました。
すなわち、 安全なコードでデストラクタを呼び損ねる方法が沢山存在するのです。
最も有名な例は、内部可変性を使用した、参照カウント方式のポインタの循環を生成
することです。

<!--
It is reasonable for safe code to assume that destructor leaks do not happen, as
any program that leaks destructors is probably wrong. However *unsafe* code
cannot rely on destructors to be run in order to be safe. For most types this
doesn't matter: if you leak the destructor then the type is by definition
inaccessible, so it doesn't matter, right? For instance, if you leak a `Box<u8>`
then you waste some memory but that's hardly going to violate memory-safety.
-->

安全なコードが、デストラクタのリークが起こらないと見なすことは理に適っています。
いかなるプログラムにおいても、デストラクタをリークするようなものは大体間違っていますから。
しかし、*アンセーフな*コードは、デストラクタがきちんと安全に実行されると信用できません。
ほとんどの型にとっては、これは問題ではありません。もしデストラクタをリークしたら、
当然その型へはアクセス不可能となります。ですからこれは問題ではありません。
そうですよね? 例えば、 `Box<u8>` をリークしても、いくらかのメモリを無駄にはしますが、
メモリ安全性はほとんど侵害することがないでしょう。

<!--
However where we must be careful with destructor leaks are *proxy* types. These
are types which manage access to a distinct object, but don't actually own it.
Proxy objects are quite rare. Proxy objects you'll need to care about are even
rarer. However we'll focus on three interesting examples in the standard
library:
-->

しかし、デストラクタのリークに対して注意深くならなければいけない場合は、*プロキシ*型です。
これらは、なんとかして異なったオブジェクトにアクセスするものの、そのオブジェクトを
実際には所有しない型です。プロキシオブジェクトは極めて稀です。気を付ける必要のある
プロキシオブジェクトに至っては殊更稀です。しかし、ここでは標準ライブラリにある 3 つの
興味深い例について着目していきます。

* `vec::Drain`
* `Rc`
* `thread::scoped::JoinGuard`



## Drain

<!--
`drain` is a collections API that moves data out of the container without
consuming the container. This enables us to reuse the allocation of a `Vec`
after claiming ownership over all of its contents. It produces an iterator
(Drain) that returns the contents of the Vec by-value.
-->

`drain` は、コンテナを消費せずにコンテナからデータをムーブする、
コレクションの API です。これによって、 `Vec` の全ての内容の所有権を獲得した後に、 `Vec` の
アロケーションを再利用することが出来ます。 `drain` は Vec の内容を値で返すイテレータ (Drain) を
生成します。

<!--
Now, consider Drain in the middle of iteration: some values have been moved out,
and others haven't. This means that part of the Vec is now full of logically
uninitialized data! We could backshift all the elements in the Vec every time we
remove a value, but this would have pretty catastrophic performance
consequences.
-->

では、 Drain がイテレーションの真っ最中であるとしましょう。ムーブされた値もあれば、
まだの値もあります。つまりこれは、 Vec の一部のデータが今、論理的には未初期化のデータで
埋まっていることを意味します!値を削除する度に Vec の要素を後ろにずらすことも出来たでしょう。
けれどもこれは結果的に、パフォーマンスをひどく落とすことになるでしょう。

<!--
Instead, we would like Drain to fix the Vec's backing storage when it is
dropped. It should run itself to completion, backshift any elements that weren't
removed (drain supports subranges), and then fix Vec's `len`. It's even
unwinding-safe! Easy!
-->

その代わりに Drain が、 Vecの背後にあるストレージがドロップした時に、 そのストレージを
修正するようにしたいと思います。 Drain は完璧に動き、削除されなかった要素は後ろに
ずらされ (Drain は副範囲をサポートしています) 、そして Vec の `len` を修正します。
巻き戻し安全でもあります! 簡単です!

<!--
Now consider the following:
-->

それでは以下の例を考えてみましょう。

```rust,ignore
let mut vec = vec![Box::new(0); 4];

{
    // ドレインを開始します。 vec にはもうアクセスできません
    let mut drainer = vec.drain(..);

    // 2 つの値を引き出し、即座にドロップします
    drainer.next();
    drainer.next();

    // drainer を取り除きますが、デストラクタは呼び出しません
    mem::forget(drainer);
}

// しまった、 vec[0] はドロップされていたんだった、解放されたメモリを読み出そうとしているぞ!
println!("{}", vec[0]);
```

<!--
This is pretty clearly Not Good. Unfortunately, we're kind of stuck between a
rock and a hard place: maintaining consistent state at every step has an
enormous cost (and would negate any benefits of the API). Failing to maintain
consistent state gives us Undefined Behavior in safe code (making the API
unsound).
-->

これは本当に明らかに良くないです。残念ながら、ある種の板挟みになっています。
すなわち、毎回のステップで一貫性のある状態を維持することは、膨大なコストが
発生するのです (そして API のあらゆる利点を消してしまうでしょう) 。
一貫性のある状態を維持できないことで、安全なコードで未定義動作を起こしてしまいます (これにより API が
不健全となってしまいます) 。

<!--
So what can we do? Well, we can pick a trivially consistent state: set the Vec's
len to be 0 when we start the iteration, and fix it up if necessary in the
destructor. That way, if everything executes like normal we get the desired
behavior with minimal overhead. But if someone has the *audacity* to
mem::forget us in the middle of the iteration, all that does is *leak even more*
(and possibly leave the Vec in an unexpected but otherwise consistent state).
Since we've accepted that mem::forget is safe, this is definitely safe. We call
leaks causing more leaks a *leak amplification*.
-->

ではどうすればいいのでしょうか? うーん、ちょっと一貫性のある状態を選択することが出来ます。
すなわち、イテレーションの初めでは Vec の len を 0 に設定し、そしてもし必要ならば、
デストラクタ内で len を修正します。このようにすることで、もしすべてが普通に実行されるなら、
最小限のオーバーヘッドで望まれている振る舞いを得ることが出来ます。
しかし、もし*大胆にも* mem::forget がイテレーションの真ん中に存在したら、
この関数によって、*更に多くのものがリークされます* (そして多分 Vec を
予期しない状態か、そうでないなら一貫性のある状態にするでしょう) 。 mem::forget は安全だとして
受け入れたので、このリークは絶対安全です。リークがより多くのリークを引き起こしてしまうことを、
*リークの増幅*と呼びます。




## Rc

<!--
Rc is an interesting case because at first glance it doesn't appear to be a
proxy value at all. After all, it manages the data it points to, and dropping
all the Rcs for a value will drop that value. Leaking an Rc doesn't seem like it
would be particularly dangerous. It will leave the refcount permanently
incremented and prevent the data from being freed or dropped, but that seems
just like Box, right?
-->

Rc は興味深いケースです。なぜなら、ひと目見ただけでは、 Rc がプロキシな値とは全く見えないからです。
結局、 Rc は自身が指しているデータを操作し、その値に対する Rc が全てドロップされることで、
その値もドロップされます。 Rc をリークすることは特に危険のようには見えません。
参照カウントが永遠にインクリメントされたまま、データが解放されたりドロップされるのを
妨害します。けれどもこれは単に Box に似ています。そうですよね?

<!--
Nope.
-->

いいえ。

<!--
Let's consider a simplified implementation of Rc:
-->

では、以下の単純化された Rc の実装を確認しましょう。

```rust,ignore
struct Rc<T> {
    ptr: *mut RcBox<T>,
}

struct RcBox<T> {
    data: T,
    ref_count: usize,
}

impl<T> Rc<T> {
    fn new(data: T) -> Self {
        unsafe {
            // もし heap::allocate がこのように動作したら便利だと思いませんか?
            let ptr = heap::allocate::<RcBox<T>>();
            ptr::write(ptr, RcBox {
                data: data,
                ref_count: 1,
            });
            Rc { ptr: ptr }
        }
    }

    fn clone(&self) -> Self {
        unsafe {
            (*self.ptr).ref_count += 1;
        }
        Rc { ptr: self.ptr }
    }
}

impl<T> Drop for Rc<T> {
    fn drop(&mut self) {
        unsafe {
            (*self.ptr).ref_count -= 1;
            if (*self.ptr).ref_count == 0 {
                // データをドロップしそして解放します
                ptr::read(self.ptr);
                heap::deallocate(self.ptr);
            }
        }
    }
}
```

<!--
This code contains an implicit and subtle assumption: `ref_count` can fit in a
`usize`, because there can't be more than `usize::MAX` Rcs in memory. However
this itself assumes that the `ref_count` accurately reflects the number of Rcs
in memory, which we know is false with `mem::forget`. Using `mem::forget` we can
overflow the `ref_count`, and then get it down to 0 with outstanding Rcs. Then
we can happily use-after-free the inner data. Bad Bad Not Good.
-->

このコードは暗黙で微妙な前提を含んでいます。すなわち、 `ref_count` が `usize` に
収まるということです。なぜなら、 `usize::MAX` 個以上の Rc はメモリに存在し得ないからです。
しかしながら、これ自体が `ref_count` が正確に、メモリ上にある Rc の数を反映しているという
前提の上にあります。ご存知のように、 `mem::forget` のせいでこれは正しくありません。 `mem::forget` を
使用することで、 `ref_count` をオーバーフローすることが可能です。そして、既に存在する Rc があるのに
値は 0 になります。そうして適切に内部データを解放後に使用します。全く良いところのない、最悪だ。

This can be solved by just checking the `ref_count` and doing *something*. The
standard library's stance is to just abort, because your program has become
horribly degenerate. Also *oh my gosh* it's such a ridiculous corner case.




## thread::scoped::JoinGuard

The thread::scoped API intends to allow threads to be spawned that reference
data on their parent's stack without any synchronization over that data by
ensuring the parent joins the thread before any of the shared data goes out
of scope.

```rust,ignore
pub fn scoped<'a, F>(f: F) -> JoinGuard<'a>
    where F: FnOnce() + Send + 'a
```

Here `f` is some closure for the other thread to execute. Saying that
`F: Send +'a` is saying that it closes over data that lives for `'a`, and it
either owns that data or the data was Sync (implying `&data` is Send).

Because JoinGuard has a lifetime, it keeps all the data it closes over
borrowed in the parent thread. This means the JoinGuard can't outlive
the data that the other thread is working on. When the JoinGuard *does* get
dropped it blocks the parent thread, ensuring the child terminates before any
of the closed-over data goes out of scope in the parent.

Usage looked like:

```rust,ignore
let mut data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
{
    let guards = vec![];
    for x in &mut data {
        // Move the mutable reference into the closure, and execute
        // it on a different thread. The closure has a lifetime bound
        // by the lifetime of the mutable reference `x` we store in it.
        // The guard that is returned is in turn assigned the lifetime
        // of the closure, so it also mutably borrows `data` as `x` did.
        // This means we cannot access `data` until the guard goes away.
        let guard = thread::scoped(move || {
            *x *= 2;
        });
        // store the thread's guard for later
        guards.push(guard);
    }
    // All guards are dropped here, forcing the threads to join
    // (this thread blocks here until the others terminate).
    // Once the threads join, the borrow expires and the data becomes
    // accessible again in this thread.
}
// data is definitely mutated here.
```

In principle, this totally works! Rust's ownership system perfectly ensures it!
...except it relies on a destructor being called to be safe.

```rust,ignore
let mut data = Box::new(0);
{
    let guard = thread::scoped(|| {
        // This is at best a data race. At worst, it's also a use-after-free.
        *data += 1;
    });
    // Because the guard is forgotten, expiring the loan without blocking this
    // thread.
    mem::forget(guard);
}
// So the Box is dropped here while the scoped thread may or may not be trying
// to access it.
```

Dang. Here the destructor running was pretty fundamental to the API, and it had
to be scrapped in favor of a completely different design.
