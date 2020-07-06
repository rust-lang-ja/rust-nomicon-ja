<!--
# Allocating Memory
-->

# メモリのアロケーティング

<!--
Using Unique throws a wrench in an important feature of Vec (and indeed all of
the std collections): an empty Vec doesn't actually allocate at all. So if we
can't allocate, but also can't put a null pointer in `ptr`, what do we do in
`Vec::new`? Well, we just put some other garbage in there!
-->

Unique を使用することで、 Vec の重要な機能に関して (そして実に std の全ての
コレクションにおいて) 問題が発生します。すなわち、空の Vec は実際に、
何もアロケートしていないのです。ですからもしアロケート出来ないだけではなく、
`ptr` にヌルポインタを代入出来ないとしたら、 `Vec::new` で何をすれば
いいのでしょうか? そうだ、単純にそこに何か他のゴミを突っ込みましょう!

<!--
This is perfectly fine because we already have `cap == 0` as our sentinel for no
allocation. We don't even need to handle it specially in almost any code because
we usually need to check if `cap > len` or `len > 0` anyway. The traditional
Rust value to put here is `0x01`. The standard library actually exposes this
as `alloc::heap::EMPTY`. There are quite a few places where we'll
want to use `heap::EMPTY` because there's no real allocation to talk about but
`null` would make the compiler do bad things.
-->

これは全く問題ありません。なぜなら、 `cap == 0` が既に、アロケーションが
ないことを示す番兵となっているからです。もはやこれを特別扱いする必要も
ありません。なぜならほとんどすべてのコードで、結局は `cap > len` か `len > 0` を
通常確かめる必要があるからです。伝統的に Rust では、 `0x01` を突っ込んでいます。
標準ライブラリでは実際にこれを `alloc::heap::EMPTY` として公開しています。
`null` を使ってしまうとコンパイラが悪さをしてしまうけれども、実際の
アロケーションが存在しないために `heap::EMPTY` を使用したい箇所がかなり
多く存在します。

<!--
All of the `heap` API is totally unstable under the `heap_api` feature, though.
We could trivially define `heap::EMPTY` ourselves, but we'll want the rest of
the `heap` API anyway, so let's just get that dependency over with.
-->

それでも全ての `heap` の API は、 `heap_api` フィーチャの下で、
全くアンステーブルです。自ら `heap::EMPTY` を定義してしまうことも
出来るでしょうが、結局 `heap` の他の API を使いたくなるため、単にその API を
依存関係に追加しましょう。

<!--
So:
-->

こうなります:

```rust,ignore
#![feature(alloc, heap_api)]

use std::mem;

use alloc::heap::EMPTY;

impl<T> Vec<T> {
    fn new() -> Self {
        // まだ ZST を扱う準備が出来ていません
        assert!(mem::size_of::<T>() != 0, "We're not ready to handle ZSTs");
        unsafe {
            // EMPTY を欲しい実際のポインタ型にキャストする必要があります。
            // 推論してもらいましょう。
            Vec { ptr: Unique::new(heap::EMPTY as *mut _), len: 0, cap: 0 }
        }
    }
}
```

<!--
I slipped in that assert there because zero-sized types will require some
special handling throughout our code, and I want to defer the issue for now.
Without this assert, some of our early drafts will do some Very Bad Things.
-->

コードの中に、assert を入れました。サイズが 0 の型は、コード全体において
何か特別な処理をする必要があり、この問題を今は後回しにしたいためです。
この assert がないと、コードの下書きにおいて、なにか非常にまずいことを
起こしてしまいます。

<!--
Next we need to figure out what to actually do when we *do* want space. For
that, we'll need to use the rest of the heap APIs. These basically allow us to
talk directly to Rust's allocator (jemalloc by default).
-->

次に、*本当に*スペースがほしいときに、実際に何をすればいいかを考える
必要があります。そのためには、 heap の他の API を使用する必要があります。
基本的にこれらによって、 Rust のアロケータ (デフォルトでは jemalloc) と
対話できるようになります。

<!--
We'll also need a way to handle out-of-memory (OOM) conditions. The standard
library calls the `abort` intrinsic, which just calls an illegal instruction to
crash the whole program. The reason we abort and don't panic is because
unwinding can cause allocations to happen, and that seems like a bad thing to do
when your allocator just came back with "hey I don't have any more memory".
-->

また、メモリ不足 (out-of-memory, OOM) の状態に対処する方法も必要です。
標準ライブラリでは、単に `abort` intrinsic を呼びます。これは単純に
不正な命令を呼び出して、プログラムをクラッシュさせます。なぜパニックではなく
アボートさせるかというと、巻き戻しによってアロケーションが起こり、
そしてアロケータが "なあ、もうメモリがないぜ" と戻ってきてしまうことで、
何か悪い事をしてしまうからです。

