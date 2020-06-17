<!--
# Splitting Borrows
-->

# 借用の分割

<!--
The mutual exclusion property of mutable references can be very limiting when
working with a composite structure. The borrow checker understands some basic
stuff, but will fall over pretty easily. It does understand structs
sufficiently to know that it's possible to borrow disjoint fields of a struct
simultaneously. So this works today:
-->

可変参照の相互排他性は、複合構造体を使用している時に非常に制限を課してくる存在となります。
借用チェッカはいくつか基本事項を理解していますが、本当に簡単にすっ転びます。
借用チェッカは構造体について十分理解しているため、構造体の別々のフィールドを同時に借用することは可能です。
ですから、このコードは今日動作します。

```rust
struct Foo {
    a: i32,
    b: i32,
    c: i32,
}

let mut x = Foo {a: 0, b: 0, c: 0};
let a = &mut x.a;
let b = &mut x.b;
let c = &x.c;
*b += 1;
let c2 = &x.c;
*a += 10;
println!("{} {} {} {}", a, b, c, c2);
```

<!--
However borrowck doesn't understand arrays or slices in any way, so this doesn't
work:
-->

しかし借用チェッカは、配列やスライスについてはどんな状況でも理解しないため、
このコードは動きません。

```rust,ignore
let mut x = [1, 2, 3];
let a = &mut x[0];
let b = &mut x[1];
println!("{} {}", a, b);
```

```text
<anon>:4:14: 4:18 error: cannot borrow `x[..]` as mutable more than once at a time
(エラー: 一度に `x[..]` を可変として 2 回以上借用することはできません)
<anon>:4 let b = &mut x[1];
                      ^~~~
<anon>:3:14: 3:18 note: previous borrow of `x[..]` occurs here; the mutable borrow prevents subsequent moves, borrows, or modification of `x[..]` until the borrow ends
(注釈: 以前の `x[..]` の借用はここで起きています。可変での借用は、その借用が終わるまで、その後のムーブや、借用、 `x[..]` の変更を防ぎます)
<anon>:3 let a = &mut x[0];
                      ^~~~
<anon>:6:2: 6:2 note: previous borrow ends here
(注釈: 以前の借用はここで終了しています)
<anon>:1 fn main() {
<anon>:2 let mut x = [1, 2, 3];
<anon>:3 let a = &mut x[0];
<anon>:4 let b = &mut x[1];
<anon>:5 println!("{} {}", a, b);
<anon>:6 }
         ^
error: aborting due to 2 previous errors
(エラー: 上記の 2 つのエラーのため中止)
```

<!--
While it was plausible that borrowck could understand this simple case, it's
pretty clearly hopeless for borrowck to understand disjointness in general
container types like a tree, especially if distinct keys actually *do* map
to the same value.
-->

仮に借用チェッカがこの単純なケースを理解しても合理的に見えただろう一方、
特に、異なるキーが本当に*本当に*同じ値にマップされているときなど、
木のような一般的なコンテナ内の、各値の素集合性を借用チェッカが理解することを望むのは、
明らかに無駄です。

<!--
In order to "teach" borrowck that what we're doing is ok, we need to drop down
to unsafe code. For instance, mutable slices expose a `split_at_mut` function
that consumes the slice and returns two mutable slices. One for everything to
the left of the index, and one for everything to the right. Intuitively we know
this is safe because the slices don't overlap, and therefore alias. However
the implementation requires some unsafety:
-->

借用チェッカに我々が行なっていることが問題ないと "教える" ためには、
アンセーフなコードに落とす必要があります。例えば、可変なスライスには、
スライスを消費し 2 つの可変なスライスを返す `split_at_mut` 関数を使用します。
片方のスライスはインデックスの左側全てを、もう片方のスライスはインデックスの右側全てを
使用するためのものです。直感的に、これは安全と分かります。互いのスライスが重ならなず、それゆえ
これらのスライスは元のスライスのエイリアスとなるからです。
しかし、その実装には少しアンセーフなコードを必要とします。

