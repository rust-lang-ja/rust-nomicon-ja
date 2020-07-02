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
している間に、部分的に初期化されていないデータを扱うことはよくあります。
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
            // can't overflow because we just reserved this
            self.set_len(self.len() + to_push.len());

            for (i, x) in to_push.iter().enumerate() {
                self.ptr().offset(i as isize).write(x.clone());
            }
        }
    }
}
```

We bypass `push` in order to avoid redundant capacity and `len` checks on the
Vec that we definitely know has capacity. The logic is totally correct, except
there's a subtle problem with our code: it's not exception-safe! `set_len`,
`offset`, and `write` are all fine; `clone` is the panic bomb we over-looked.

Clone is completely out of our control, and is totally free to panic. If it
does, our function will exit early with the length of the Vec set too large. If
the Vec is looked at or dropped, uninitialized memory will be read!

The fix in this case is fairly simple. If we want to guarantee that the values
we *did* clone are dropped, we can set the `len` every loop iteration. If we
just want to guarantee that uninitialized memory can't be observed, we can set
the `len` after the loop.





## BinaryHeap::sift_up

Bubbling an element up a heap is a bit more complicated than extending a Vec.
The pseudocode is as follows:

```text
bubble_up(heap, index):
    while index != 0 && heap[index] < heap[parent(index)]:
        heap.swap(index, parent(index))
        index = parent(index)

```

A literal transcription of this code to Rust is totally fine, but has an annoying
performance characteristic: the `self` element is swapped over and over again
uselessly. We would rather have the following:

```text
bubble_up(heap, index):
    let elem = heap[index]
    while index != 0 && element < heap[parent(index)]:
        heap[index] = heap[parent(index)]
        index = parent(index)
    heap[index] = elem
```

This code ensures that each element is copied as little as possible (it is in
fact necessary that elem be copied twice in general). However it now exposes
some exception safety trouble! At all times, there exists two copies of one
value. If we panic in this function something will be double-dropped.
Unfortunately, we also don't have full control of the code: that comparison is
user-defined!

Unlike Vec, the fix isn't as easy here. One option is to break the user-defined
code and the unsafe code into two separate phases:

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

If the user-defined code blows up, that's no problem anymore, because we haven't
actually touched the state of the heap yet. Once we do start messing with the
heap, we're working with only data and functions that we trust, so there's no
concern of panics.

Perhaps you're not happy with this design. Surely it's cheating! And we have
to do the complex heap traversal *twice*! Alright, let's bite the bullet. Let's
intermix untrusted and unsafe code *for reals*.

If Rust had `try` and `finally` like in Java, we could do the following:

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

The basic idea is simple: if the comparison panics, we just toss the loose
element in the logically uninitialized index and bail out. Anyone who observes
the heap will see a potentially *inconsistent* heap, but at least it won't
cause any double-drops! If the algorithm terminates normally, then this
operation happens to coincide precisely with the how we finish up regardless.

Sadly, Rust has no such construct, so we're going to need to roll our own! The
way to do this is to store the algorithm's state in a separate struct with a
destructor for the "finally" logic. Whether we panic or not, that destructor
will run and clean up after us.

```rust,ignore
struct Hole<'a, T: 'a> {
    data: &'a mut [T],
    /// `elt` is always `Some` from new until drop.
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
        // fill the hole again
        unsafe {
            let pos = self.pos;
            ptr::write(&mut self.data[pos], self.elt.take().unwrap());
        }
    }
}

impl<T: Ord> BinaryHeap<T> {
    fn sift_up(&mut self, pos: usize) {
        unsafe {
            // Take out the value at `pos` and create a hole.
            let mut hole = Hole::new(&mut self.data, pos);

            while hole.pos() != 0 {
                let parent = parent(hole.pos());
                if hole.removed() <= hole.get(parent) { break }
                hole.move_to(parent);
            }
            // Hole will be unconditionally filled here; panic or not!
        }
    }
}
```