<!--
Of course, this is a bit silly since most platforms don't actually run out of
memory in a conventional way. Your operating system will probably kill the
application by another means if you legitimately start using up all the memory.
The most likely way we'll trigger OOM is by just asking for ludicrous quantities
of memory at once (e.g. half the theoretical address space). As such it's
*probably* fine to panic and nothing bad will happen. Still, we're trying to be
like the standard library as much as possible, so we'll just kill the whole
program.
-->

もちろん、通常ならほとんどのプラットフォームにおいて、実際にメモリ不足に
陥ることはないため、これはちょっと馬鹿げています。オペレーティングシステムは、
何らかの理由でアプリケーションが全てのメモリを使用しているなら、
そのアプリケーションを他の手段によって多分 kill するでしょう。
OOM になってしまう、もっともあり得る場合というのは単に、信じられないくらいの
メモリ量をいっぺんに確保しようとする場合です (例: 理論上のアドレス空間の半分) 。
ですからパニックしても*多分*問題なく、何も悪いことは起きません。それでも、
なるべく標準ライブラリに似せるため、ここでは単にプログラム全体を kill します。

<!--
We said we don't want to use intrinsics, so doing exactly what `std` does is
out. Instead, we'll call `std::process::exit` with some random number.
-->

intrinsic を使いたくないと述べました。ですので、 `std` で行なっていることと、
全く同じことをすることは出来ません。代わりに、 `std::process::exit` を
適当な値と共に呼び出します。

```rust
fn oom() {
    ::std::process::exit(-9999);
}
```

<!--
Okay, now we can write growing. Roughly, we want to have this logic:
-->

よし、これで Vec の伸長のコードを書くことが出来ます。欲しい
ロジックは大体以下のようなものです。

```text
if cap == 0:
    allocate()
    cap = 1
else:
    reallocate()
    cap *= 2
```

<!--
But Rust's only supported allocator API is so low level that we'll need to do a
fair bit of extra work. We also need to guard against some special
conditions that can occur with really large allocations or empty allocations.
-->

しかし、 Rust が唯一サポートしているアロケータ API は本当に低レベルな
ものですので、追加の作業がかなり必要です。また、本当に大きいアロケーションや、
空のアロケーションの際に起こる、特別な状況に対してガードする必要もあります。

<!--
In particular, `ptr::offset` will cause us a lot of trouble, because it has
the semantics of LLVM's GEP inbounds instruction. If you're fortunate enough to
not have dealt with this instruction, here's the basic story with GEP: alias
analysis, alias analysis, alias analysis. It's super important to an optimizing
compiler to be able to reason about data dependencies and aliasing.
-->

特に `ptr::offset` は、沢山の問題を引き起こします。なぜならこれは、 LLVM の、
GEP インバウンド命令のセマンティクスを持っているからです。もしあなたが
幸運にもこの命令に対処したことがない場合、こちらが GEP に関する
基本的な事柄です: エイリアス分析、エイリアス分析、エイリアス分析。
コンパイラが最適化をする際、データの依存関係や、エイリアシングを
推論できるということは、本当に重要なのです。

<!--
As a simple example, consider the following fragment of code:
-->

単純な例として、以下のコード片を考えてみましょう。

```rust
# let x = &mut 0;
# let y = &mut 0;
*x *= 7;
*y *= 3;
```

<!--
If the compiler can prove that `x` and `y` point to different locations in
memory, the two operations can in theory be executed in parallel (by e.g.
loading them into different registers and working on them independently).
However the compiler can't do this in general because if x and y point to
the same location in memory, the operations need to be done to the same value,
and they can't just be merged afterwards.
-->

もしコンパイラが、 `x` と `y` がメモリ上の別の場所をそれぞれ指していると
証明できるのなら、理論的には、これらの 2 つの命令は並列に行なうことが
可能です (例: 異なるレジスタにロードして、個別に操作する) 。
しかしながら、コンパイラは一般的にこれをすることが出来ません。
なぜなら、 `x` と `y` がメモリ上の同一の場所を指しているのなら、操作を
同じ値に対して行なわなければならず、単に最後、統合することは不可能だからです。

<!--
When you use GEP inbounds, you are specifically telling LLVM that the offsets
you're about to do are within the bounds of a single "allocated" entity. The
ultimate payoff being that LLVM can assume that if two pointers are known to
point to two disjoint objects, all the offsets of those pointers are *also*
known to not alias (because you won't just end up in some random place in
memory). LLVM is heavily optimized to work with GEP offsets, and inbounds
offsets are the best of all, so it's important that we use them as much as
possible.
-->