```rust,ignore
fn split_at_mut(&mut self, mid: usize) -> (&mut [T], &mut [T]) {
    let len = self.len();
    let ptr = self.as_mut_ptr();
    assert!(mid <= len);
    unsafe {
        (from_raw_parts_mut(ptr, mid),
         from_raw_parts_mut(ptr.offset(mid as isize), len - mid))
    }
}
```

<!--
This is actually a bit subtle. So as to avoid ever making two `&mut`'s to the
same value, we explicitly construct brand-new slices through raw pointers.
-->

これは実際、ちょっと細かくて難しいです。 同じ値に対する 2 つの `&mut` を生成するのを
常に避けるため、生ポインタを通じて明確に完全に新しいスライスを構築します。

<!--
However more subtle is how iterators that yield mutable references work.
The iterator trait is defined as follows:
-->

しかし、もっと細かくて難しいのは、可変参照を生成するイテレータが
どのように動作するかについてです。イテレータのトレイトは以下のように定義されます。

```rust
trait Iterator {
    type Item;

    fn next(&mut self) -> Option<Self::Item>;
}
```

<!--
Given this definition, Self::Item has *no* connection to `self`. This means that
we can call `next` several times in a row, and hold onto all the results
*concurrently*. This is perfectly fine for by-value iterators, which have
exactly these semantics. It's also actually fine for shared references, as they
admit arbitrarily many references to the same thing (although the iterator needs
to be a separate object from the thing being shared).
-->

上記の定義によれば、 Self::Item は `self` と何のつながりも持ち*ません*。
これは、 `next` を続けて何回か呼ぶことができ、そしてそれらに対する全ての結果を
*同時に*保持することができることを意味します。これは値渡しのイテレータに対しては
全く問題ありません。値渡しのイテレータも全く同じセマンティクスを持つからです。
そして、共有参照に対しても問題ありません。これらも同じものに対する任意の数の
参照を認めているからです (イテレータは共有されるオブジェクトと分離されている必要がありますが) 。

<!--
But mutable references make this a mess. At first glance, they might seem
completely incompatible with this API, as it would produce multiple mutable
references to the same object!
-->

しかし、可変参照はこれをごちゃごちゃにします。ひと目見ただけでも、可変参照は
この API に全く対応できないように見えるかもしれません。この API が同じオブジェクトに対する
複数の可変参照を生成するからです!

However it actually *does* work, exactly because iterators are one-shot objects.
Everything an IterMut yields will be yielded at most once, so we don't
actually ever yield multiple mutable references to the same piece of data.

Perhaps surprisingly, mutable iterators don't require unsafe code to be
implemented for many types!

For instance here's a singly linked list:

```rust
# fn main() {}
type Link<T> = Option<Box<Node<T>>>;

struct Node<T> {
    elem: T,
    next: Link<T>,
}

pub struct LinkedList<T> {
    head: Link<T>,
}

pub struct IterMut<'a, T: 'a>(Option<&'a mut Node<T>>);

impl<T> LinkedList<T> {
    fn iter_mut(&mut self) -> IterMut<T> {
        IterMut(self.head.as_mut().map(|node| &mut **node))
    }
}

impl<'a, T> Iterator for IterMut<'a, T> {
    type Item = &'a mut T;

    fn next(&mut self) -> Option<Self::Item> {
        self.0.take().map(|node| {
            self.0 = node.next.as_mut().map(|node| &mut **node);
            &mut node.elem
        })
    }
}
```

Here's a mutable slice:

