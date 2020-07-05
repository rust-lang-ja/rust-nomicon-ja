<!--
# Example: Implementing Vec
-->

# 例: Vec の実装

<!--
To bring everything together, we're going to write `std::Vec` from scratch.
Because all the best tools for writing unsafe code are unstable, this
project will only work on nightly (as of Rust 1.9.0). With the exception of the
allocator API, much of the unstable code we'll use is expected to be stabilized
in a similar form as it is today.
-->

全てをまとめるために、最初から `std::Vec` を書くことにします。
アンセーフなコードを書くための最良のツールは全部アンステーブルなため、
このプロジェクトは nightly でしか動作しません (Rust 1.9.0 現在) 。
アロケータの API を除いて、使用するアンステーブルなもののほとんどは、
今日の形態に似た状態で、安定版となると予測しています。

<!--
However we will generally try to avoid unstable code where possible. In
particular we won't use any intrinsics that could make a code a little
bit nicer or efficient because intrinsics are permanently unstable. Although
many intrinsics *do* become stabilized elsewhere (`std::ptr` and `std::mem`
consist of many intrinsics).
-->

しかし、なるべくアンステーブルなコードを書くことを避けようと思います。
特に、いかなる intrinsic は使わないことにします。これらはコードを
ちょっと改善したり、効率を良くします。これらを使わない理由は、
intrinsic が永遠にアンステーブルだからです。もっとも、多くの intrinsic は*実際に*
別の場において安定版になっていますが (`std::ptr` や `std::mem` は、
多くの intrinsic を含んでいます) 。

Ultimately this means our implementation may not take advantage of all
possible optimizations, though it will be by no means *naive*. We will
definitely get into the weeds over nitty-gritty details, even
when the problem doesn't *really* merit it.

You wanted advanced. We're gonna go advanced.
