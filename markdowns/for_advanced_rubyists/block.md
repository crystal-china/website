## 代码块参数的自动展开(auto expanding)

下面的 Ruby 代码是工作的： 

```ruby
[[1, "A"], [2, "B"]].each do |a, b|
  p a, b
end

# 1
# "A"
# 2
# "B"
```

因为 Enumerable 对象的的元素（这里是一个子数组）作为参数传递给代码块时，会自动根据
代码块参数形参的个数 auto expanding，但是 Crystal 不会自动这样做（这也避免了一些潜在的 bug）


```sh
In 1.cr:1:27

 1 | [[1, "A"], [2, "B"]].each do |a, b|
                               ^
Error: too many block parameters (given 2, expected maximum 1)
```

错误消息告诉我们，期望的代码块参数个数是一个，但是我们提供了两个。

正确的做法是将所有参数使用圆括号括起来，其内部会执行 unpack： `a, b = [1, "A"]`

```crystal
[[1, "A"], [2, "B"]].each do |(a, b)|
  p a, b
end # => ok
```

嵌套的 unpacking 也是可以的。(since 1.10.0)

```crystal
ary = [
  {1, {2, {3, 4}}} # => A Tuple
]

ary.each do |(w, (x, (y, z)))|
  w # => 1

  x # => 2
  y # => 3
  z # => 4
end
```

Ruby 里的 Splat 参数也是支持的。

```crystal
ary = [
  [1, 2, 3, 4, 5],
]

ary.each do |(x, *y, z)|
  x # => 1
  y # => [2, 3, 4]
  z # => 5
end
```

不过，当 Hash 或 NamedTuple 作为可枚举对象传递**键值对**给代码块时，
是不需要 unpacking 直接可以工作的（也比较符合直觉）。


```crystal
{1 => "A",2 => "B"}.each do |a, b|
  p a, b
end

# 1
# "A"
# 2
# "B"
```

```crystal
{foo: 1, bar: 2}.each do |a, b|
  p a, b
end

# :foo
# 1
# :bar
# 2
```

## yield(non-captured block) 和 &block(captured block)

在较早版本的 Ruby 中，yield 比 &block 拥有稍微较好的性能，但功能通常不做明确的区分。
在最近版本的 Ruby 中, 两者性能已经没有什么性能差异了，但是如果你使用 Crystal, 必须
明白 yield 和 &block, 两者的实现方式有着根本性的不同。

当使用 yield 的时候，在方法体中，代码块并没有作为一个变量在方法内被引用，即，一定
无法将 block 作为方法返回值返回，我们称其为 non-captured block.

当使用 &block 时，显然，其自身作为一个 Proc 类型的参数在方法中可以直接访问，自身就是
一个针对代码块的引用，并**有可能**作为方法的返回值被返回，形成闭包，我们称其为 captured block。
作为一个将类型安全放在首位的程序语言，captured block 无法被内联，因此性能不如 yield 好。

下面是使用 yield 的情形：

```crystal
def foo(&)
  [1,2,3].each do |e|
    yield e
  end
end

foo { |x| puts x }
```

当使用 --release 模式编译时，代码块中的代码，总是会被 llvm 内联化，实际生成代码
看起来像这个样子：


```crystal
def foo
  puts 1
  puts 2
  puts 3
end

foo
```

没有任何性能惩罚！

---------

下面是使用 &block 的例子，编译器无法内联化，因此性能差于使用 yield.


```crystal
def foo(&block : Int32 -> Nil)
  [1,2,3].each do |e|
    block.call(e)
  end
end

foo { |x| puts x }
```

```
**注意**：无论你是否在方法中（作为闭包）实际上**真正**返回(captured)了这个 block，内部
统统按照闭包处理。
```

```
而且，是否是 captured block 与你使用花括号 {} 或者是 do .... end 方式定义无关。
```

## 使用 &block 并且存在代码块参数时，必须增加精确的类型声明

正如上面的例子，当你使用 &block 形式，并且 block 接受参数时，则必须指定参数类型
和返回值类型 `&block : Int32 -> Nil`, 如果具有多个参数，使用逗号分隔。

例如：

```crystal
def foo(&block : Int32, Int32 -> Int32)
  block.call(1, 2)
end

p! foo {|x,y| x + y} # => 3
```

如果你希望 block 没有返回值(即：返回 nil ), 你可以省略 -> 后面的类型，下面的两种写法是等价的：(他们甚至全局共享同样的 Proc 对象)

