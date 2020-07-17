<!--
# Handling Zero-Sized Types
-->

# サイズが 0 の型を扱う

<!--
It's time. We're going to fight the specter that is zero-sized types. Safe Rust
*never* needs to care about this, but Vec is very intensive on raw pointers and
raw allocations, which are exactly the two things that care about
zero-sized types. We need to be careful of two things:
-->

時間です。サイズが 0 の型という怪物と戦いましょう。安全な Rust では*絶対に*
これを気にする必要はないのですが、 Vec は非常に生ポインタや生アロケーションを
多用します。これらはサイズが 0 の型を気にします。以下の 2 つを気にしなければ
なりません。

<!--
* The raw allocator API has undefined behavior if you pass in 0 for an
  allocation size.
* raw pointer offsets are no-ops for zero-sized types, which will break our
  C-style pointer iterator.
-->

* 生アロケータ API は、もしアロケーションのサイズとして 0 を渡すと、
  未定義動作を引き起こします。
* 生ポインタのオフセットは、サイズが 0 の型に対しては no-op となります。
  これによって C スタイルのポインタによるイテレータが壊れます。

<!--
Thankfully we abstracted out pointer-iterators and allocating handling into
RawValIter and RawVec respectively. How mysteriously convenient.
-->

ありがたいことに、ポインタのイテレータと、 RawValIter と RawVec に対する
アロケーションの扱いを抽出しました。なんと魔法のように役立つでしょう。




<!--
## Allocating Zero-Sized Types
-->

## サイズが 0 の型をアロケートする

<!--
So if the allocator API doesn't support zero-sized allocations, what on earth
do we store as our allocation? Why, `heap::EMPTY` of course! Almost every operation
with a ZST is a no-op since ZSTs have exactly one value, and therefore no state needs
to be considered to store or load them. This actually extends to `ptr::read` and
`ptr::write`: they won't actually look at the pointer at all. As such we never need
to change the pointer.
-->

では、アロケータの API がサイズ 0 の型のアロケーションに対応していないのならば、
一体全体何を、アロケーションとして保存すればいいのでしょうか? そうさ，勿論 `heap::EMPTY` さ!
ZST に対する操作は、 ZSTがちょうど 1 つの値を持つため、 ほとんど全てが no-op となります。
それゆえこの型の値を保存したりロードしたりする場合に、状態を考える必要がありません。
この考えは実際に `ptr::read` や `ptr::write` に拡張されます。つまり、これらの操作は、
実際には全くポインタに着目していないのです。ですからポインタを変える必要は全くないのです。

<!--
Note however that our previous reliance on running out of memory before overflow is
no longer valid with zero-sized types. We must explicitly guard against capacity
overflow for zero-sized types.
-->

ですが、サイズが 0 の型に対しては、オーバーフローの前にメモリ不足になる、という、
前述した前提は最早有効ではないということに注意してください。サイズが 0 の型に対しては、
キャパシティのオーバーフローに対して明示的にガードしなければなりません。

<!--
Due to our current architecture, all this means is writing 3 guards, one in each
method of RawVec.
-->

現在のアーキテクチャでは、これは 3 つのガードを書くということを意味します。
この内 1 つは RawVec の各メソッド内に書きます。

