<!--
# Drop Flags
-->

# ドロップフラグ

<!--
The examples in the previous section introduce an interesting problem for Rust.
We have seen that it's possible to conditionally initialize, deinitialize, and
reinitialize locations of memory totally safely. For Copy types, this isn't
particularly notable since they're just a random pile of bits. However types
with destructors are a different story: Rust needs to know whether to call a
destructor whenever a variable is assigned to, or a variable goes out of scope.
How can it do this with conditional initialization?
-->

前章の例では、 Rust における興味深い問題を紹介しました。
状況によって、メモリの場所を初期化したり、初期化されていない状態に戻したり、
再初期化したりすることを、完全に安全に行なうことが可能だということを
確認してきました。 Copy を実装している型に関しては、メモリの場所にあるものは
単なるビットのランダムな山であるため、これは特に重要なことではありません。
しかし、デストラクタを備えている型に関しては話が違います。 Rust は変数が代入されたときや、
あるいは変数がスコープを外れたときは毎回、デストラクタを呼ぶかを知る必要があります。
これを、状況に応じた初期化と共に、どのように行えばよいのでしょうか?

<!--
Note that this is not a problem that all assignments need worry about. In
particular, assigning through a dereference unconditionally drops, and assigning
in a `let` unconditionally doesn't drop:
-->

全ての代入において心配する必要がある問題ではないことに注意してください。
特に、参照外しを通した代入では、状況によらずドロップしますし、 `let` を使用した
代入では、状況によらずドロップしません。

```
let mut x = Box::new(0); // let によって新しい変数が生成されるので、ドロップの必要はありません
let y = &mut x;
*y = Box::new(1); // 参照外しでは、参照される側の変数は初期化されていると見なされているため、この参照されている変数はいつもドロップします
```

<!--
This is only a problem when overwriting a previously initialized variable or
one of its subfields.
-->

これは、以前に初期化された変数や、その副フィールドの1つを上書きする時のみ問題となります。

<!--
It turns out that Rust actually tracks whether a type should be dropped or not
*at runtime*. As a variable becomes initialized and uninitialized, a *drop flag*
for that variable is toggled. When a variable might need to be dropped, this
flag is evaluated to determine if it should be dropped.
-->

実際には Rust は*実行時に*、型がドロップされるべきかそうでないかを追っていると分かります。
変数が初期化されたり、初期化されてない状態になったりすると、その変数に対する*ドロップフラグ*が
切り替わります。もし変数がドロップされる必要があるかもしれない状況になると、
本当にドロップされるべきかを決定するため、このフラグが評価されます。

<!--
Of course, it is often the case that a value's initialization state can be
statically known at every point in the program. If this is the case, then the
compiler can theoretically generate more efficient code! For instance, straight-
line code has such *static drop semantics*:
-->

勿論、しばしば値の初期化に関する状況は、プログラムのどの地点においても
知ることが出来ます。もしこれが本当なら、コンパイラは理論的には、
もっと効率的なコードを生成できます! 例えば、分岐のない真っ直ぐなコードは、
このような*静的ドロップセマンティクス*を持っています。

```rust
let mut x = Box::new(0); // x は初期化されていないので、単に上書きします。
let mut y = x;           // y は初期化されていないので、単に上書きします。そして x を初期化前の状態にします。
x = Box::new(0);         // x は初期化されていないので、単に上書きします。
y = x;                   // y は初期化されているので、 y をドロップし、上書きし、そして x を初期化前の状態にします!
                         // y はスコープを抜けました。 y は初期化されているので、 y をドロップします!
                         // x はスコープを抜けました。 x は初期化されていない状態なので、何もしません。
```

<!--
Similarly, branched code where all branches have the same behavior with respect
to initialization has static drop semantics:
-->

同じように、全ての分岐が初期化の点において、同一のことをする分岐があるコードでは、
静的ドロップセマンティクスを持っています。

```rust
# let condition = true;
let mut x = Box::new(0);    // x は初期化されていないので、単に上書きします。
if condition {
    drop(x)                 // x はムーブされたので、 x を初期化前の状態にします。
} else {
    println!("{}", x);
    drop(x)                 // x はムーブされたので、 x を初期化前の状態にします。
}
x = Box::new(0);            // x は初期化されていない状態なので、単に上書きします。
                            // x はスコープを抜けました。 x は初期化されているので、 x をドロップします!
```

<!--
However code like this *requires* runtime information to correctly Drop:
-->

しかしながらこのようなコードでは、正しくドロップするために実行時に情報が必要となります。

```rust
# let condition = true;
let x;
if condition {
    x = Box::new(0);        // x は初期化されていないので、単に上書きします。
    println!("{}", x);
}
                            // x はスコープを抜けました。 x は初期化されていないかもしれません。
                            // フラグを確認!
```

<!--
Of course, in this case it's trivial to retrieve static drop semantics:
-->

勿論この場合、静的ドロップセマンティクスを復活させるのは些細なことです。

```rust
# let condition = true;
if condition {
    let x = Box::new(0);
    println!("{}", x);
}
```

<!--
The drop flags are tracked on the stack and no longer stashed in types that
implement drop.
-->

ドロップフラグはスタック上で追跡され、ドロップを実装している型に
隠されることはもはやありません。
