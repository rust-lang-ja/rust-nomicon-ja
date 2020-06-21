<!--
# Working With Uninitialized Memory
-->

# 初期化されないメモリを扱う

<!--
All runtime-allocated memory in a Rust program begins its life as
*uninitialized*. In this state the value of the memory is an indeterminate pile
of bits that may or may not even reflect a valid state for the type that is
supposed to inhabit that location of memory. Attempting to interpret this memory
as a value of *any* type will cause Undefined Behavior. Do Not Do This.
-->

すべての Rust の、実行時にアロケートされるメモリは、最初に*初期化されません*。
この状態では、メモリ上の値は、そのメモリ番地にあると想定される型の、正しい状態を
反映しているかもしれないし、していないかもしれないビットの無限の山です。
このメモリを*いかなる*型の値として解釈しようとしても、未定義動作を引き起こすでしょう。
絶対にしないでください。

Rust provides mechanisms to work with uninitialized memory in checked (safe) and
unchecked (unsafe) ways.
