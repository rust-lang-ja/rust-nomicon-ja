<!--
# Type Conversions
-->

# 型変換

<!--
At the end of the day, everything is just a pile of bits somewhere, and type
systems are just there to help us use those bits right. There are two common
problems with typing bits: needing to reinterpret those exact bits as a
different type, and needing to change the bits to have equivalent meaning for
a different type. Because Rust encourages encoding important properties in the
type system, these problems are incredibly pervasive. As such, Rust
consequently gives you several ways to solve them.
-->

結局の所、全ては単に、どこかにあるビットの山なだけであり、型システムはただただ
これらのビットを正しく扱えるように手助けするためにあるのです。ビットを型付けするのには、 2 つの
問題があります。すなわち、ビットを異なる型として解釈する必要性と、同じ意味を異なる型で持たせるために
ビットを変更する必要性です。 Rust は型システム内の重要な特性をエンコードすることを奨励しているため、
これらの問題は信じられないほど蔓延しています。ですから、 Rust では結果的に、
これらの問題を解決する複数の方法があります。

First we'll look at the ways that Safe Rust gives you to reinterpret values.
The most trivial way to do this is to just destructure a value into its
constituent parts and then build a new type out of them. e.g.

```rust
struct Foo {
    x: u32,
    y: u16,
}

struct Bar {
    a: u32,
    b: u16,
}

fn reinterpret(foo: Foo) -> Bar {
    let Foo { x, y } = foo;
    Bar { a: x, b: y }
}
```

But this is, at best, annoying. For common conversions, Rust provides
more ergonomic alternatives.

