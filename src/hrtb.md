<!--
# Higher-Rank Trait Bounds (HRTBs)
-->

# 高階トレイト境界

<!--
Rust's `Fn` traits are a little bit magic. For instance, we can write the
following code:
-->

Rust の `Fn` トレイトはちょっとした魔法です。例えば、次のように書くことができます。

```rust
struct Closure<F> {
    data: (u8, u16),
    func: F,
}

impl<F> Closure<F>
    where F: Fn(&(u8, u16)) -> &u8,
{
    fn call(&self) -> &u8 {
        (self.func)(&self.data)
    }
}

fn do_it(data: &(u8, u16)) -> &u8 { &data.0 }

fn main() {
    let clo = Closure { data: (0, 1), func: do_it };
    println!("{}", clo.call());
}
```

<!--
If we try to naively desugar this code in the same way that we did in the
lifetimes section, we run into some trouble:
-->

ライフタイムの節と同じように単純に脱糖しようとすると、問題が起こります。

```rust,ignore
struct Closure<F> {
    data: (u8, u16),
    func: F,
}

impl<F> Closure<F>
    // where F: Fn(&'??? (u8, u16)) -> &'??? u8,
{
    fn call<'a>(&'a self) -> &'a u8 {
        (self.func)(&self.data)
    }
}

fn do_it<'b>(data: &'b (u8, u16)) -> &'b u8 { &'b data.0 }

fn main() {
    'x: {
        let clo = Closure { data: (0, 1), func: do_it };
        println!("{}", clo.call());
    }
}
```

<!--
How on earth are we supposed to express the lifetimes on `F`'s trait bound? We
need to provide some lifetime there, but the lifetime we care about can't be
named until we enter the body of `call`! Also, that isn't some fixed lifetime;
`call` works with *any* lifetime `&self` happens to have at that point.
-->

`F` のトレイト境界は、一体どうすれば表現できるのでしょう?
なんらかのライフタイムを提供する必要がありますが、問題のライフタイムは `call` 関数が呼ばれるまで名前が無いのです。さらに、ライフタイムは固定されていません。
`&self` に*どんな*ライフタイムが割り当てられても、`call` は動作します。

<!--
This job requires The Magic of Higher-Rank Trait Bounds (HRTBs). The way we
desugar this is as follows:
-->

この問題は、高階トレイト境界（HRTB: Higher-Rank Trait Bounds）という魔法で解決できます。
HRTB を使うとつぎのように脱糖できます。

```rust,ignore
where for<'a> F: Fn(&'a (u8, u16)) -> &'a u8,
```

<!--
(Where `Fn(a, b, c) -> d` is itself just sugar for the unstable *real* `Fn`
trait)
-->

（`Fn(a, b, c) -> d` 自体が、まだ仕様が安定していない*本当の* `Fn` トレイトの糖衣構文です。）

<!--
`for<'a>` can be read as "for all choices of `'a`", and basically produces an
*infinite list* of trait bounds that F must satisfy. Intense. There aren't many
places outside of the `Fn` traits where we encounter HRTBs, and even for
those we have a nice magic sugar for the common cases.
-->

`for<'a>` は、「`'a` に何を選んだとしても」という意味で、つまり F が満たさなくてはならないトレイト境界の*無限リスト*を生成します。強烈でしょう?
`Fn` トレイトを除けば、HRTB が使われる場所はほとんどありません。`Fn` トレイトにおいても、ほとんどの場合は魔法の糖衣構文が良いされています。
