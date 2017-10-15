<!-- # The Perils Of Ownership Based Resource Management (OBRM) -->
# 所有権に基づいたリソース管理(Ownership Based Resource Management, OBRM)の危険性について

<!--
OBRM (AKA RAII: Resource Acquisition Is Initialization) is something you'll
interact with a lot in Rust. Especially if you use the standard library.
-->
OBRM(またの名をRAII: Resource Acquisition Is Initialization)とは、Rustにおいて
関連性の深い概念です。特に標準ライブラリと密接に関与します。

<!--
Roughly speaking the pattern is as follows: to acquire a resource, you create an
object that manages it. To release the resource, you simply destroy the object,
and it cleans up the resource for you. The most common "resource" this pattern
manages is simply *memory*. `Box`, `Rc`, and basically everything in
`std::collections` is a convenience to enable correctly managing memory. This is
particularly important in Rust because we have no pervasive GC to rely on for
memory management. Which is the point, really: Rust is about control. However we
are not limited to just memory. Pretty much every other system resource like a
thread, file, or socket is exposed through this kind of API.
-->
このパターンを簡単に説明すると以下のようになります。リソースの獲得時に
操作の対象となるオブジェクトの初期化を行い、リソースの解放時には単にその
オブジェクトを破棄すればあとはリソースのクリーンアップを勝手に行ってくれる、
いうものです。ここでいう「リソース」とは単に**メモリ**のことです。`Box`、`Rc`、
その他`std::collections`の諸々全ては、メモリの管理を便利にするためのものです。
Rustの場合、メモリの管理において一貫したGCに頼るということができないので、これら
は特に重要になります。大事なことなので強調しましょう。この「管理」という考え方は
Rustの根幹です。それは何もメモリに限った話ではありません。スレッド、ファイル、
ソケットといったほぼ全てのリソースがこういった考え方に基づくAPIを通して扱うように
できています。
