<!-- # Exception Safety -->
# 例外安全性

<!--
Although programs should use unwinding sparingly, there's a lot of code that
*can* panic. If you unwrap a None, index out of bounds, or divide by 0, your
program will panic. On debug builds, every arithmetic operation can panic
if it overflows. Unless you are very careful and tightly control what code runs,
pretty much everything can unwind, and you need to be ready for it.
-->
プログラム中のunwindの使用は補助的なものにとどめるべきですが、panicすることが
**可能な**コードは数多くあります。Noneをunwrapしたり、範囲外のインデックスアクセス
を行ったり、値を0で割ったりすれば、プログラムはpanicします。debugビルドの場合、
任意の代数的計算がオーバーフローするとpanicを引き起こす可能性があります。
コードが実行する内容に非常に気を使わない限り、ほぼ全てにおいてunwindする可能性が
あり、したがって備える必要があります。

<!--
Being ready for unwinding is often referred to as *exception safety*
in the broader programming world. In Rust, there are two levels of exception
safety that one may concern themselves with:
-->
unwindに備えることを、プログラミング一般の用語で**例外安全(exception safety)**
であると呼びます。Rustの場合、例外安全性には２種類の関わり方があります。


<!--
* In unsafe code, we *must* be exception safe to the point of not violating
  memory safety. We'll call this *minimal* exception safety.
-->
* unsafeなコード中ではメモリ安全性を損なわない程度の例外安全性が**必要**です。
ここではこれを**最低限の**例外安全性と呼ぶことにします。

<!--
* In safe code, it is *good* to be exception safe to the point of your program
  doing the right thing. We'll call this *maximal* exception safety.
 -->
* safeなコード中では、プログラムが意図した通りに動作する程度の例外安全性が**推奨**
されています。ここではこれを**最大限の**例外安全性と呼ぶことにします。

<!--
As is the case in many places in Rust, Unsafe code must be ready to deal with
bad Safe code when it comes to unwinding. Code that transiently creates
unsound states must be careful that a panic does not cause that state to be
used. Generally this means ensuring that only non-panicking code is run while
these states exist, or making a guard that cleans up the state in the case of
a panic. This does not necessarily mean that the state a panic witnesses is a
fully coherent state. We need only guarantee that it's a *safe* state.
-->
Rustにおいては大抵、unsafeなコードは不適切なsafeコードに対処する準備を
しておく必要がありますが、unwindingに関しても同様です。
一時的によろしくない状態を作り出すコードの場合、panicによってその状態が使用
されないように注意する必要があります。一般的に、これはこの状態が存在する際には
panicが起こらないようにするか、panic時にクリーンアップを行うようなガードを
実装するかのいずれかによって対処します。
これはpanicしたコードが見る状態が無矛盾であることを必ずしも意味しません。
ただ、その状態が*safe*であることを保証できれば良いのです。

<!--
Most Unsafe code is leaf-like, and therefore fairly easy to make exception-safe.
It controls all the code that runs, and most of that code can't panic. However
it is not uncommon for Unsafe code to work with arrays of temporarily
uninitialized data while repeatedly invoking caller-provided code. Such code
needs to be careful and consider exception safety.
-->
多くのunsafeなコードは木構造の先端(leaf-like)であり、したがって例外安全にするのは
難しくありません。実行されるコード全体を制御下におくことができ、そのほとんどは
panicできないためです。しかしながら、unsafeコードブロック中においては一時的に
未初期化の領域を持つ配列を持ちつつ、呼び出し元から与えられたコードを繰り返し
実行することもしばしばです。そのような場合には例外安全である
ことを慎重に確かめなくてはなりません。


## Vec::push_all

<!--
`Vec::push_all` is a temporary hack to get extending a Vec by a slice reliably
efficient without specialization. Here's a simple implementation:
-->
`Vec::push_all`はVecを特殊化せずに効率的に伸長させるための一時的なハックです。
以下に簡単な実装を示します。

