<!-- The Rustonomicon -->

# Rust 裏本

<!-- The Dark Arts of Advanced and Unsafe Rust Programming -->

#### 高度で危険な Rust Programming のための闇の技法

<!-- NOTE: This is a draft document, and may contain serious errors -->

# NOTE: この文書はドラフトです。重大な間違いを含んでいるかもしれません。

<!--
Instead of the programs I had hoped for, there came only a shuddering blackness and ineffable loneliness; and I saw at last a fearful truth which no one had ever dared to breathe before — the unwhisperable secret of secrets — The fact that this language of stone and stridor is not a sentient perpetuation of Rust as London is of Old London and Paris of Old Paris, but that it is in fact quite unsafe, its sprawling body imperfectly embalmed and infested with queer animate things which have nothing to do with it as it was in compilation.
-->

> 私に与えられたのは、望んだようなプログラムではなく、身を震わせるような暗黒と言い表せないような孤独であった。そして私はついに、誰ひとり口にしようともしなかった恐ろしい真実、ささやくことすらできない神秘中の神秘を目にしたのだ。石のように硬く、耳障りな音をたてるこの言語は、ロンドンが古きロンドンではなく、パリが古きパリではないように、Rust の御代をとこしえにするものではなく、実はきわめて危険で、不完全に防腐処理された、だらしなく寝そべった死体だったのだ。そこにはコンパイル時に生まれた奇妙な生き物たちが所在なさげに蔓延っていた。
>
> （訳注: H.P. ラヴクラフトの小説「[あの男][he]」のパロディのようです。）

<!--
This book digs into all the awful details that are necessary to understand in order to write correct Unsafe Rust programs. Due to the nature of this problem, it may lead to unleashing untold horrors that shatter your psyche into a billion infinitesimal fragments of despair.
-->

この本は、危険な Rust プログラムを正しく書くために理解しなくてはいけない、不愉快な詳細について詳しく見ていきます。このような性質上、この文書は今まで語られることのなかった恐怖を解き放ち、あなたの精神を何十億もの絶望のかけらに砕いてしまうかもしれません。

<!--
Should you wish a long and happy career of writing Rust programs, you should turn back now and forget you ever saw this book. It is not necessary. However if you intend to write unsafe code -- or just want to dig into the guts of the language -- this book contains invaluable information.
-->

もし貴方が Rust とともに長く幸せな人生を歩みたいと望むなら、今すぐに背を向けて、この本を見てしまったことを忘れるのです。貴方には必要ないのですから。しかし、危険なコードを書く意思がもしも貴方にあるのなら、もしくはこの言語の最重要部にただ踏み込んでみたいのなら、この本は代えがたい情報をもたらすでしょう。

<!--
Unlike [The Book][trpl] we will be assuming considerable prior knowledge. In
particular, you should be comfortable with basic systems programming and Rust.
If you don't feel comfortable with these topics, you should consider [reading
The Book][trpl] first. Though we will not be assuming that you have, and will
take care to occasionally give a refresher on the basics where appropriate. You
can skip straight to this book if you want; just know that we won't be
explaining everything from the ground up.
-->

[The Book][trpl] とは異なり、ここでは多くの事前知識を前提としています。特に基本的なシステムプログラミングと Rust に精通していなくてはなりません。もし貴方がそうでないなら、まず [The Book を読む][trpl] べきでしょう。とはいえ、The Book は前提ではありませんし、適切な場面で基本知識を復習する機会を与えます。The Book を飛ばしてこの本を読んでも構いませんが、すべてが基礎から説明されるわけではないことを覚えておいてください。

<!--
To be clear, this book goes into deep detail. We're going to dig into
exception-safety, pointer aliasing, memory models, and even some type-theory.
We will also be spending a lot of time talking about the different kinds
of safety and guarantees.
-->

はっきり言いますが、この本は詳細について深く説明します。例外の安全性、ポインタエイリアシング、メモリモデル、そして型理論についても少し。また、様々な種類の安全性や保証についてもたくさん説明します。


> 訳注: 原文は[こちら][nomicon-en]、日本語の翻訳文書は[こちら][bookja]です。


[trpl]: https://doc.rust-lang.org/book/
[he]: http://quotes.yourdictionary.com/author/h-p-lovecraft/172934
[nomicon-en]: https://doc.rust-lang.org/nomicon/index.html
[bookja]: https://github.com/rust-lang-ja/rust-nomicon-ja
