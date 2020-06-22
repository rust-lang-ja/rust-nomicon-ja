<!--
# Checked Uninitialized Memory
-->

# チェックされる初期化されないメモリ

<!--
Like C, all stack variables in Rust are uninitialized until a value is
explicitly assigned to them. Unlike C, Rust statically prevents you from ever
reading them until you do:
-->

C のように、 Rust の全てのスタック上の変数は、値が明示的に代入されるまでは初期化されません。 C とは違い、 Rust では、
値が代入されるまで、初期化されていない変数を読み込もうとするのを静的に防ぎます。

```rust,ignore
fn main() {
    let x: i32;
    println!("{}", x);
}
```

```text
src/main.rs:3:20: 3:21 error: use of possibly uninitialized variable: `x`
(エラー: 初期化されていないかもしれない変数 `x` を使用しています)
src/main.rs:3     println!("{}", x);
                                 ^
```

<!--
This is based off of a basic branch analysis: every branch must assign a value
to `x` before it is first used. Interestingly, Rust doesn't require the variable
to be mutable to perform a delayed initialization if every branch assigns
exactly once. However the analysis does not take advantage of constant analysis
or anything like that. So this compiles:
-->

これは、基本的な分岐分析に基づいています。すなわち、全ての分岐は、 `x` が初めに
使用される前に、値を代入しなければなりません。興味深いことに、 Rust では、もし全ての分岐の中で
値がちょうど一回しか代入されない場合、遅延初期化を行なうために、変数をミュータブルにする必要がありません。
しかし、この分析は定数の分析や、それに似たものを利用していないため、このコードはコンパイルできます。

```rust
fn main() {
    let x: i32;

    if true {
        x = 1;
    } else {
        x = 2;
    }

    println!("{}", x);
}
```

<!--
but this doesn't:
-->

しかし、このコードはコンパイルできません。

```rust,ignore
fn main() {
    let x: i32;
    if true {
        x = 1;
    }
    println!("{}", x);
}
```

```text
src/main.rs:6:17: 6:18 error: use of possibly uninitialized variable: `x`
(エラー: 初期化されていないかもしれない変数 `x` を使用しています)
src/main.rs:6   println!("{}", x);
```

<!--
while this does:
-->

一方でこのコードはコンパイルできます。

```rust
fn main() {
    let x: i32;
    if true {
        x = 1;
        println!("{}", x);
    }
    // 初期化されない分岐があっても構いません。
    // 値をその分岐で使用しないからです。
}
```

<!--
Of course, while the analysis doesn't consider actual values, it does
have a relatively sophisticated understanding of dependencies and control
flow. For instance, this works:
-->

もちろん、分析では実際の値は考慮されませんが、比較的洗練された、依存関係や制御フローに関する
分析は行われます。例えば、このコードは動作します。

```rust
let x: i32;

loop {
    // Rust は、この分岐が状況によらず選択されることは理解しません。
    // なぜならこれは、実際の値に依存するためです。
    if true {
        // しかし Rust は、この分岐がたった一回しか選択されないと理解しています。
        // なぜなら、状況によらず、この分岐を抜け出すからです。
        // それゆえ、`x` はミュータブルとしてマークされる必要がないのです。
        x = 0;
        break;
    }
}
// Rust はまた、 break に到達せずに、ここに来ることが不可能だということを知っています。
// そしてそれゆえに、 `x` はこの場所に於いて初期化されなければならないと知っているのです!
println!("{}", x);
```

<!--
If a value is moved out of a variable, that variable becomes logically
uninitialized if the type of the value isn't Copy. That is:
-->

もし値の型が Copy を実装しておらず、値が変数からムーブされたら、
論理的にはその変数は初期化されていない事になります。

```rust
fn main() {
    let x = 0;
    let y = Box::new(0);
    let z1 = x; // i32 は Copy を実装しているため、 x はまだ有効です
    let z2 = y; // Box は Copy を実装していないため、もはや y は論理的には初期化されていません
}
```

<!--
However reassigning `y` in this example *would* require `y` to be marked as
mutable, as a Safe Rust program could observe that the value of `y` changed:
-->

しかしながらこの例では、 `y` に値を再代入しようとするのであれば、 `y` を
ミュータブルとしてマークする必要が*あるでしょう*。
安全な Rust のプログラムは `y` の値が変わったと認識出来るからです。

```rust
fn main() {
    let mut y = Box::new(0);
    let z = y; // y is now logically uninitialized because Box isn't Copy
    y = Box::new(1); // reinitialize y
}
```

Otherwise it's like `y` is a brand new variable.
