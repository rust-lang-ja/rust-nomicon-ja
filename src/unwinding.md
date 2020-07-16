<!--
# Unwinding
-->

# 巻き戻し

<!--
Rust has a *tiered* error-handling scheme:
-->
Rustのエラーハンドリングには**階層的な**スキームが存在します。

<!--
* If something might reasonably be absent, Option is used.
* If something goes wrong and can reasonably be handled, Result is used.
* If something goes wrong and cannot reasonably be handled, the thread panics.
* If something catastrophic happens, the program aborts.
-->
* もし何かが、明確な理由があって欠如しうる場合、Optionが使われます
* もし何かおかしなことが起こった際に合理的な対処方法がある場合、Resultが使われます
* もし何かおかしなことが起こった際に合理的な対処方法がない場合、そのスレッドはパニックします
* もし何か破滅的な出来事が起こった場合、プログラムはアボートします

<!--
Option and Result are overwhelmingly preferred in most situations, especially
since they can be promoted into a panic or abort at the API user's discretion.
Panics cause the thread to halt normal execution and unwind its stack, calling
destructors as if every function instantly returned.
-->
大抵の状況では圧倒的にOptionとResultが好まれます。というのもAPIのユーザーの
裁量次第でパニックやアボートさせることも可能だからです。パニックはスレッドの正常処理を
停止し、スタックを巻き戻し、全ての関数が即座にリターンしたかのようにデストラクタ
を呼び出します。

<!--
As of 1.0, Rust is of two minds when it comes to panics. In the long-long-ago,
Rust was much more like Erlang. Like Erlang, Rust had lightweight tasks,
and tasks were intended to kill themselves with a panic when they reached an
untenable state. Unlike an exception in Java or C++, a panic could not be
caught at any time. Panics could only be caught by the owner of the task, at which
point they had to be handled or *that* task would itself panic.
-->
バージョン1.0以降のRustはパニック時に２種類の対処法を用いるようになりました。
大昔、Rustは今よりもErlangによく似ていました。Erlangと同様、Rustには軽量のタスク
が存在し、タスクが続行不可能な状態に陥った際にはタスクが自分自身をパニックによって
killすることを意図して設計されていました。JavaやC++の例外と違い、パニックはいかなる
場合においても捕捉することはできませんでした。パニックを捕捉できるのはタスクの
オーナーのみであり、その時点で適切にハンドリングされるか、**その**タスク
(訳注: オーナーとなるタスク)自体がパニックするかのどちらかでした。

<!--
Unwinding was important to this story because if a task's
destructors weren't called, it would cause memory and other system resources to
leak. Since tasks were expected to die during normal execution, this would make
Rust very poor for long-running systems!
-->
この一連の流れの中では、タスクのデスクトラクタが呼ばれなかった場合にメモリ及び
その他のシステムリソースがリークを起こす可能性があったため、巻き戻しが重要でした。
タスクは通常の実行中にも死ぬ可能性があると想定されていたため、Rustのこういった
特徴は長期間実行されるシステムを作る上でとても不適切でした。

<!--
As the Rust we know today came to be, this style of programming grew out of
fashion in the push for less-and-less abstraction. Light-weight tasks were
killed in the name of heavy-weight OS threads. Still, on stable Rust as of 1.0
panics can only be caught by the parent thread. This means catching a panic
requires spinning up an entire OS thread! This unfortunately stands in conflict
to Rust's philosophy of zero-cost abstractions.
-->
Rustが現在の形に近づく過程で、より抽象化を少なくしたいという時流に押された
スタイルのプログラミングが確立していき、その過程で軽量のタスクは重量級の
OSスレッドに駆逐・統一されました
（訳注: いわゆるグリーンスレッドとネイティブスレッドの話）。しかしながら
Rust1.0の時点ではパニックはその親スレッドによってのみ補足が可能という仕様であった
ため、 パニックの補足時にOSのスレッドを丸ごと巻き戻してしまう必要
があったのです！不幸なことにこれはゼロコスト抽象化というRustの思想と
真っ向からぶつかってしまいました。

<!--
There is an unstable API called `catch_panic` that enables catching a panic
without spawning a thread. Still, we would encourage you to only do this
sparingly. In particular, Rust's current unwinding implementation is heavily
optimized for the "doesn't unwind" case. If a program doesn't unwind, there
should be no runtime cost for the program being *ready* to unwind. As a
consequence, actually unwinding will be more expensive than in e.g. Java.
Don't build your programs to unwind under normal circumstances. Ideally, you
should only panic for programming errors or *extreme* problems.
-->
一応 `catch_panic` というunstableなAPIが存在し、これによってスレッドをspawn
することなくパニックを捕捉することはできます。

> 訳注: その後 `recover` -> `catch_unwind` と変更され、Rust1.9でstableになりました。

とはいえあくまでこれは代替手段として用いることを推奨します。現在のRustの巻き戻し
は「巻き戻ししない」ケースに偏った最適化をしています。巻き戻しが発生しないとわかって
いれば、プログラムが巻き戻しの**準備**をするためのランタイムコストも無くなるためです。
結果として、実際にはJavaのような言語よりも巻き戻しのコストは高くなっています。
したがって通常の状況では巻き戻ししないようなプログラムの作成を心がけるべきです。
**非常に大きな**問題の発生時やプログラミングエラーに対してのみパニックすべきです。

<!--
Rust's unwinding strategy is not specified to be fundamentally compatible
with any other language's unwinding. As such, unwinding into Rust from another
language, or unwinding into another language from Rust is Undefined Behavior.
You must *absolutely* catch any panics at the FFI boundary! What you do at that
point is up to you, but *something* must be done. If you fail to do this,
at best, your application will crash and burn. At worst, your application *won't*
crash and burn, and will proceed with completely clobbered state.
-->
Rustの巻き戻しの取り扱い方針は、他の言語のそれと根本から同等になるように設計されて
はいません。したがって他の言語で発生した巻き戻しがRustに波及したり、逆にRustから
多言語に波及したりといった動作は未定義となっています。
FFIの構築時には**絶対に**全てのパニックを境界部でキャッチしなくてはなりません。
キャッチの結果どのように対処するかはプログラマ次第ですが、とにかく**何か**を
しなくてはなりません。そうしなければ、良くてアプリケーションがクラッシュ・炎上します。
最悪のケースではアプリケーションがクラッシュ・炎上**しません**。完全にボロボロの状態
のまま走り続けます。