GEP インバウンドを使用する際、実行しようとしているオフセットは、
単一の "アロケートされた" エンティティの境界内に収まると、 LLVM に
事細かく伝えることになります。 LLVM を使うことによる、究極の利点は、
2 つのポインタが異なるオブジェクトを指すと分かっている時、これらの
ポインタの全てのオフセット*も*、エイリアスではないということが
分かるということです (なぜならメモリ上のどこかランダムな場所を
指さないと分かっているからです) 。 LLVM は、 GEP オフセットを
扱うために激しく最適化されていて、インバウンドオフセットは
全ての中で最良のものです。ですからなるべくこれらを使うことが重要です。

<!--
So that's what GEP's about, how can it cause us trouble?
-->

これが、 GEP についてです。ではこれが、どのような問題を引き起こすのでしょうか?

<!--
The first problem is that we index into arrays with unsigned integers, but
GEP (and as a consequence `ptr::offset`) takes a signed integer. This means
that half of the seemingly valid indices into an array will overflow GEP and
actually go in the wrong direction! As such we must limit all allocations to
`isize::MAX` elements. This actually means we only need to worry about
byte-sized objects, because e.g. `> isize::MAX` `u16`s will truly exhaust all of
the system's memory. However in order to avoid subtle corner cases where someone
reinterprets some array of `< isize::MAX` objects as bytes, std limits all
allocations to `isize::MAX` bytes.
-->

第一に、配列のインデックス指定では符号なし整数を指定しますが、
GEP (そして結果として `ptr::offset` も) では符号付き整数を受け取ります。
これはつまり、配列のインデックス指定では有効であろう値の半分が、 GEP では
オーバーフローしてしまい、実際に間違った方向に進んでしまうのです! ですから
全てのアロケーションを `isize::MAX` 個の要素に制限しなければなりません。
これは実際には、バイトサイズのオブジェクトに関してのみ、心配する必要があります。
なぜなら、例えば `isize::MAX` 個以上の `u16` などでは、明らかにシステムのメモリを
使い果たしてしまうでしょう。しかし、何らかの配列を `isize::MAX` 個以下のバイトオブジェクトと
再解釈するような、微妙なコーナーケースを避けるため、 std では全てのアロケーションを
`isize::MAX` バイトに制限しています。

<!--
On all 64-bit targets that Rust currently supports we're artificially limited
to significantly less than all 64 bits of the address space (modern x64
platforms only expose 48-bit addressing), so we can rely on just running out of
memory first. However on 32-bit targets, particularly those with extensions to
use more of the address space (PAE x86 or x32), it's theoretically possible to
successfully allocate more than `isize::MAX` bytes of memory.
-->

Rust が現在サポートしている 64 ビットのターゲットでは、 恣意的に、 64 ビットの
アドレス空間全体よりも遥かに少なく制限されています (現代の x64 プラットフォームでは、
48 ビットのアドレスしか公開されていません) 。ですから単純に、最初にメモリ不足に
なると考えて良いです。しかし 32 ビットのターゲットでは、特に追加のアドレス空間
を使用する拡張に対して (PAE x86 や x32) 、理論的には `isize::MAX` バイト以上の
メモリをアロケートしてしまうことが可能です。

<!--
However since this is a tutorial, we're not going to be particularly optimal
here, and just unconditionally check, rather than use clever platform-specific
`cfg`s.
-->

しかしながら、これはチュートリアルですので、ここではベストを尽くしません。
単に、プラットフォーム特有の `cfg` 等を使用するのではなく、状況に関わりなく
チェックします。

<!--
The other corner-case we need to worry about is empty allocations. There will
be two kinds of empty allocations we need to worry about: `cap = 0` for all T,
and `cap > 0` for zero-sized types.
-->

心配しなければならない他のコーナーケースは、空のアロケーションです。
空のアロケーションには 2 種類あります。 全ての T における `cap = 0` と、
サイズが 0 の型における `cap > 0` です。

<!--
These cases are tricky because they come
down to what LLVM means by "allocated". LLVM's notion of an
allocation is significantly more abstract than how we usually use it. Because
LLVM needs to work with different languages' semantics and custom allocators,
it can't really intimately understand allocation. Instead, the main idea behind
allocation is "doesn't overlap with other stuff". That is, heap allocations,
stack allocations, and globals don't randomly overlap. Yep, it's about alias
analysis. As such, Rust can technically play a bit fast and loose with the notion of
an allocation as long as it's *consistent*.
-->

