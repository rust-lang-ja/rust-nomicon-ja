<!--
# Lifetime Elision
-->

# 生存期間の省略

<!--
In order to make common patterns more ergonomic, Rust allows lifetimes to be
*elided* in function signatures.
-->

よくあるパターンをより易しく書けるように、Rust では関数シグネチャの生存期間を省略できます。

<!--
A *lifetime position* is anywhere you can write a lifetime in a type:
-->

*生存期間ポジション* とは、型の定義において生存期間を書ける場所のことです。

```rust,ignore
&'a T
&'a mut T
T<'a>
```

<!--
Lifetime positions can appear as either "input" or "output":
-->

生存期間ポジションは、「入力」か「出力」のいづれかです。

<!--
* For `fn` definitions, input refers to the types of the formal arguments
  in the `fn` definition, while output refers to
  result types. So `fn foo(s: &str) -> (&str, &str)` has elided one lifetime in
  input position and two lifetimes in output position.
  Note that the input positions of a `fn` method definition do not
  include the lifetimes that occur in the method's `impl` header
  (nor lifetimes that occur in the trait header, for a default method).
-->

* `fn` 定義では、入力とは仮引数の型のことで、出力とは結果の型のことです。
  `fn foo(s: *str) -> (&str, &str)` では、入力ポジションの生存期間が一つ省略され、
  出力ポジションの生存期間が二つ省略されています。
  `fn` メソッド定義の入力ポジションには、
  メソッドの `impl` ヘッダに現れる生存期間は含まれません。
  （デフォルトメソッドの場合の trait ヘッダに現れる生存期間も含まれません。）

<!--
* In the future, it should be possible to elide `impl` headers in the same manner.
-->

* 将来のバージョンでは、`impl` ヘッダの生存期間の省略も同様に可能になるでしょう。

<!--
Elision rules are as follows:
-->

省略のルールは次の通りです。

<!--
* Each elided lifetime in input position becomes a distinct lifetime
  parameter.
-->

* 入力ポジションの省略された生存期間は、それぞれ別の生存期間パラメタになります。

<!--
* If there is exactly one input lifetime position (elided or not), that lifetime
  is assigned to *all* elided output lifetimes.
-->

* 入力ポジションの生存期間（省略されているかどうかに関わらず）が一つしか無い場合、
  省略された出力生存期間全てにその生存期間が割り当てられます。

<!--
* If there are multiple input lifetime positions, but one of them is `&self` or
  `&mut self`, the lifetime of `self` is assigned to *all* elided output lifetimes.
-->

* 入力ポジションに複数の生存期間があって、そのうちの一つが `&self` または `&mut self` の場合、
  省略された出力生存期間全てに `self` の生存期間が割り当てられます。

<!--
* Otherwise, it is an error to elide an output lifetime.
-->

* それ以外の場合は、出力の生存期間を省略するとエラーになります。

<!--
Examples:
-->

例：

```rust,ignore
fn print(s: &str);                                      // 省略した場合
fn print<'a>(s: &'a str);                               // 展開した場合

fn debug(lvl: uint, s: &str);                           // 省略した場合
fn debug<'a>(lvl: uint, s: &'a str);                    // 展開した場合

fn substr(s: &str, until: uint) -> &str;                // 省略した場合
fn substr<'a>(s: &'a str, until: uint) -> &'a str;      // 展開した場合

fn get_str() -> &str;                                   // エラー

fn frob(s: &str, t: &str) -> &str;                      // エラー

fn get_mut(&mut self) -> &mut T;                        // 省略した場合
fn get_mut<'a>(&'a mut self) -> &'a mut T;              // 展開した場合

fn args<T: ToCStr>(&mut self, args: &[T]) -> &mut Command                  // 省略した場合
fn args<'a, 'b, T: ToCStr>(&'a mut self, args: &'b [T]) -> &'a mut Command // 展開した場合

fn new(buf: &mut [u8]) -> BufWriter;                    // 省略した場合
fn new<'a>(buf: &'a mut [u8]) -> BufWriter<'a>          // 展開した場合

```
