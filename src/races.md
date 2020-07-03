<!--
# Data Races and Race Conditions
-->

# データ競合と競合状態

<!--
Safe Rust guarantees an absence of data races, which are defined as:
-->

安全な Rust では、データ競合が存在しないことが保証されています。
データ競合は、以下のように定義されています。

<!--
* two or more threads concurrently accessing a location of memory
* one of them is a write
* one of them is unsynchronized
-->

* 2 以上のスレッドが並行にメモリ上の場所にアクセスしている
* この内 1 つは書き込み
* この内 1 つは非同期

<!--
A data race has Undefined Behavior, and is therefore impossible to perform
in Safe Rust. Data races are *mostly* prevented through rust's ownership system:
it's impossible to alias a mutable reference, so it's impossible to perform a
data race. Interior mutability makes this more complicated, which is largely why
we have the Send and Sync traits (see below).
-->

データ競合は未定義動作を含み、そしてそれ故に安全な Rust で発生させることは不可能です。
データ競合は Rust の所有権システムによって*ほとんど*防がれています。可変参照の
エイリアスを生成することは不可能ですから、データ競合を起こすことは不可能です。
内部可変性はこれをもっと複雑にします。これが、 Send トレイトと Sync トレイトが
何故存在するかということの主な理由です (以下を見てください) 。

<!--
**However Rust does not prevent general race conditions.**
-->

**しかしながら Rust は、一般的な競合状態を防ぎません。**

<!--
This is pretty fundamentally impossible, and probably honestly undesirable. Your
hardware is racy, your OS is racy, the other programs on your computer are racy,
and the world this all runs in is racy. Any system that could genuinely claim to
prevent *all* race conditions would be pretty awful to use, if not just
incorrect.
-->

これは根本的に不可能で、そして多分本当に望まれていないものです。ハードウェアは
競合状態を起こし、 OS は競合状態を起こし、コンピュータの他のプログラムも競合状態を起こし、
そして世界中にある全てのプログラムは競合状態を起こします。どんなシステムでも、
*全ての*競合状態を防げると喧伝しているようなものは、本当に使いづらいものとなるでしょう。
たとえ正しいものだとしても。

<!--
So it's perfectly "fine" for a Safe Rust program to get deadlocked or do
something nonsensical with incorrect synchronization. Obviously such a program
isn't very good, but Rust can only hold your hand so far. Still, a race
condition can't violate memory safety in a Rust program on its own. Only in
conjunction with some other unsafe code can a race condition actually violate
memory safety. For instance:
-->

ですから、安全な Rust のプログラムがデッドロックに陥ったり、正しくない同期によって何か
馬鹿げたことを行なっても、これは全く "問題ない" のです。明らかにそのようなプログラムは
本当に良くないです。ですが、 Rust は今までのところ、プログラマに我慢してもらうしか出来ないのです。
それでも Rust のプログラムだけでは、競合状態において、メモリ安全性を侵害することは出来ません。
何か他のアンセーフなコードと組み合わせることだけでしか、実際に競合状態において、
メモリ安全性を侵害することが出来ないのです。例:

```rust,no_run
use std::thread;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

let data = vec![1, 2, 3, 4];
// Arc にすることで、 他のスレッドより前に完全に実行が終了しても、 AtomicUsize が
// 保存されているメモリが、他のスレッドがインクリメントするために存在し続けます。
// これ無しにはコンパイルできません。なぜなら、 thread::spawn が
// ライフタイムを必要とするからです!
let idx = Arc::new(AtomicUsize::new(0));
let other_idx = idx.clone();

// `move` によって other_idx が値でキャプチャされ、このスレッドにムーブされます
thread::spawn(move || {
    // idx を変更しても大丈夫です。この値はアトミックだからです。
    // ですからデータ競合は起こりません。
    other_idx.fetch_add(10, Ordering::SeqCst);
});

// アトミックなものからロードした値を使用してインデックス指定をします。これは安全です。
// なぜなら、アトミックメモリから読み込み、その値のコピーを Vec のインデックス実装に
// 渡すからです。このインデックス指定では、正しく境界チェックが行なわれ、そして途中で
// 値が変わることはありません。しかし、もしスポーンされたスレッドが、なんとかして実行前に
// インクリメントするならば、このプログラムはパニックするかもしれません。
// 正しいプログラムの実行 (パニックすることはほとんど正しくありません) は、スレッドの
// 実行順序に依存するため、競合状態となります。
println!("{}", data[idx.load(Ordering::SeqCst)]);
```

```rust,no_run
use std::thread;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;

let data = vec![1, 2, 3, 4];

let idx = Arc::new(AtomicUsize::new(0));
let other_idx = idx.clone();

// `move` によって other_idx が値でキャプチャされ、このスレッドにムーブされます
thread::spawn(move || {
    // idx を変更しても大丈夫です。この値はアトミックだからです。
    // ですからデータ競合起こりません。
    other_idx.fetch_add(10, Ordering::SeqCst);
});

if idx.load(Ordering::SeqCst) < data.len() {
    unsafe {
        // 境界チェックを行なった後、間違えて idx をロードしてしまいます。
        // この値は変わってしまったかもしれません。これは競合状態で、*危険*です。
        // なぜなら `unsafe` である `get_unchecked` を行なったからです。
        println!("{}", data.get_unchecked(idx.load(Ordering::SeqCst)));
    }
}
```