```crystal
def foo1(&block : Int32 ->)
  block
end

def foo2(&block : Int32 -> Nil)
  block
end

f1 = foo1 {|x| x }
f2 = foo2 {|x| x }

p! f1,f2
f1 # => #<Proc(Int32, Nil):0x55fa01b79f90>
f2 # => #<Proc(Int32, Nil):0x55fa01b79fb0>

p! f1.call(1), f2.call(2) # => nil,nil
```

如果你接受 block 返回啥类型都可以，使用 `_` 作为返回值即可。

```crystal
def foo(&block : Int32 -> _)
  block
end

f1 = foo { |x| x + 1 }
p! typeof(f1) # => Proc(Int32, Int32), 这里自动推断返回 Int32

f2 = foo {|x| x.to_s }
p! typeof(f2) # => Proc(Int32, String), 这里自动推断返回 String
```

上面 p! 返回的类型似乎和我们声明的方式不太一样，这其实是另一种更通用，偏内部实现方式
的写法，如果你用过 haskell 这样的函数语言，一定感觉很熟悉，Proc 声明中的最后一个类型
总是代表代码块的返回值，因此是无法省略的。

```crystal
def foo(&block : Proc(Int32, Int32, Int32)) # => 最后一个类型代表返回值
  block.call(1, 2)
end

p! foo {|x,y| x + y} # => 3
```

## _1, _2 ... 在 Crystal 中就是普通参数。

在 Ruby 2.7 中，引入了位置参数的简写形式，例如：

```ruby
[[1,2],[3,4]].each { print _1, _2, "\n" } # => # 12
											   # 34
```

而在 Crystal 中，_1, _2 就是普通的合法变量, 和普通的变量没有什么不同。

```crystal
[[1,2],[3,4]].each { print _1, _2, "\n" }# Error: undefined local variable or method '_1' for top-level-
```

正确的写法如下：

```crystal
[[1, 2], [3, 4]].each { |(_1, _2)| print _1, _2, "\n" } # => 12
														# => 34
```

## self 含义

在 Crystal 的代码块中，没有自己的 self, 它和代码块被调用时的上下文共享同样的 self。

例如：下面的代码中，self 总是属于方法 foo。

```crystal
class Foo
  def foo
    p "self in the method: #{self}"
    [1].each {|x| p "self in the block: #{self}"}
  end
end

Foo.new.foo

# => "self in the method: #<Foo:0x7f5f107d4fb0>"
# => "self in the block: #<Foo:0x7f5f107d4fb0>"
```

Crystal 中，自然没有类似 `instance_eval { ... }` 或 `instance_exec { ... }` 这样的 hack


但是 Crystal 支持通过 `with self yield` 将 self 传递到代码块中，再通过 `Object#itself` 来访问。

例如：

```crystal
class Adder
  getter x : Int32, y : Int32

  def initialize(@x, @y)
  end

  def calc(&)
    with self yield
  end
end

adder = Adder.new(1, 2)
p! adder.calc { itself.x + itself.y } # => 3
```

```
&block 不支持 with 语法
```

## &. 含义完全不同

Ruby 中，&. 被称作安全调用操作符(Safe Navigation Operator)，例如：

```ruby
nil.upcase.reverse # => NoMethodError: undefined method `upcase' for nil
nil&.upcase&.reverse # => nil 之上使用 &. 调用，不会报错，而是总是返回 nil
```

而 Crystal 中 &. 含义完全不同，我们称其为 `block Short one-parameter (invoke) syntax` 
（block 短调用形式）, 它是Ruby 中 `&:` 用法的一个增强替代，

例如，代码块只有一个代码块参数，并且代码块的内部只是在**这个参数之上调用一个方法**，
此时，我们可以使用 `&` 代表那个唯一的参数，如果在其之上调用 upcase 方法，直接写做：
`&.upcase`, 例如, 下面的两个用法是等价的。

```crystal
["hello", "world"].map {|x| x.upcase }
["hello", "world"].map &.upcase
```

它看起来和 Ruby 版本的 `["hello", "world"].map &:upcase` 相似，但是更强大，因为，
它调用的方法还允许接受自己的参数，甚至允许链式调用。

例如：

```crystal
(1..10).map &.**(3) # 等价于：(1..10).map {|x| x.**(3) }, 结果为：[1, 8, 27, 64, 125, 216, 343, 512, 729, 1000]
["hello", "world"].map(&.upcase.reverse) # => ["OLLEH", "DLROW"]
```

## return 

Crystal 不允许从顶层空间直接 return，仅在方法定义的上下文中才允许 return

这在和 block 一起使用时，尤其注意，例如, 上面的代码最后一行如果使用 return 会报错。

```
adder.calc { return itself.x + itself.y } # Error: can't return from top level
```
