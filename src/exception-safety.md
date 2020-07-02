<!--
# Exception Safety
-->

# 例外安全性

<!--
Although programs should use unwinding sparingly, there's a lot of code that
*can* panic. If you unwrap a None, index out of bounds, or divide by 0, your
program will panic. On debug builds, every arithmetic operation can panic
if it overflows. Unless you are very careful and tightly control what code runs,
pretty much everything can unwind, and you need to be ready for it.
-->

プログラム内では巻き戻しを注意深く使用するべきですが、パニック*し得る*コードが
たくさんあります。もし None をアンラップしたり、境界外のインデックスを指定したり、
0 で除算したりしたら、プログラムはパニックするでしょう。デバッグビルドでは、
全ての算術演算は、オーバーフロー時にパニックします。非常に注意深く、
そしてどのコードを実行するかを厳しくコントロールしない限り、ほとんどすべての
コードが巻き戻しをする可能性があり、これに対して準備をする必要があります。

<!--
Being ready for unwinding is often referred to as *exception safety*
in the broader programming world. In Rust, there are two levels of exception
safety that one may concern themselves with:
-->

巻き戻しに対して準備が出来ていることは、もっと広いプログラミングの世界において、
しばしば*例外安全*と呼ばれています。 Rust では、プログラムが関わる可能性のある、
2 つの例外安全のレベルがあります。

<!--
* In unsafe code, we *must* be exception safe to the point of not violating
  memory safety. We'll call this *minimal* exception safety.

* In safe code, it is *good* to be exception safe to the point of your program
  doing the right thing. We'll call this *maximal* exception safety.
-->

* アンセーフなコードでは、メモリ安全性を侵害しないという点において、
  例外安全で*なければなりません*。これを、*最小限*の例外安全と呼びます。

* 安全なコードでは、プログラムが正しいことを行なうという点において、
  例外安全であると*良い*です。これを*最大限*の例外安全と呼びます。

<!--
As is the case in many places in Rust, Unsafe code must be ready to deal with
bad Safe code when it comes to unwinding. Code that transiently creates
unsound states must be careful that a panic does not cause that state to be
used. Generally this means ensuring that only non-panicking code is run while
these states exist, or making a guard that cleans up the state in the case of
a panic. This does not necessarily mean that the state a panic witnesses is a
fully coherent state. We need only guarantee that it's a *safe* state.
-->

Rust の多くの場において事実なのですが、巻き戻しとなると、アンセーフなコードは、
悪い安全なコードに対処する準備をしなければなりません。一時的に健全ではない
状態を生むコードは、パニックによってその状態が使用されないよう、注意深く
扱わなければなりません。一般的にこれは、このような健全でない状態が存在する間、
パニックを起こさないコードのみを確実に実行させることを意味するか、あるいは
パニックの際、その状態を片付けるガードを生成することを意味します。
これは必ずしも、パニックが起きているときの状態が、完全に意味のある状態であるということを
意味しません。*安全な*状態であると保証されていることだけが必要なのです。

<!--
Most Unsafe code is leaf-like, and therefore fairly easy to make exception-safe.
It controls all the code that runs, and most of that code can't panic. However
it is not uncommon for Unsafe code to work with arrays of temporarily
uninitialized data while repeatedly invoking caller-provided code. Such code
needs to be careful and consider exception safety.
-->

ほとんどのアンセーフなコードは葉のようなもので、それ故に割と簡単に例外安全に
出来ます。例外安全によって実行されるコードが管理され、そしてほとんどのコードは
パニックしません。しかし、アンセーフなコードが繰り返し呼び出し側のコードを実行
している間に、部分的に初期化されていない配列を扱うことはよくあります。
このようなコードは注意深く扱い、例外安全を考える必要があるのです。





## Vec::push_all

<!--
`Vec::push_all` is a temporary hack to get extending a Vec by a slice reliably
efficient without specialization. Here's a simple implementation:
-->

`Vec::push_all` は、特殊化なしに、スライスが確実に効率的であることを利用した、
Vec を伸ばす一時的なハックです。これは単純な実装です。

```rust,ignore
impl<T: Clone> Vec<T> {
    fn push_all(&mut self, to_push: &[T]) {
        self.reserve(to_push.len());
        unsafe {
            // 今さっき reserve をしましたので、オーバーフローするはずがありません
            self.set_len(self.len() + to_push.len());

            for (i, x) in to_push.iter().enumerate() {
                self.ptr().offset(i as isize).write(x.clone());
            }
        }
    }
}
```

