<!--
# Poisoning
-->

# ポイゾニング

<!--
Although all unsafe code *must* ensure it has minimal exception safety, not all
types ensure *maximal* exception safety. Even if the type does, your code may
ascribe additional meaning to it. For instance, an integer is certainly
exception-safe, but has no semantics on its own. It's possible that code that
panics could fail to correctly update the integer, producing an inconsistent
program state.
-->
全てのアンセーフな型は最低限の例外安全性を満たしていることが**必要です**が、全ての
アンセーフな型が**最大限**の例外安全性を満たしている必要はありません。
仮に型自体が満たしていたとしても、実装が別の意味を暗黙に付与してしまう場合も
あります。例えば整数型は間違いなく例外安全ですが、その(訳注: 最大限の例外安全性
を担保する)セマンティクスを独自に持つわけではないため、整数をアップデートする
際にパニックを起こすと、プログラムが一貫性のない状態に陥る可能性があります。

<!--
This is *usually* fine, because anything that witnesses an exception is about
to get destroyed. For instance, if you send a Vec to another thread and that
thread panics, it doesn't matter if the Vec is in a weird state. It will be
dropped and go away forever. However some types are especially good at smuggling
values across the panic boundary.
-->
これは**通常は**問題になることはありません。というのも例外を発見した処理は直後に
死ぬためです。例えばVecを別のスレッドに送り、そのスレッドがパニックし、結果として
Vecが奇妙な状態に陥ったとしても、ドロップされて永久に闇の彼方に葬られてしまうためです。
とはいえ型によってはパニックの境界をまたいでくる場合もあります。

<!--
These types may choose to explicitly *poison* themselves if they witness a panic.
Poisoning doesn't entail anything in particular. Generally it just means
preventing normal usage from proceeding. The most notable example of this is the
standard library's Mutex type. A Mutex will poison itself if one of its
MutexGuards (the thing it returns when a lock is obtained) is dropped during a
panic. Any future attempts to lock the Mutex will return an `Err` or panic.
-->
こういった型は、パニックに直面した際に、意図的に自分自身を**ポイゾン**する可能性があり
ます。ポイゾニング自体は特に何か別の事態を引き起こすわけではありません。一般的に
通常の手続きの継続を止めるべきであることを表しています。よく知られた例として
標準ライブラリのMutex型があります。この型は対応するMutexGuards(lockを取得した際に
返るもの)が、panicによってdropされた際に自分自身をpoisonします。以後Mutexをlock
しようとすると`Err`を返すかpanicします。

<!--
Mutex poisons not for true safety in the sense that Rust normally cares about. It
poisons as a safety-guard against blindly using the data that comes out of a Mutex
that has witnessed a panic while locked. The data in such a Mutex was likely in the
middle of being modified, and as such may be in an inconsistent or incomplete state.
It is important to note that one cannot violate memory safety with such a type
if it is correctly written. After all, it must be minimally exception-safe!
-->
Mutexのpoisonは、通常の文脈で語られるRustの安全性とは異なる用途のためのものです。
Mutexを扱うスレッドがlock中にパニックを引き起こした場合、Mutexの中のデータは変更中
であった可能性が高く、一貫性を欠いていたり変更が未完了の状態であったりするため、
そのようなデータを盲目的に扱う危険性に対する安全装置として動作します。
注意しておきたいのはそのような型が適切に実装されていた場合、メモリ安全性**は**確実
に満たしているという点です。つまるところ、最低限の例外安全性は満たしていなくては
ならないということです。

<!--
However if the Mutex contained, say, a BinaryHeap that does not actually have the
heap property, it's unlikely that any code that uses it will do
what the author intended. As such, the program should not proceed normally.
Still, if you're double-plus-sure that you can do *something* with the value,
the Mutex exposes a method to get the lock anyway. It *is* safe, after all.
Just maybe nonsense.
-->
しかしながら、Mutexが例えばBinaryHeapを持っていたとして、その値が実際にはヒープ
として要件を満たさなかったような場合、そのデータ構造を利用するプログラムが作成者の
意図通りの挙動をするということは考えにくいです。通常とは異なる振る舞いをする
でしょう。とはいえ、十分に注意すればそのような場合でもその値が**何かに**使える
可能性はあります。safe**では**あるのです。ただ、ナンセンスかもしれませんが。
