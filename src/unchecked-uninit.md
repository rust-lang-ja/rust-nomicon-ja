<!--
# Unchecked Uninitialized Memory
-->

# チェックされない初期化されていないメモリ

<!--
One interesting exception to this rule is working with arrays. Safe Rust doesn't
permit you to partially initialize an array. When you initialize an array, you
can either set every value to the same thing with `let x = [val; N]`, or you can
specify each member individually with `let x = [val1, val2, val3]`.
Unfortunately this is pretty rigid, especially if you need to initialize your
array in a more incremental or dynamic way.
-->

この規則の興味深い例外に、配列があります。安全な Rust は、配列を部分的に初期化することを
認めません。配列を初期化するとき、 `let x = [val; N]` を用いて、
全ての値を初期化するか、 `let x = [val1, val2, val3]` を用いて、
それぞれの要素の値を個別に指定することが出来ます。残念ながら、
特によりインクリメンタル的なやり方や、動的な方法で配列を初期化したい場合、
これは非常に融通が利きません。

<!--
Unsafe Rust gives us a powerful tool to handle this problem:
`mem::uninitialized`. This function pretends to return a value when really
it does nothing at all. Using it, we can convince Rust that we have initialized
a variable, allowing us to do trickier things with conditional and incremental
initialization.
-->

アンセーフな Rust では、この問題に対処するパワフルなツールが用意されています。 `mem::uninitialized` です。
この関数は本当に何もせず、値を返すふりをします。これを利用することで、 Rust に
変数が初期化されたと見なさせることができ、状況に応じた、インクリメンタル的な初期化を
行ないトリッキーなことが出来ます。

<!--
Unfortunately, this opens us up to all kinds of problems. Assignment has a
different meaning to Rust based on whether it believes that a variable is
initialized or not. If it's believed uninitialized, then Rust will semantically
just memcopy the bits over the uninitialized ones, and do nothing else. However
if Rust believes a value to be initialized, it will try to `Drop` the old value!
Since we've tricked Rust into believing that the value is initialized, we can no
longer safely use normal assignment.
-->

残念ながら、これによってあらゆる種類の問題が浮かび上がります。
変数が初期化されていると Rust が思っているか、思っていないかによって、
代入は異なる意味を持ちます。もし初期化していないと思っている場合、 Rust は、
セマンティクス的には単にビットを初期化していないメモリにコピーし、他には
何もしません。しかし、もし値が初期化していると思っている場合、 Rust は
古い値を `Drop` しようとします! Rust に、値が初期化されていると信じ込ませるよう
トリックをしたので、もはや安全には普通の代入は使えません。

<!--
This is also a problem if you're working with a raw system allocator, which
returns a pointer to uninitialized memory.
-->

生のシステムアロケータを使用している場合も問題となります。このアロケータは、
初期化されていないメモリへのポインタを返すからです。

<!--
To handle this, we must use the `ptr` module. In particular, it provides
three functions that allow us to assign bytes to a location in memory without
dropping the old value: `write`, `copy`, and `copy_nonoverlapping`.
-->

これに対処するには、 `ptr` モジュールを使用しなければなりません。
特にこのモジュールは、古い値をドロップせずに、メモリ上の場所に値を代入することが
可能となる 3 つの関数を提供しています: `write`、`copy`、`copy_nonoverlapping`です。

<!--
* `ptr::write(ptr, val)` takes a `val` and moves it into the address pointed
  to by `ptr`.
* `ptr::copy(src, dest, count)` copies the bits that `count` T's would occupy
  from src to dest. (this is equivalent to memmove -- note that the argument
  order is reversed!)
* `ptr::copy_nonoverlapping(src, dest, count)` does what `copy` does, but a
  little faster on the assumption that the two ranges of memory don't overlap.
  (this is equivalent to memcpy -- note that the argument order is reversed!)
-->

* `ptr::write(ptr, val)` は `val` を受け取り、 `ptr` が指し示すアドレスに受け取った値を
  移します。
* `ptr::copy(src, dest, count)` は、 T 型の `count` が占有するビット数だけ、 src から dest に
コピーします。 (これは memmove と同じです -- 引数の順序が逆転していることに注意してください!)
* `ptr::copy_nonoverlapping(src, dest, count)` は `copy` と同じことをしますが、 2 つのメモリ領域が
  重なっていないと見なしているため、若干高速です。 (これは memcpy と同じです -- 引数の
  順序が逆転していることに注意してください!)

<!--
It should go without saying that these functions, if misused, will cause serious
havoc or just straight up Undefined Behavior. The only things that these
functions *themselves* require is that the locations you want to read and write
are allocated. However the ways writing arbitrary bits to arbitrary
locations of memory can break things are basically uncountable!
-->

言うまでもないのですが、もしこれらの関数が誤用されると、甚大な被害を引き起こしたり、
未定義動作を引き起こすでしょう。これらの関数*自体*が必要とする唯一のものは、
読み書きしたい場所がアロケートされているということです。しかし、
任意のビットを任意のメモリの場所に書き込むことでものを壊すようなやり方は数え切れません!

<!--
Putting this all together, we get the following:
-->

これらを全部一緒にすると、以下のようなコードとなります。

```rust
use std::mem;
use std::ptr;

// size of the array is hard-coded but easy to change. This means we can't
// use [a, b, c] syntax to initialize the array, though!
const SIZE: usize = 10;

let mut x: [Box<u32>; SIZE];

unsafe {
	// convince Rust that x is Totally Initialized
	x = mem::uninitialized();
	for i in 0..SIZE {
		// very carefully overwrite each index without reading it
		// NOTE: exception safety is not a concern; Box can't panic
		ptr::write(&mut x[i], Box::new(i as u32));
	}
}

println!("{:?}", x);
```

It's worth noting that you don't need to worry about `ptr::write`-style
shenanigans with types which don't implement `Drop` or contain `Drop` types,
because Rust knows not to try to drop them. Similarly you should be able to
assign to fields of partially initialized structs directly if those fields don't
contain any `Drop` types.

However when working with uninitialized memory you need to be ever-vigilant for
Rust trying to drop values you make like this before they're fully initialized.
Every control path through that variable's scope must initialize the value
before it ends, if it has a destructor.
*[This includes code panicking](unwinding.html)*.

And that's about it for working with uninitialized memory! Basically nothing
anywhere expects to be handed uninitialized memory, so if you're going to pass
it around at all, be sure to be *really* careful.
