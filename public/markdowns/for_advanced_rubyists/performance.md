谈起 Crystal 和 Ruby 的区别，就不能不谈性能因素，毕竟很多人离开 Ruby 而采用其他语言，
例如，go、rust、包括 Crystal，都是因为 Ruby 相对而言速度较慢，对吧？

这里主要分析一下使用 Crystal 之后，值得注意的性能相关的因素。

本文部分内容参考自[官方 performance 文档](https://crystal-lang.org/reference/latest/guides/performance.html)

## 不要过早的优化

```info
> We should forget about small efficiencies, say about 97% of the time: premature optimization is the root of all evil. 
> Yet we should not pass up our opportunities in that critical 3%.

我们应该忽略那些细微的效率优化，例如：在 97% 的情况下，过早优化是万恶之源。
然而，我们也不能放过那关键的 3% 的优化机会。
```

然而，如果你正在编写一个程序，并意识到通过进行一些微小的修改就可以写出一个语义相同且运行速度更快的版本时，你绝对不应该错过这个机会。


你总是应该首先对程序进行剖析，以了解其瓶颈所在。

- 在 macOS 上你可以使用随 XCode 提供的 [Instruments Time Profiler](https://developer.apple.com/library/prerelease/content/documentation/DeveloperTools/Conceptual/InstrumentsUserGuide/Instrument-TimeProfiler.html)，或任何一个 [sample profile](https://stackoverflow.com/questions/11445619/profiling-c-on-mac-os-x) 工具。

- 在 Linux 上，任何能够剖析 C/C++ 程序的工具，如 perf 或 Callgrind，都应能正常工作。更多的例子，见 [查找性能瓶颈](/docs/profile)

- 无论是 Linux 还是 OS X，你都可以使用调试器运行程序，然后偶尔按下 `ctrl+c` 中断它，并执行 `gdbbacktrace` 来查看路径追踪中的模式（或者使用 gdb 的穷人版剖析工具，该工具为你做了同样的事情，或者 OS X 的 sample 命令）。

## 尽可能的避免 额外/不必要 的内存分配

例如，创建一个类的实例，将在堆中分配内存。

但是，创建一个 struct 的实例使用栈内存, 不会产生性能惩罚。

如果你不懂堆和栈的区别，请参考 [这个答案](https://stackoverflow.com/questions/79923/what-and-where-are-the-stack-and-heap) 

分配堆内存速度更慢，而且它给垃圾收集器 GC (Garbage Collector )更多的压力，因为它
不得不在稍后释放这些内存。

见下面的 benchmark 

```crystal
# class_vs_struct.cr

require "benchmark"

class PointClass
  getter x
  getter y

  def initialize(@x : Int32, @y : Int32)
  end
end

struct PointStruct
  getter x
  getter y

  def initialize(@x : Int32, @y : Int32)
  end
end

Benchmark.ips do |x|
  x.report("class") { PointClass.new(1, 2) }
  x.report("struct") { PointStruct.new(1, 2) }
end
```

```bash
 ╰──➤ $ crystal run --release class_vs_struct.cr
 class 134.44M (  7.44ns) (± 6.40%)  16.0B/op   4.74× slower
struct 637.87M (  1.57ns) (±20.96%)   0.0B/op        fastest
```

但是 struct 也不是万能的，struct 按照值的方式传递（而不是大多数对象采用的引用方式传递）

```info
任何时候，一个 struct 对象 `（作为参数）被 传递` 或 `返回` 时，都会创建一个新的副本。
如果恰巧在传递后修改了它，则只是修改的副本，这点极容易引起 bug。
```

例如：如果你传递一个 struct 给一个方法，并且在方法内部修改了它，方法的调用者(caller) 无法
看到这些改变，看下面这个例子：


```crystal
class Klass
  property array = ["str"]
end

struct Strukt
  property array = ["str"]
end

def modify(obj)
  obj.array << "foo" # 这个直接在数组 ["str"] 引用之上修改，class/struct 都有效
  obj.array = ["new"] # 这个是直接修改 object.array 的属性，class 直接修改传入的 obj, struct 修改的是副本。
  obj.array << "bar"  # 这个是在上面的新的 array 之上操作。
  
  obj
end

klass = Klass.new
# 类是作为引用被传入的
puts modify(klass) # => ["new", "bar"]
puts klass.array   # => ["new", "bar"]

strukt = Strukt.new
# 结构体作为一个值的副本被传入的
puts modify(strukt) # ，=> ["new", "bar"]
puts strukt.array   # => ["str", "foo"]
```

甚至结构体内通过 self 返回，都是一个副本，所以结构体更适合于包装 `不可变的(immutable)对象`，尤其是小对象。

## 不要建立中间字符串，而是尽可能的直接写入 IO

如果你使用 Ruby, 当打印一个数字到标准输出时，例如：

```ruby
puts 123
```

实际做的事情是：puts 会查找对象是否有实现 `#to_s`, 如果有，调用它，返回对象的字符串形式，
然后，将字符串写入标准输出。这工作的很好，但是有一个瑕疵，它在堆上建立一个中间字符串
（当调用#to_s 时），用完之后又立即丢弃它，这是不必要的。

在 Crystal 中，puts 调用的是 `123.to_s(io)`, 那个额外的 io 参数就是 puts 希望输出到的 IO

所以，Crystal 下请不要这样做：

```crystal
puts 123.to_s
```

而代之，应该总是附加一个对象直接到 IO

下面是一个例子：

```crystal
class MyClass
  # Good
  def to_s(io)
    # appends "1, 2" to IO without creating intermediate strings
    x = 1
    y = 2
    io << x << ", " << y
  end

  # Bad
  def to_s(io)
    x = 1
    y = 2
    # using a string interpolation creates an intermediate string.
    # this should be avoided
    io << "#{x}, #{y}"
  end
end
```

所以，对于自定义类型，总是应该覆写(override) `#to_s(io)`， 而不是 `to_s` 方法，来
避免中间字符串，获取更好的性能。

下面是一个 benchmark

```crystal
# io_benchmark.cr

require "benchmark"

io = IO::Memory.new

Benchmark.ips do |x|
  x.report("without to_s") do
    io << 123
    io.clear
  end

  x.report("with to_s") do
    io << 123.to_s
    io.clear
  end
end
```

```bash
 ╰──➤ $ crystal run --release io_benchmark.cr
without to_s 161.36M (  6.20ns) (± 2.96%)   0.0B/op        fastest
   with to_s  55.23M ( 18.11ns) (± 3.40%)  32.0B/op   2.92× slower
```

## 使用字符串插值，而不是字符串拼接

几乎在所有情况下，字符串插值，例如 `"Hello, #{name}"` 总是好过后者 `"Hello, " + name.to_s`

字符串插值由编译器转换成如下形式，来避免中间字符串：

```crystal
String.build do |io|
  io << "Hello, " << name
end
```

## 使用优化的 `String.build`，而不是 `IO::Memory` 来构建字符串

参见下面的 benchmark

```crystal
require "benchmark"

Benchmark.ips do |bm|
  bm.report("String.build") do
    String.build do |io|
      99.times do
        io << "hello world"
      end
    end
  end

  bm.report("IO::Memory") do
    io = IO::Memory.new
    99.times do
      io << "hello world"
    end
    io.to_s
  end
end
```

```bash
 ╰──➤ $ crystal run --release 1.cr
String.build   1.92M (519.54ns) (± 7.71%)  5.88kB/op        fastest
  IO::Memory 870.79k (  1.15µs) (± 6.98%)  5.88kB/op   2.21× slower
```


## 避免反复的创建临时对象。

参见下面的例子：

```crystal
lines_with_language_reference = 0

while line = gets
  if ["crystal", "ruby", "java"].any? { |string| line.includes?(string) }
    lines_with_language_reference += 1
  end
end

puts "Lines that mention crystal, ruby or java: #{lines_with_language_reference}"
```

上面的代码存在一个重大性能问题！

当迭代每一行时，一个新的（不变的）数组对象 ["crystal", "ruby", "java"] 被反复创建。

解决办法：

1. 使用 tuple `{"crystal", "ruby", "java"}` 代替数组，它在 stack 中被创建，占用内存很少，
   而且，编译器大概率会将它优化掉, 因此这是首选的方式。

2. 将数组作为一个常量, 并移到循环外面。

```crystal
LANGS = ["crystal", "ruby", "java"]

lines_with_language_reference = 0
while line = gets
  if LANGS.any? { |string| line.includes?(string) }
    lines_with_language_reference += 1
  end
end
puts "Lines that mention crystal, ruby or java: #{lines_with_language_reference}"
```

总是仔细检查在循环中存在类似上面的 array literal，这些事情也可能发生在一个方法调用中。


## 迭代字符串

Crystal 中的字符串使用 UTF-8 编码, 因为 UTF-8 是一个可变长的编码，不同的字符可能需要
不同的字节来保存。因此 `String#[]` 方法复杂度不是 O(1) 的，因为寻找指定位置的字符，
需要遍历整个字符串，不断的执行解码操作。


下面的方法拥有 O(N^2) 的复杂度。（而且 string.size 也是一个 slow 操作）

```crystal
string = "foo"
while i < string.size
  char = string[i]
  # ...
end

```

但是 ASCII 字符总是单字节的，如果我们知道一个字符串全部由 ASCII 字符组成，那么
`String#[]` 可以是 O(1) 的，如果我们知道它是合法的 ASCII 字符串，我们可以使用 
each_char 来遍历：

```crystal
string = "foo"
string.each_char do |char|
  # ...
end
```