```rust
# fn main() {}
use std::mem;

pub struct IterMut<'a, T: 'a>(&'a mut[T]);

impl<'a, T> Iterator for IterMut<'a, T> {
    type Item = &'a mut T;

    fn next(&mut self) -> Option<Self::Item> {
        let slice = mem::replace(&mut self.0, &mut []);
        if slice.is_empty() { return None; }

        let (l, r) = slice.split_at_mut(1);
        self.0 = r;
        l.get_mut(0)
    }
}

impl<'a, T> DoubleEndedIterator for IterMut<'a, T> {
    fn next_back(&mut self) -> Option<Self::Item> {
        let slice = mem::replace(&mut self.0, &mut []);
        if slice.is_empty() { return None; }

        let new_len = slice.len() - 1;
        let (l, r) = slice.split_at_mut(new_len);
        self.0 = l;
        r.get_mut(0)
    }
}
```

And here's a binary tree:

```rust
# fn main() {}
use std::collections::VecDeque;

type Link<T> = Option<Box<Node<T>>>;

struct Node<T> {
    elem: T,
    left: Link<T>,
    right: Link<T>,
}

pub struct Tree<T> {
    root: Link<T>,
}

struct NodeIterMut<'a, T: 'a> {
    elem: Option<&'a mut T>,
    left: Option<&'a mut Node<T>>,
    right: Option<&'a mut Node<T>>,
}

enum State<'a, T: 'a> {
    Elem(&'a mut T),
    Node(&'a mut Node<T>),
}

pub struct IterMut<'a, T: 'a>(VecDeque<NodeIterMut<'a, T>>);

impl<T> Tree<T> {
    pub fn iter_mut(&mut self) -> IterMut<T> {
        let mut deque = VecDeque::new();
        self.root.as_mut().map(|root| deque.push_front(root.iter_mut()));
        IterMut(deque)
    }
}

impl<T> Node<T> {
    pub fn iter_mut(&mut self) -> NodeIterMut<T> {
        NodeIterMut {
            elem: Some(&mut self.elem),
            left: self.left.as_mut().map(|node| &mut **node),
            right: self.right.as_mut().map(|node| &mut **node),
        }
    }
}


impl<'a, T> Iterator for NodeIterMut<'a, T> {
    type Item = State<'a, T>;

    fn next(&mut self) -> Option<Self::Item> {
        match self.left.take() {
            Some(node) => Some(State::Node(node)),
            None => match self.elem.take() {
                Some(elem) => Some(State::Elem(elem)),
                None => match self.right.take() {
                    Some(node) => Some(State::Node(node)),
                    None => None,
                }
            }
        }
    }
}

impl<'a, T> DoubleEndedIterator for NodeIterMut<'a, T> {
    fn next_back(&mut self) -> Option<Self::Item> {
        match self.right.take() {
            Some(node) => Some(State::Node(node)),
            None => match self.elem.take() {
                Some(elem) => Some(State::Elem(elem)),
                None => match self.left.take() {
                    Some(node) => Some(State::Node(node)),
                    None => None,
                }
            }
        }
    }
}

impl<'a, T> Iterator for IterMut<'a, T> {
    type Item = &'a mut T;
    fn next(&mut self) -> Option<Self::Item> {
        loop {
            match self.0.front_mut().and_then(|node_it| node_it.next()) {
                Some(State::Elem(elem)) => return Some(elem),
                Some(State::Node(node)) => self.0.push_front(node.iter_mut()),
                None => if let None = self.0.pop_front() { return None },
            }
        }
    }
}

impl<'a, T> DoubleEndedIterator for IterMut<'a, T> {
    fn next_back(&mut self) -> Option<Self::Item> {
        loop {
            match self.0.back_mut().and_then(|node_it| node_it.next_back()) {
                Some(State::Elem(elem)) => return Some(elem),
                Some(State::Node(node)) => self.0.push_back(node.iter_mut()),
                None => if let None = self.0.pop_back() { return None },
            }
        }
    }
}
```

All of these are completely safe and work on stable Rust! This ultimately
falls out of the simple struct case we saw before: Rust understands that you
can safely split a mutable reference into subfields. We can then encode
permanently consuming a reference via Options (or in the case of slices,
replacing with an empty slice).