```rust,ignore
impl<T: Clone> Vec<T> {
    fn push_all(&mut self, to_push: &[T]) {
        self.reserve(to_push.len());
        unsafe {
            // can't overflow because we just reserved this
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
余計なキャパシティの確保と、確実にキャパシティを持つとわかっているVecに対する
`len`チェックを避けるため、`push`の使用を避けています。このコードはロジックは
完全に正しいのですが、ちょっとした問題があります。例外安全ではないのです！
`set_len`、`offset`、`write`は全く問題がないのですが、`clone`がpanicの火種
となることを見落としていました。

<!--
Clone is completely out of our control, and is totally free to panic. If it
does, our function will exit early with the length of the Vec set too large. If
the Vec is looked at or dropped, uninitialized memory will be read!
-->
Cloneは完全に我々の制御から完全に外れており、勝手にpanicする可能性がります。
そうなった場合、Vecの長さが長すぎる状態になったまま、関数がexitします。その後に
Vecが使われたりdropされたりした場合、未初期化のメモリが読まれることになるのです！

<!--
The fix in this case is fairly simple. If we want to guarantee that the values
we *did* clone are dropped, we can set the `len` every loop iteration. If we
just want to guarantee that uninitialized memory can't be observed, we can set
the `len` after the loop.
-->
このケースの場合、修正は比較的容易です。クローンを**行なった**値がdropされること
を保証するため、ループのイテレーション毎に`len`をセットすれば良いのです。単に
未初期化のメモリアクセスを避けたいというだけならば、loopの後に`len`をセットすれば
OKです。



## BinaryHeap::sift_up

<!--
Bubbling an element up a heap is a bit more complicated than extending a Vec.
The pseudocode is as follows:
-->
ヒープ上の要素を(バブルソート的に)比較して整列するような場合、Vecの伸長よりも
話は複雑になります。以下は疑似コードです。

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
これをRustでそのまま実装すること自体は全く問題がありませんが、パフォーマンス上
考慮しなくてはならない問題点が存在します。`self`が何度も無意味にスワップされて
しまうのです。以下の方が良いでしょう。

```text
bubble_up(heap, index):
    let elem = heap[index]
    while index != 0 && element < heap[parent(index)]:
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
こうすることで要素のコピーを最小に抑えられます(実際のところ、一般的に要素が二回
コピーされる必要があります)が、例外安全性に関する問題が発生してしまいます！常に
単一の値のコピーが二つ存在するので、この関数内でpanicが起きると何かが二回drop
されてしまうのです。残念なことに、コードの全体をコントロール下におくことも
できていません。比較時の挙動はユーザー定義であるためです！

<!--
Unlike Vec, the fix isn't as easy here. One option is to break the user-defined
code and the unsafe code into two separate phases:
-->
Vecの場合と違い、対処法は単純ではありません。一つの方法はユーザー定義コードを
分割してunsafeなコードを二つに分けることです。

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
前半ではヒープの状態にまだ触れていないので、ユーザー定義コードが爆発しても
問題ではありません。ヒープ自体に触る時には信頼済みのデータと
関数だけを対象としているため、panicの心配をしなくて済みます。

<!--
Perhaps you're not happy with this design. Surely it's cheating! And we have
to do the complex heap traversal *twice*! Alright, let's bite the bullet. Let's
intermix untrusted and unsafe code *for reals*.
-->
おそらくこのデザインには不満を感じるでしょう。というのもこれはある意味でずるを
しているようなものであり、複雑なheapの走査を**二回も！**しなくてはならない
ためです。
では、ちょっと辛いかもしれませんがもう少し現実的なやり方で信頼できないコードと
unsafeなコードを混ぜてみましょう。

<!--
If Rust had `try` and `finally` like in Java, we could do the following:
-->
もしRustにJavaのような`try`と`finally`を存在したならば、以下のような書き方が
できます。

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
基本的な考え方は単純です。比較時にパニックが起きた場合、論理的に初期化されて
いないindexの未確定な要素を投げ捨てて関数を脱出します。heapの内容をみようとした場合、
**矛盾した**内容を見る可能性はありますが、少なくとも二回ドロップするようなこと
は無くなります！アルゴリズムが正常終了した場合も、ここでの手続きは最終的に同じ
結果をもたらします。

<!--
Sadly, Rust has no such construct, so we're going to need to roll our own! The
way to do this is to store the algorithm's state in a separate struct with a
destructor for the "finally" logic. Whether we panic or not, that destructor
will run and clean up after us.
-->
残念ながらRustにはこのような機能は存在しないので、自作しましょう！「finally」
のロジック実装したデストラクタを持ったstructの中にアルゴリズムの状態を保存
することで実装します。panicするしないに関わらず、このデストラクタが
クリーンアップを行なってくれます。

```rust,ignore
struct Hole<'a, T: 'a> {
    data: &'a mut [T],
    /// `elt` はnewからdropするまでの間常に `Some` です。
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
        // 再度空白を埋める
        unsafe {
            let pos = self.pos;
            ptr::write(&mut self.data[pos], self.elt.take().unwrap());
        }
    }
}

impl<T: Ord> BinaryHeap<T> {
    fn sift_up(&mut self, pos: usize) {
        unsafe {
            // `pos` から値を取り出して空白を作る
            let mut hole = Hole::new(&mut self.data, pos);

            while hole.pos() != 0 {
                let parent = parent(hole.pos());
                if hole.removed() <= hole.get(parent) { break }
                hole.move_to(parent);
            }
            // panicの有無に関係なく空白はここで必ずここで埋められる！
        }
    }
}
```
