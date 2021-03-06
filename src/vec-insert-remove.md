<!--
# Insert and Remove
-->

# 挿入と削除

<!--
Something *not* provided by slice is `insert` and `remove`, so let's do those
next.
-->

スライスから提供*されない*ものに、 `insert` と `remove` があります。
今度はこれらを実装していきましょう。

<!--
Insert needs to shift all the elements at the target index to the right by one.
To do this we need to use `ptr::copy`, which is our version of C's `memmove`.
This copies some chunk of memory from one location to another, correctly
handling the case where the source and destination overlap (which will
definitely happen here).
-->

挿入では、挿入位置から最後の要素まで、 1 ずつずらす必要があります。
これを行なうために、 `ptr::copy` を使う必要があります。 C の `memmove` の、
Rust 版のようなものです。これは、ある場所のメモリを別の場所にコピーします。
そして、2つの場所が重なっていても、正しくコピーされます (今回の場合、
明らかに重なります) 。

<!--
If we insert at index `i`, we want to shift the `[i .. len]` to `[i+1 .. len+1]`
using the old len.
-->

インデックス `i` の位置に挿入する場合、古い `len` の値を用いて、
`[i .. len]` を `[i+1 .. len+1]` にシフトします。

```rust,ignore
pub fn insert(&mut self, index: usize, elem: T) {
    // 注意: 全要素の後に挿入しても問題ないため、
    // `<=` としています。これは、プッシュと同等です。

    // 境界外インデックスです
    assert!(index <= self.len, "index out of bounds");
    if self.cap == self.len { self.grow(); }

    unsafe {
        if index < self.len {
            // ptr::copy(src, dest, len): "src から dest まで len 個の要素をコピー"
            ptr::copy(self.ptr.offset(index as isize),
                      self.ptr.offset(index as isize + 1),
                      self.len - index);
        }
        ptr::write(self.ptr.offset(index as isize), elem);
        self.len += 1;
    }
}
```

<!--
Remove behaves in the opposite manner. We need to shift all the elements from
`[i+1 .. len + 1]` to `[i .. len]` using the *new* len.
-->

削除では真逆の事を行ないます。*新しい* len を使用して、
`[i+1 .. len+1]` を `[i .. len]` にシフトします。

```rust,ignore
pub fn remove(&mut self, index: usize) -> T {
    // 注意: 全要素のあとの物を削除することは*有効ではない*ため、 '<' を使用します

    // 境界外インデックスです
    assert!(index < self.len, "index out of bounds");
    unsafe {
        self.len -= 1;
        let result = ptr::read(self.ptr.offset(index as isize));
        ptr::copy(self.ptr.offset(index as isize + 1),
                  self.ptr.offset(index as isize),
                  self.len - index);
        result
    }
}
```
