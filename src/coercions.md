<!--
# Coercions
-->

# 型強制

<!--
Types can implicitly be coerced to change in certain contexts. These changes are
generally just *weakening* of types, largely focused around pointers and
lifetimes. They mostly exist to make Rust "just work" in more cases, and are
largely harmless.
-->

特定の状況では、暗黙に型変換を強制することが出来ます。これらの変換は、一般には
単に型を*弱く*していて、主にポインタやライフタイム周りに着目されます。
これらはほとんどが、より多くのケースで Rust が "単に動く" ようにするために存在し、
そして大部分において、ほとんど害はありません。

<!--
Here's all the kinds of coercion:
-->

これらは全ての種類の型強制です:

<!--
Coercion is allowed between the following types:
-->

型強制は以下の型の間で認められています:

<!--
* Transitivity: `T_1` to `T_3` where `T_1` coerces to `T_2` and `T_2` coerces to
  `T_3`
* Pointer Weakening:
    * `&mut T` to `&T`
    * `*mut T` to `*const T`
    * `&T` to `*const T`
    * `&mut T` to `*mut T`
* Unsizing: `T` to `U` if `T` implements `CoerceUnsized<U>`
* Deref coercion: Expression `&x` of type `&T` to `&*x` of type `&U` if `T` derefs to `U` (i.e. `T: Deref<Target=U>`)
-->

* 推移性: `T_1` から `T_3` 但し `T_1` が `T_2` に型強制可能で、 `T_2` が `T_3` に型強制可能な場合
* ポインタの弱化:
    * `&mut T` から `&T`
    * `*mut T` から `*const T`
    * `&T` から `*const T`
    * `&mut T` から `*mut T`
* アンサイジング: `T` から `U` 但し `T` が `CoerceUnsized<U>` を実装している場合
* 参照外しの型強制: 型 `&T` の式 `&x` から型 `&U` の式 `&'x` 但し `T` が `U` に参照外しされる場合 (例: `T: Deref<Target=U>`)

<!--
`CoerceUnsized<Pointer<U>> for Pointer<T> where T: Unsize<U>` is implemented
for all pointer types (including smart pointers like Box and Rc). Unsize is
only implemented automatically, and enables the following transformations:
-->

`CoerceUnsized<Pointer<U>> for Pointer<T> where T: Unsize<U>` は
全てのポインタ型 (Box や Rc のようなスマートポインタを含む) で実装されています。
アンサイズは自動的にのみ実装され、以下の変換を有効にします。

<!--
* `[T; n]` => `[T]`
* `T` => `Trait` where `T: Trait`
* `Foo<..., T, ...>` => `Foo<..., U, ...>` where:
    * `T: Unsize<U>`
    * `Foo` is a struct
    * Only the last field of `Foo` has type involving `T`
    * `T` is not part of the type of any other fields
    * `Bar<T>: Unsize<Bar<U>>`, if the last field of `Foo` has type `Bar<T>`
-->

* `[T; n]` => `[T]`
* `T` => `Trait` 但し `T: Trait`
* `Foo<..., T, ...>` => `Foo<..., U, ...>` 但し
    * `T: Unsize<U>`
    * `Foo` は構造体
    * `Foo` の最後のフィールドだけが `T` を含む型である
    * `T` は他のフィールドの一部となっていない
    * `Bar<T>: Unsize<Bar<U>>` 但し `Foo` の最後のフィールドが `Bar<T>` の型である場合

<!--
Coercions occur at a *coercion site*. Any location that is explicitly typed
will cause a coercion to its type. If inference is necessary, the coercion will
not be performed. Exhaustively, the coercion sites for an expression `e` to
type `U` are:
-->

型強制は、*型強制サイト*で起こります。明確に型が指定されている全ての場所で、
その型への型強制が発生します。もし推論が必要ならば、型強制は行われません。
余すことなく言えば、式 `e` に対する型 `U` への型強制サイトは以下の通りです。

* let statements, statics, and consts: `let x: U = e`
* Arguments to functions: `takes_a_U(e)`
* Any expression that will be returned: `fn foo() -> U { e }`
* Struct literals: `Foo { some_u: e }`
* Array literals: `let x: [U; 10] = [e, ..]`
* Tuple literals: `let x: (U, ..) = (e, ..)`
* The last expression in a block: `let x: U = { ..; e }`

Note that we do not perform coercions when matching traits (except for
receivers, see below). If there is an impl for some type `U` and `T` coerces to
`U`, that does not constitute an implementation for `T`. For example, the
following will not type check, even though it is OK to coerce `t` to `&T` and
there is an impl for `&T`:

```rust,ignore
trait Trait {}

fn foo<X: Trait>(t: X) {}

impl<'a> Trait for &'a i32 {}


fn main() {
    let t: &mut i32 = &mut 0;
    foo(t);
}
```

```text
<anon>:10:5: 10:8 error: the trait bound `&mut i32 : Trait` is not satisfied [E0277]
<anon>:10     foo(t);
              ^~~
```
