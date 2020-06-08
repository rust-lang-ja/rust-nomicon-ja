<!--
# Limits of Lifetimes
-->

# ライフタイムシステムの限界

<!--
Given the following code:
-->

次のコードを見てみましょう。

```rust,ignore
struct Foo;

impl Foo {
    fn mutate_and_share(&mut self) -> &Self { &*self }
    fn share(&self) {}
}

fn main() {
    let mut foo = Foo;
    let loan = foo.mutate_and_share();
    foo.share();
}
```

<!--
One might expect it to compile. We call `mutate_and_share`, which mutably borrows
`foo` temporarily, but then returns only a shared reference. Therefore we
would expect `foo.share()` to succeed as `foo` shouldn't be mutably borrowed.
-->

このコードはコンパイルを通ると思うかもしれません。
`mutate_and_share` は、`foo` を一時的に変更可能に借用しますが、
共有参照を返します。
そうすると、`foo` は変更可能には借用されていないので、
`foo.share()` は成功すると思うでしょう。

<!--
However when we try to compile it:
-->

ところが、このコードをコンパイルすると・・・。

```text
<anon>:11:5: 11:8 error: cannot borrow `foo` as immutable because it is also borrowed as mutable
(エラー: `foo`は可変で借用されているので、不変で借用できません)
<anon>:11     foo.share();
              ^~~
<anon>:10:16: 10:19 note: previous borrow of `foo` occurs here; the mutable borrow prevents subsequent moves, borrows, or modification of `foo` until the borrow ends
(注釈: 以前の`foo`の借用はここで起きています。可変での借用は、その借用が終わるまで、その後のムーブや、借用、`foo`の変更を防ぎます)
<anon>:10     let loan = foo.mutate_and_share();
                         ^~~
<anon>:12:2: 12:2 note: previous borrow ends here
(注釈: 以前の借用はここで終了しています)
<anon>:8 fn main() {
<anon>:9     let mut foo = Foo;
<anon>:10     let loan = foo.mutate_and_share();
<anon>:11     foo.share();
<anon>:12 }
          ^
```

<!--
What happened? Well, we got the exact same reasoning as we did for
[Example 2 in the previous section][ex2]. We desugar the program and we get
the following:
-->

何が起こったのでしょう?
[前の節の 2 つ目のサンプル][ex2]と全く同じ推論を行ったのです。
このコードを脱糖すると、次のようになります。

```rust,ignore
struct Foo;

impl Foo {
    fn mutate_and_share<'a>(&'a mut self) -> &'a Self { &'a *self }
    fn share<'a>(&'a self) {}
}

fn main() {
	'b: {
    	let mut foo: Foo = Foo;
    	'c: {
    		let loan: &'c Foo = Foo::mutate_and_share::<'c>(&'c mut foo);
    		'd: {
    			Foo::share::<'d>(&'d foo);
    		}
    	}
    }
}
```

<!--
The lifetime system is forced to extend the `&mut foo` to have lifetime `'c`,
due to the lifetime of `loan` and mutate_and_share's signature. Then when we
try to call `share`, and it sees we're trying to alias that `&'c mut foo` and
blows up in our face!
-->

`loan` のライフタイムと mutate_and_share のシグネチャとのため、
`&mut foo` のライフタイムは `'c` に延長されなくてはなりません。
そして、`share` を呼ぼうとするとき、`&'c mut foo` の別名を取ろうとすると認識され、大失敗に終わるのです。

<!--
This program is clearly correct according to the reference semantics we actually
care about, but the lifetime system is too coarse-grained to handle that.
-->

このプログラムは、私たちにとって重要な参照の意味的には全く正しいのですが、
ライフタイムシステムはこのプログラムを処理するには粗すぎるのです。

<!--
TODO: other common problems? SEME regions stuff, mostly?
-->

TODO: その他のよくある問題は? 主に SEME 領域とか?


[ex2]: lifetimes.html#例可変リファレンスの別名付け