<!--
We bypass `push` in order to avoid redundant capacity and `len` checks on the
Vec that we definitely know has capacity. The logic is totally correct, except
there's a subtle problem with our code: it's not exception-safe! `set_len`,
`offset`, and `write` are all fine; `clone` is the panic bomb we over-looked.
-->

絶対にキャパシティがあると分かっている Vec の capacity と `len` の余分なチェックを
回避するため、 `push` を使用していません。論理は完全に正しいです。但し、
このコードに微妙な問題が含まれていることを除く。すなわち、このコードは例外安全
ではないのです! `set_len` と `offset` と `write` は全部問題ありません。 `clone` は、
我々が見落としていたパニックの起爆装置です。

<!--
Clone is completely out of our control, and is totally free to panic. If it
does, our function will exit early with the length of the Vec set too large. If
the Vec is looked at or dropped, uninitialized memory will be read!
-->

Clone は全く制御不能で、全く自由にパニックしてしまいます。もしパニックしてしまえば、
この関数は、 Vec の長さが大きすぎる値に設定されたまま、早期に終了してしまいます。
もし Vec が読み出されたりドロップされたりすると、未初期化のメモリが読み出されて
しまいます!

<!--
The fix in this case is fairly simple. If we want to guarantee that the values
we *did* clone are dropped, we can set the `len` every loop iteration. If we
just want to guarantee that uninitialized memory can't be observed, we can set
the `len` after the loop.
-->

この場合、修正は割と簡単です。もし*本当に*、クローンした値がドロップされたと
いうことを保証したいのなら、全てのループのイテレーションにおいて、 `len` を
設定することが出来ます。もし単に、未初期化のメモリが読まれないようにしたいのなら、
ループの後に `len` を設定することが出来ます。



## BinaryHeap::sift_up

<!--
Bubbling an element up a heap is a bit more complicated than extending a Vec.
The pseudocode is as follows:
-->

ヒープのアップヒープは Vec を伸ばすことよりちょっと複雑です。擬似コードはこんな感じです。

```text
bubble_up(heap, index):
    while index != 0 && heap[index] < heap[parent(index)]:
        heap.swap(index, parent(index))
        index = parent(index)

```

<!--
A literal transcription of this code to Rust is totally fine, but has an annoying
performance characteristic: the `self` element is swapped over and over again
uselessly. We would rather have the following:
-->

このコードを Rust に直訳するのは全く問題ありません。ですが、嫌になるようなパフォーマンス
です。すなわち、 `self` の要素が無駄に交換され続けます。それならむしろ、以下のコードの方が
良いでしょう。

```text
bubble_up(heap, index):
    let elem = heap[index]
    while index != 0 && elem < heap[parent(index)]:
        heap[index] = heap[parent(index)]
        index = parent(index)
    heap[index] = elem
```

<!--
This code ensures that each element is copied as little as possible (it is in
fact necessary that elem be copied twice in general). However it now exposes
some exception safety trouble! At all times, there exists two copies of one
value. If we panic in this function something will be double-dropped.
Unfortunately, we also don't have full control of the code: that comparison is
user-defined!
-->

このコードでは確実に、それぞれの要素ができるだけ少ない回数でコピーされます
(実は一般的に、要素を 2 回コピーすることが必要なのです) 。しかし、これによって、
いくつか例外安全性の問題が露見しました! 毎回、ある値に対する 2 つのコピーが
存在します。もしこの関数内でパニックしたら、何かが 2 回ドロップされてしまいます。
残念ながら、このコードに関しても、完全にコントロールすることは出来ません。
比較がユーザ定義されているのです!

<!--
Unlike Vec, the fix isn't as easy here. One option is to break the user-defined
code and the unsafe code into two separate phases:
-->

Vec とは違い、これを直すのは簡単ではありません。一つの選択肢として、ユーザ定義の
コードとアンセーフなコードを、 2 つの段階に分割することです。

```text
bubble_up(heap, index):
    let end_index = index;
    while end_index != 0 && heap[end_index] < heap[parent(end_index)]:
        end_index = parent(end_index)

    let elem = heap[index]
    while index != end_index:
        heap[index] = heap[parent(index)]
        index = parent(index)
    heap[index] = elem
```

