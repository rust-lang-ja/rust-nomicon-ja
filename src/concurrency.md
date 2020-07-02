<!--
# Concurrency and Parallelism
-->

# 並行性と並列性

<!--
Rust as a language doesn't *really* have an opinion on how to do concurrency or
parallelism. The standard library exposes OS threads and blocking sys-calls
because everyone has those, and they're uniform enough that you can provide
an abstraction over them in a relatively uncontroversial way. Message passing,
green threads, and async APIs are all diverse enough that any abstraction over
them tends to involve trade-offs that we weren't willing to commit to for 1.0.
-->

言語としての Rust には、*本当に*、どのように並行性や並列性を実現するかについての
信条がありません。標準ライブラリは、 OS のスレッドやシステムコールのブロックを
公開しています。なぜなら皆これらを持っていて、そして十分統一されているために、
比較的反論の起きないような、これらに対する抽象化を提供できるからです。メッセージパッシング、
グリーンスレッド、そして async の API はすべて、本当に異なっているため、
これらに対するいかなる抽象化においても、バージョン 1.0 に対するコミットを
行ないたくないようなトレードオフを巻き込む傾向にあります。

<!--
However the way Rust models concurrency makes it relatively easy to design your own
concurrency paradigm as a library and have everyone else's code Just Work
with yours. Just require the right lifetimes and Send and Sync where appropriate
and you're off to the races. Or rather, off to the... not... having... races.
-->

しかしながら、 Rust の並行性のモデルは比較的簡単に、ライブラリとして、自分自身の並行パラダイムを
設計することができ、そして、自分のコードと同じように、他の人のコードもちゃんと動かすことも出来ます。
必要なのは正しいライフタイムと、必要に応じて Send と Sync で、これですぐ書くことが出来ます。
あるいは... 競合を... 起こさずに... 済みます。
