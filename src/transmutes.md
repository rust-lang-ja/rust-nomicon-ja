<!--
# Transmutes
-->

# トランスミュート

<!--
Get out of our way type system! We're going to reinterpret these bits or die
trying! Even though this book is all about doing things that are unsafe, I
really can't emphasize that you should deeply think about finding Another Way
than the operations covered in this section. This is really, truly, the most
horribly unsafe thing you can do in Rust. The railguards here are dental floss.
-->

型システムから抜け出しましょう! 何がなんでもビットを再解釈します! この本は
アンセーフなもの全てについて書かれていますが、この章でカバーされている操作を
やるよりも、他の方法を見つけるよう深刻に考えるべきだということは、
いくら強調しようとも、強調しきれません。これは本当に、マジで、 Rust で出来る
最も恐ろしいアンセーフなことです。ここではガードレールは爪楊枝のように脆いです。

<!--
`mem::transmute<T, U>` takes a value of type `T` and reinterprets it to have
type `U`. The only restriction is that the `T` and `U` are verified to have the
same size. The ways to cause Undefined Behavior with this are mind boggling.
-->

`mem::transmute<T, U>` は型 `T` の値を受け取り、その値が型 `U` であると再解釈します。
唯一の制約は、 `T` と `U` が同じサイズを持つとされていることです。
この操作によって未定義動作が起こる方法を考えると、気が遠くなります。

<!--
* First and foremost, creating an instance of *any* type with an invalid state
  is going to cause arbitrary chaos that can't really be predicted.
* Transmute has an overloaded return type. If you do not specify the return type
  it may produce a surprising type to satisfy inference.
* Making a primitive with an invalid value is UB
* Transmuting between non-repr(C) types is UB
* Transmuting an & to &mut is UB
    * Transmuting an & to &mut is *always* UB
    * No you can't do it
    * No you're not special
* Transmuting to a reference without an explicitly provided lifetime
  produces an [unbounded lifetime]
-->

* まず真っ先に、*いかなる*型においても、無効状態のインスタンスを作ることは、本当に予測不可能な混沌状態を引き起こすでしょう。
* transmute はオーバーロードされたリターン型を持ちます。もしリターン型を指定しなかった場合、
  推論を満たす、びっくりするような型を生成するかもしれません。
* 無効なプリミティブを生成することは未定義動作を引き起こします。
* repr(C) でない型の間でのトランスミュートは未定義動作を引き起こします。
* & から &mut へのトランスミュートは未定義動作を引き起こします。
    * & から &mut へのトランスミュートは*いつも*未定義動作を引き起こします。
    * いいえ、これは出来ません。
    * いいか、君は特別じゃないんだ。
* 明確にライフタイムが指定されていない参照へのトランスミュートは[無制限のライフタイム]を生成します。

<!--
`mem::transmute_copy<T, U>` somehow manages to be *even more* wildly unsafe than
this. It copies `size_of<U>` bytes out of an `&T` and interprets them as a `U`.
The size check that `mem::transmute` has is gone (as it may be valid to copy
out a prefix), though it is Undefined Behavior for `U` to be larger than `T`.
-->

`mem::transmute_copy<T, U>` は、どうにかして transmute よりも*本当に更に*アンセーフな事をしようとします。
この関数は `&T` から `size_of<U>` バイトコピーし、これらを `U` として解釈します。
もし `U` が `T` よりも大きい場合、未定義動作を引き起こしますが、 `mem::transmute` の
サイズチェックはなくなっています ( `T` の先頭部分をコピーすることが有効である場合があるためです) 。

<!--
Also of course you can get most of the functionality of these functions using
pointer casts.
-->

そしてもちろん、これらの関数の機能のほとんどを、ポインタのキャストを利用することで
得ることができます。


[無制限のライフタイム]: unbounded-lifetimes.html