<!--
If the user-defined code blows up, that's no problem anymore, because we haven't
actually touched the state of the heap yet. Once we do start messing with the
heap, we're working with only data and functions that we trust, so there's no
concern of panics.
-->

もしユーザ定義のコードでトラブっても、もう問題ありません。なぜなら、
ヒープの状態にはまだ触れていないからです。ヒープを実際に弄るとき、
信用しているデータや関数のみを扱っています。ですからもうパニックの心配は
ありません。

<!--
Perhaps you're not happy with this design. Surely it's cheating! And we have
to do the complex heap traversal *twice*! Alright, let's bite the bullet. Let's
intermix untrusted and unsafe code *for reals*.
-->

多分、この設計を嬉しく思わないでしょう。明らかに騙している! そして複雑な
ヒープのトラバーサルを *2 回* 行わなければならない! 分かった、我慢しよう。
信用していないコードやアンセーフなコードを*本気で*混ぜてみよう。

<!--
If Rust had `try` and `finally` like in Java, we could do the following:
-->

もし Rust に Java のような `try` と `finally` があったら、コードは
こんな感じだったでしょう。

```text
bubble_up(heap, index):
    let elem = heap[index]
    try:
        while index != 0 && element < heap[parent(index)]:
            heap[index] = heap[parent(index)]
            index = parent(index)
    finally:
        heap[index] = elem
```

<!--
The basic idea is simple: if the comparison panics, we just toss the loose
element in the logically uninitialized index and bail out. Anyone who observes
the heap will see a potentially *inconsistent* heap, but at least it won't
cause any double-drops! If the algorithm terminates normally, then this
operation happens to coincide precisely with the how we finish up regardless.
-->

基本的な考えは単純です。すなわち、もし比較においてパニックしたのなら、単に要素を
論理的に未初期化のインデックスの位置に保存し、脱出します。このヒープを観察する誰もが、
潜在的には*一貫性のない*ヒープを目にするでしょうが、少なくともこのコードは二重ドロップを
起こしません! もしアルゴリズムが通常通り終了すれば、この操作はコードがどのように終了するかに
関わらず、結果を正確に一致させるために実行されます。

<!--
Sadly, Rust has no such construct, so we're going to need to roll our own! The
way to do this is to store the algorithm's state in a separate struct with a
destructor for the "finally" logic. Whether we panic or not, that destructor
will run and clean up after us.
-->

悲しいことに、 Rust にはそのような構造が存在しません。ですので、自分たちで退避させなければ
ならないようです! これを行なうには、 "finally" の論理を構成するため、デストラクタと共に
アルゴリズムの状態を、別の構造体に保存します。パニックしようがしまいが、デストラクタは
実行され、状態を綺麗にします。

```rust,ignore
struct Hole<'a, T: 'a> {
    data: &'a mut [T],
    /// `elt` は new で生成されたときからドロップまで、常に Some です
    elt: Option<T>,
    pos: usize,
}

impl<'a, T> Hole<'a, T> {
    fn new(data: &'a mut [T], pos: usize) -> Self {
        unsafe {
            let elt = ptr::read(&data[pos]);
            Hole {
                data: data,
                elt: Some(elt),
                pos: pos,
            }
        }
    }

    fn pos(&self) -> usize { self.pos }

    fn removed(&self) -> &T { self.elt.as_ref().unwrap() }

    unsafe fn get(&self, index: usize) -> &T { &self.data[index] }

    unsafe fn move_to(&mut self, index: usize) {
        let index_ptr: *const _ = &self.data[index];
        let hole_ptr = &mut self.data[self.pos];
        ptr::copy_nonoverlapping(index_ptr, hole_ptr, 1);
        self.pos = index;
    }
}

impl<'a, T> Drop for Hole<'a, T> {
    fn drop(&mut self) {
        // 穴を再び埋めます
        unsafe {
            let pos = self.pos;
            ptr::write(&mut self.data[pos], self.elt.take().unwrap());
        }
    }
}

impl<T: Ord> BinaryHeap<T> {
    fn sift_up(&mut self, pos: usize) {
        unsafe {
            // `pos` にある値を受け取り、穴を作ります。
            let mut hole = Hole::new(&mut self.data, pos);

            while hole.pos() != 0 {
                let parent = parent(hole.pos());
                if hole.removed() <= hole.get(parent) { break }
                hole.move_to(parent);
            }
            // 状況に関わらず、穴はここで埋まります。パニックしてもしなくても!
        }
    }
}
```
