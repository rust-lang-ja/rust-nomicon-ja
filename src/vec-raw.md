# RawVec

<!--
We've actually reached an interesting situation here: we've duplicated the logic
for specifying a buffer and freeing its memory in Vec and IntoIter. Now that
we've implemented it and identified *actual* logic duplication, this is a good
time to perform some logic compression.
-->

興味深い状況に突入しました。すなわち、 Vec と IntoIter の、バッファの指定と
メモリの解放の論理が重複しているのです。これらを実装し、*実際に*ロジックが
重複していると特定したので、今がロジックを圧縮する丁度良い時です。

<!--
We're going to abstract out the `(ptr, cap)` pair and give them the logic for
allocating, growing, and freeing:
-->

`(ptr, cap)` のペアを取り除き、これにアロケート、伸長そして解放のロジックを
与えます。

```rust,ignore
struct RawVec<T> {
    ptr: Unique<T>,
    cap: usize,
}

impl<T> RawVec<T> {
    fn new() -> Self {
        assert!(mem::size_of::<T>() != 0, "TODO: implement ZST support");
        unsafe {
            RawVec { ptr: Unique::new(heap::EMPTY as *mut T), cap: 0 }
        }
    }

    // Vec の時と変更ありません
    fn grow(&mut self) {
        unsafe {
            let align = mem::align_of::<T>();
            let elem_size = mem::size_of::<T>();

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
        if self.cap != 0 {
            let align = mem::align_of::<T>();
            let elem_size = mem::size_of::<T>();
            let num_bytes = elem_size * self.cap;
            unsafe {
                heap::deallocate(*self.ptr as *mut _, num_bytes, align);
            }
        }
    }
}
```

<!--
And change Vec as follows:
-->

そして Vec を以下のように変更します。

```rust,ignore
pub struct Vec<T> {
    buf: RawVec<T>,
    len: usize,
}

impl<T> Vec<T> {
    fn ptr(&self) -> *mut T { *self.buf.ptr }

    fn cap(&self) -> usize { self.buf.cap }

    pub fn new() -> Self {
        Vec { buf: RawVec::new(), len: 0 }
    }

    // push/pop/insert/remove は以下以外の変更はありません。
    // * `self.ptr -> self.ptr()`
    // * `self.cap -> self.cap()`
    // * `self.grow -> self.buf.grow()`
}

impl<T> Drop for Vec<T> {
    fn drop(&mut self) {
        while let Some(_) = self.pop() {}
        // デアロケートは RawVec が対処します
    }
}
```

<!--
And finally we can really simplify IntoIter:
-->

最終的に、本当に IntoIter が単純になります。

```rust,ignore
struct IntoIter<T> {
    _buf: RawVec<T>, // これを扱うことはないのですが、その存在は必要です。
    start: *const T,
    end: *const T,
}

// next と next_back は buf を参照していないため、文字通り変更しません

impl<T> Drop for IntoIter<T> {
    fn drop(&mut self) {
        // 全ての要素が確実に読まれていることだけが必要です。
        // バッファは後で自身を片付けます。
        for _ in &mut *self {}
    }
}

impl<T> Vec<T> {
    pub fn into_iter(self) -> IntoIter<T> {
        unsafe {
            // buf をアンセーフに移動させるため、 ptr:read を必要とします。
            // buf は Copy を実装しておらず、 Vec は Drop を実装しているからです
            // (ですから Vec をデストラクト出来ません) 。
            let buf = ptr::read(&self.buf);
            let len = self.len;
            mem::forget(self);

            IntoIter {
                start: *buf.ptr,
                end: buf.ptr.offset(len as isize),
                _buf: buf,
            }
        }
    }
}
```

Much better.