```rust,ignore
impl<T> RawVec<T> {
    fn new() -> Self {
        unsafe {
            // !0 は usize::MAX です。この分岐はコンパイル時に取り除かれるはずです。
            let cap = if mem::size_of::<T>() == 0 { !0 } else { 0 };

            // heap::EMPTY は "アロケートされていない" と "サイズが 0 の型のアロケーションの" の
            // 2 つの意味を持ちます。
            RawVec { ptr: Unique::new(heap::EMPTY as *mut T), cap: cap }
        }
    }

    fn grow(&mut self) {
        unsafe {
            let elem_size = mem::size_of::<T>();

            // elem_size が 0 の時にキャパシティを usize::MAX にしたので、
            // ここにたどり着いてしまうということは、 Vec が満杯であることを必然的に
            // 意味します。
            assert!(elem_size != 0, "capacity overflow");

            let align = mem::align_of::<T>();

            let (new_cap, ptr) = if self.cap == 0 {
                let ptr = heap::allocate(elem_size, align);
                (1, ptr)
            } else {
                let new_cap = 2 * self.cap;
                let ptr = heap::reallocate(*self.ptr as *mut _,
                                            self.cap * elem_size,
                                            new_cap * elem_size,
                                            align);
                (new_cap, ptr)
            };

            // もしアロケートや、リアロケートに失敗すると、 `null` が返ってきます
            if ptr.is_null() { oom() }

            self.ptr = Unique::new(ptr as *mut _);
            self.cap = new_cap;
        }
    }
}

impl<T> Drop for RawVec<T> {
    fn drop(&mut self) {
        let elem_size = mem::size_of::<T>();

        // サイズが 0 の型のアロケーションは解放しません。そもそもアロケートされていないからです。
        if self.cap != 0 && elem_size != 0 {
            let align = mem::align_of::<T>();

            let num_bytes = elem_size * self.cap;
            unsafe {
                heap::deallocate(*self.ptr as *mut _, num_bytes, align);
            }
        }
    }
}
```

<!--
That's it. We support pushing and popping zero-sized types now. Our iterators
(that aren't provided by slice Deref) are still busted, though.
-->

以上。これで、サイズが 0 の型に対するプッシュとポップがサポートされます。
それでもイテレータ (スライスの Deref から提供されていないもの) は
まだサポートされていないのですが。




<!--
## Iterating Zero-Sized Types
-->

## サイズが 0 の型のイテレーション

<!--
Zero-sized offsets are no-ops. This means that our current design will always
initialize `start` and `end` as the same value, and our iterators will yield
nothing. The current solution to this is to cast the pointers to integers,
increment, and then cast them back:
-->

サイズが 0 の型に対するオフセットは no-op です。つまり、現在の設計では `start` と `end` を
常に同じ値に初期化し、イテレータは何も値を返しません。これに対する今の所の解決策は、
ポインタを整数にキャストし、インクリメントした後に下に戻すという方法です。

```rust,ignore
impl<T> RawValIter<T> {
    unsafe fn new(slice: &[T]) -> Self {
        RawValIter {
            start: slice.as_ptr(),
            end: if mem::size_of::<T>() == 0 {
                ((slice.as_ptr() as usize) + slice.len()) as *const _
            } else if slice.len() == 0 {
                slice.as_ptr()
            } else {
                slice.as_ptr().offset(slice.len() as isize)
            }
        }
    }
}
```

<!--
Now we have a different bug. Instead of our iterators not running at all, our
iterators now run *forever*. We need to do the same trick in our iterator impls.
Also, our size_hint computation code will divide by 0 for ZSTs. Since we'll
basically be treating the two pointers as if they point to bytes, we'll just
map size 0 to divide by 1.
-->

さて、これにより別のバグが発生します。イテレータが全く動作しない代わりに、
このイテレータは*永遠に*動作してしまいます。同じトリックをイテレータの impl に
行なう必要があります。また、 size_hint の計算では、 ZST の場合 0 で割ることになります。
基本的に 2 つのポインタを、それらがバイトサイズの値を指しているとして扱っているため、
サイズが 0 の場合、 1 で割ります。

```rust,ignore
impl<T> Iterator for RawValIter<T> {
    type Item = T;
    fn next(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                let result = ptr::read(self.start);
                self.start = if mem::size_of::<T>() == 0 {
                    (self.start as usize + 1) as *const _
                } else {
                    self.start.offset(1)
                };
                Some(result)
            }
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let elem_size = mem::size_of::<T>();
        let len = (self.end as usize - self.start as usize)
                  / if elem_size == 0 { 1 } else { elem_size };
        (len, Some(len))
    }
}

impl<T> DoubleEndedIterator for RawValIter<T> {
    fn next_back(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                self.end = if mem::size_of::<T>() == 0 {
                    (self.end as usize - 1) as *const _
                } else {
                    self.end.offset(-1)
                };
                Some(ptr::read(self.end))
            }
        }
    }
}
```

And that's it. Iteration works!