これらは結局、 LLVM が意味する "アロケートされた" 状態ですので、扱いにくいです。
LLVM におけるアロケーションの概念は、我々が普段使う概念よりも遥かに抽象的です。
LLVM は異なる言語のセマンティクスや、カスタムアロケータを扱う必要があるため、
アロケーションに深入り出来ないのです。その代わり、アロケーションの
背後にある主要な考えは "他のものと重ならない" という事です。つまり、
ヒープアロケーションやスタックアロケーション、そしてグローバルな
アロケーションは、ランダムに重なることはありません。ええ、これはエイリアス分析
についてです。ですから、 Rust は*一貫性*を保つ限り、アロケーションの概念に関しては
技術的に、ちょっと高速に、ちょっと緩く、行なうことが出来ます。

<!--
Getting back to the empty allocation case, there are a couple of places where
we want to offset by 0 as a consequence of generic code. The question is then:
is it consistent to do so? For zero-sized types, we have concluded that it is
indeed consistent to do a GEP inbounds offset by an arbitrary number of
elements. This is a runtime no-op because every element takes up no space,
and it's fine to pretend that there's infinite zero-sized types allocated
at `0x01`. No allocator will ever allocate that address, because they won't
allocate `0x00` and they generally allocate to some minimal alignment higher
than a byte. Also generally the whole first page of memory is
protected from being allocated anyway (a whole 4k, on many platforms).
-->

空のアロケーションの場合について戻りましょう。ジェネリックなコードの結果、 0 の
オフセットが欲しい場合がいくつかあります。そうすると問題はこうなります。すなわち、
これを行なうことは、一貫性があるのでしょうか? 例えばサイズが 0 の型の場合、
任意の要素数による GEP インバウンドオフセットを行なうことは、実に一貫性が
あると結論付けました。これは実行時には no-op です。なぜなら、全ての要素は
スペースを消費せず、そして `0x01` に無限の数の、サイズが 0 の型がアロケート
されているとしても問題ないからです。どのアロケータも、常にそのアドレスには
アロケートしません。なぜなら、アロケータは `0x00` にはアロケートせず、
一般的にバイト以上のある最小のアラインメントにアロケートするからです。
また一般的には、メモリの最初のページ全体は、アロケートされることに対し
結局保護されています (多くのプロットフォームでは 4k 全体) 。

<!--
However what about for positive-sized types? That one's a bit trickier. In
principle, you can argue that offsetting by 0 gives LLVM no information: either
there's an element before the address or after it, but it can't know which.
However we've chosen to conservatively assume that it may do bad things. As
such we will guard against this case explicitly.
-->

しかしながら、サイズが正の型についてはどうでしょうか? これはちょっと
トリッキーです。一般には、 0 のオフセットでは LLVM には何の情報も
行き渡らないと論ずる事が出来ます。すなわち、アドレスの前か後ろかの
どちらかに要素があるけれども、どっちなのかはわからないということです。
しかし、これによって悪いことが起きると保守的に見なすことを選びました。
ですからこれらの場合に対しては、明示的にガードします。

<!--
*Phew*
-->

*ふー*

Ok with all the nonsense out of the way, let's actually allocate some memory:

```rust,ignore
fn grow(&mut self) {
    // this is all pretty delicate, so let's say it's all unsafe
    unsafe {
        // current API requires us to specify size and alignment manually.
        let align = mem::align_of::<T>();
        let elem_size = mem::size_of::<T>();

        let (new_cap, ptr) = if self.cap == 0 {
            let ptr = heap::allocate(elem_size, align);
            (1, ptr)
        } else {
            // as an invariant, we can assume that `self.cap < isize::MAX`,
            // so this doesn't need to be checked.
            let new_cap = self.cap * 2;
            // Similarly this can't overflow due to previously allocating this
            let old_num_bytes = self.cap * elem_size;

            // check that the new allocation doesn't exceed `isize::MAX` at all
            // regardless of the actual size of the capacity. This combines the
            // `new_cap <= isize::MAX` and `new_num_bytes <= usize::MAX` checks
            // we need to make. We lose the ability to allocate e.g. 2/3rds of
            // the address space with a single Vec of i16's on 32-bit though.
            // Alas, poor Yorick -- I knew him, Horatio.
            assert!(old_num_bytes <= (::std::isize::MAX as usize) / 2,
                    "capacity overflow");

            let new_num_bytes = old_num_bytes * 2;
            let ptr = heap::reallocate(*self.ptr as *mut _,
                                        old_num_bytes,
                                        new_num_bytes,
                                        align);
            (new_cap, ptr)
        };

        // If allocate or reallocate fail, we'll get `null` back
        if ptr.is_null() { oom(); }

        self.ptr = Unique::new(ptr as *mut _);
        self.cap = new_cap;
    }
}
```

Nothing particularly tricky here. Just computing sizes and alignments and doing
some careful multiplication checks.

