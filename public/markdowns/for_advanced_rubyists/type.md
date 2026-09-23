## 字符串

Crystal 使用双引号来表示字符串，单引号是 Char 类型（在栈中分配）。

```crystal
p typeof("Hello") # => String
p typeof("汉") # => String
p typeof('汉') # => Char
```

这几乎总是从 Ruby 切换到 Crystal 最先遇到的坑。

而且，Crystal 字符串是不可变的, 因此，Ruby 中常用的方法 `String#<<` 是没有的。

尝试修改一个字符串，例如 String#+ 或 interpolation 都会产生新的字符串，你需要将修改后字符串重新赋值给一个变量。

```crystal
str = "Hello"
p str.object_id # => 104918042676384
str = str.sub("H", "h")
p str.object_id # => 132565044809664
```

你仍然可以使用 `%` 或 `%q` 来分别表示 Ruby 中等价的 `"双引号"` 和 `'单引号'` 

```crystal
recipient = "Billy"
p %(Hello #{recipient}!) # => "Hello Billy!"
p %q(Hello #{recipient}!) # => "Hello \#{recipient}!"
```

## Crystal 中没有全局变量

Crystal 不支持定义 $ 开头的全局变量，事实上 $ 开头的其实根本不是全局变量，因为只是方法可见的。

默认，只有很少的几个预定义的 $ 开头的变量，正则匹配相关的 $~, $1, $2 ... 以及前一个被执行的进程退出状态 $?

```crystal
"hello" =~ /(ll)o/

p $~ # => Regex::MatchData("llo" 1:"ll")
p $0 # => llo, 等价于 $~[0]，等价于 Ruby 中的 $&
p $1 # => ll，等价于 $~[1]
p $2 # => Unhandled exception: Invalid capture group index: 2 (IndexError)

`ls -alh`
p $? # => Process::Status[0]
```

## 整数与布尔类型

整数类型细分为 8 个，而 Ruby 是 Integer 一个。

```crystal
p typeof(1_i8) # => Int8
p typeof(1_u8) # => UInt8
p typeof(1_i16) # => Int16
p typeof(1_u16) # => UInt16
p typeof(1) # => Int32 这是整数默认类型, 等价于：typeof(1_i32)
p typeof(1_u32) # => UInt32
p typeof(1_i64) # => Int64
p typeof(1_u64) # => UInt64
```

Ruby 中，当数字大到 Fixnum 无法容纳它时，会自动转化为 Bignum, Crystal 则抛出 OverflowError 异常

```crystal
x = 127_i8 # An Int8 type
x          # => 127
x += 1     # Unhandled exception: Arithmetic overflow (OverflowError)
```

Crystal 标准库提供了专门的任意大小和精度的类型

[`BigDecimal`](https://crystal-lang.org/api/BigDecimal.html) | 
[`BigFloat`](https://crystal-lang.org/api/BigFloat.html) |
[`BigInt`](https://crystal-lang.org/api/BigInt.html) |
[`BigRational`](https://crystal-lang.org/api/BigRational.html)

Crystal 中，true/false 类属于 Bool 类型, 而 Ruby 是单独的 TrueClass 和 FalseClass

## 哈希与 NamedTuple

Crystal 当中：哈希火箭表示一个哈希，而 1.9 新哈希表示法

`{:foo => 100}` 这是定义了一个哈希。

`{foo: 100}` 则是定义了一个 NamedTuple

后者是一个不可变的、编译时确定大小的特定的 NamedTuple 类型, 并且是栈分配的，可以简单的将理解为就是一个不可变的 Struct。

```crystal
x = {:foo => 100, :bar => "Hello"}
y = {foo: 100, bar: "Hello"}

p typeof(x) # => Hash(Symbol, Int32 | String)
p typeof(y) # => NamedTuple(foo: Int32, bar: String), 编译时类型就是一个包含了整数类型属性 foo, 以及字符串类型属性 bar 的 NamedTuple

# 通过符号和字符串取值都是可以的。
p y[:foo] # => 100
p y["foo"] # => 100
```

个人认为这是对 Ruby 错误设计的完美修复，关键字参数本来就应该设计成这样。

## 实例变量和类变量

Crystal 中不存在 Ruby 的类变量那样的东西，Crystal 的 `类变量` 的行为和 Ruby 中 `类的实例变量` 相同。

```crystal
class Foo
  @@value = 1

  def self.value
    @@value
  end

  def self.value=(@@value)
  end
end

class Bar < Foo
end

p Foo.value # => 1
p Bar.value # => 1

Foo.value = 2

p Foo.value # => 2
p Bar.value # => 1

Bar.value = 3

p Foo.value # => 2
p Bar.value # => 3
```

即：`@@类变量` 是属于类自身的变量，每一个子类也会继承父类的类变量值（类型必须相同），
但是会创建自己**独立的**类变量实例, 因此修改子类的类变量的值，不会影响父类，反之亦然。

这是再一次对 Ruby 错误行为的修复。

-----------

因为 Crystal 中的 `@@类变量` 其行为表现就是 Ruby 中的 `类级别` 的 `@实例变量`, 
那么问题来了，Crystal 中类级别定义的实例变量又是什么呢？


```crystal
class Foo
  @value = 100

  def value
    @value
  end

  def initialize
    puts "Foo"
  end
end

class Bar < Foo
end

bar = Bar.new
p bar.value  # => Crystal 输出 100, Ruby 输出 nil
```

结果为：上面的 @value 其实就是一个普通的实例变量，只不过在类定义中进行了初始化，
如果这个类有签名不同的多个不同版本的构造器(initialize 方法)，它相当于为所有构造器
初始化了变量 @value，避免了重复初始化。 而且当这样的类被 reopen 时，@value 值也是存在的。

由于目前编译器的限制，在方法定义中初始化一个的可空的实例变量是不合法的。

```crystal
class A
  def initialize
    @x : Int32? 
  end
end

a = A.new 

# 3 | @x : Int32?
# ^-
# Error: declaring the type of an instance variable must be done at the class level
```

即使赋初值为 nil 也不行。

```crystal
class A
  def initialize
    @x : Int32? = nil
  end
end

a = A.new

#  3 | @x : Int32? = nil
#      ^
# Error: instance variable @x of A was inferred to be Nil, but Nil alone provides no information
```

只能通过类级别来初始化

```crystal
class A
  @x : Int32?

  def initialize
  end
end

p A.new # => #<A:0x7a69c688bfc0 @x=nil>
```

当然，在方法中直接使用 literal 值初始化一个实例变量是可以的。


```crystal
# 但是赋值一个非 nilable 的值，来推断类型是可以的。

class A
  def initialize
    @x = 100
  end
  
  def hello
    @hello = "Hello"
  end
end

p  A.new # => #<A:0x7d736b629ce0 @x=100, @hello=nil>
```
