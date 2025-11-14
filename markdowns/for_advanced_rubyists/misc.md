## 运行代码方式

Crystal 是一门编译型、静态类型的语言，因此你需要先**编译**，再**运行**。

假设你有一个 `foo.cr`:

```crystal
# Crystal
puts "Hello world"
```

你需要首先 build 它 

```bash
$ crystal build foo.cr
```

它在当前文件夹下，创建了一个可执行文件叫做：`foo`，然后你可以运行它。

```bash
$ ./foo
Hello world
```

当作为最终发布版分发时，记得添加 `--release`, 这开启了最高级别的 llvm 优化，它带来了好得多的性能，但需要更长的 build 时间。

当执行基准测试时，请总是记得开启它。

```bash
$ crystal build --release foo.cr
```

`crystal build --help` 来获取更多的帮助。

## 迭代器(Iterator)

Crystal 额外引入了 Iterator 类型（等价于 Ruby 中的 Enumerator::Lazy)

通常来说，当调用一个 Enumerable 方法，例如：#each, #map 等，但是没有代码块时，
会返回一个 lazy 的 Iterator 对象。

举个例子：我们希望取出一千万以内的前三个偶数，并将其 ✖️ 3。

```crystal
(1..10_000_000).select(&.even?).map { |x| x * 3 }.first(3) # => [6, 12, 18]
```

上面的写法是工作的，但是建立了数个不必要的中间数组，我们将其分解如下：

```crystal
(1..10_000_000).select(&.even?) # => 返回一个大小为 500 万，元素全是偶数的数组

map { |x| x * 3 } # => 将上面的的所有元素✖️3

first(3) # => 最后取出前三个
```

这带来额外的计算以及不必要的巨大内存消耗，因为我们只对前三个元素感兴趣，
但是却返回了 500 万个，并计算，但最后只取了前三个，其他被抛弃。

更高效的做法，首先通过 each 返回一个 lazy 的 Iterator，因为 Iterator 重新定义了很多 
Enumerable 的方法，例如：上面的 #map, #select, #first, 调用这些方法，返回了一个
包裹调用者 Iterator 对象的新的 Iterator 对象，在调用链的最后，我们仍然得到的是一个新的 
lazy 的 Iterator 对象，没有任何实际计算，

```crystal
(1..10_000_000).each.select(&.even?).map { |x| x * 3 }.first(3) # => #<Iterator::FirstIterator ... >
```

分解如下：

```crystal
(1..10_000_000).each # => <Range::ItemIterator ...>
select(&.even?) # =>  Iterator::SelectIterator(<Range::ItemIterator ...> ... >>
...
first(3) # => #<Iterator::FirstIterator ... >
```

当我们希望取出值时，我们可以再次调用 #each(&) 或 to_a 


```crystal
first_three_iter = (1..10_000_000).each.select(&.even?).map { |x| x * 3 }.first(3)

first_three_iter.each do |x|
  p x # => 直到这里才实际执行计算。
end # => 打印 6, 12, 18

# 因为 Iterator 是单向的，上面已经通过 each(&) 将所有的三个结果都取出了

first_three_iter.to_a # => []，因此 to_a 返回空数组。
```

正如你猜想的那样，你也可以通过 Iterator#next 方法，一个一个的将元素取出。

```crystal
iter = (1..5).each

iter.next # => 1
iter.next # => 2
typeof(iter.next) # => Int32 | Iterator::Stop
```

------------

创建一个新的 Iterator （Ruby 里面叫做 Enumerator) 也是可以的, 需要下面的几步：

1. 创建一个类，并且混入 Iterator(T) 模块
1. 定义一个 #next 方法，返回下一个元素
2. 在达到结尾时，调用 #stop 方法返回一个 Iterator::Stop::INSTANCE

例如，下面是一个 Zeros 类，返回指定数量的 0

```crystal
class Zeros
  include Iterator(Int32)

  def initialize(@size : Int32)
    @produced = 0
  end

  def next
    if @produced < @size
      @produced += 1
      0
    else
      stop
    end
  end
end

zeros = Zeros.new(5)

zeros.each {|e| print e } # => 00000
```
 
## require 用法不同
 
### Crystal 移除了 require_relative 方法

代之，可以直接使用 require 来引用相对路径的文件。
 
```crystal
require "./foo"
```

并且支持和 File.match? 一样的增强版的 shell filename globbing

- `*` 支持任意数量的除了目录分隔符之外的任意字符。

例如：`require "./foo/*"`，匹配 foo 目录下的所有 cr 文件, 但不含子目录。

- `/**` 递归的匹配所有子目录中的 cr 文件

例如：`require "./foo/**"`，匹配 foo 目录以及所有子目录下的所有 cr 文件。

### $CRYSTAL_PATH

类似于 Ruby 在 $RUBYLIB 从前往后中查找 lib 文件夹来确定引用的 gem, Crystal 等价的环境变量
叫做 $CRYSTAL_PATH, 可以通过 `crystal env CRYSTAL_PATH` 来取得这个变量的默认值

```bash
 ╰──➤ $ crystal env CRYSTAL_PATH
lib:/home/zw963/Crystal/bin/../share/crystal/src
```

可以看到，$CRYSTAL_PATH 默认仅仅包含 `当前目录下的 ./lib` 以及本地安装的编译器的 `标准库相对路径`.
`~/Crystal/share/crystal/src`，我们将指定的文件夹加入到到 $CRYSTAL_PATH中，使用冒号（:) 分隔即可。

例如：

```bash
 ╰──➤ $ export CRYSTAL_PATH=new_folder:$(crystal env CRYSTAL_PATH)
lib:/home/zw963/Crystal/bin/../share/crystal/src
 ╰──➤ $ crystal env CRYSTAL_PATH
new_folder:lib:/home/zw963/Crystal/bin/../share/crystal/src
```


### require 查找策略

我们假设这个加入 $CRYSTAL_PATH 的**文件夹**叫做 `CPATH`, 当我们 `require "foo"` 时，会按照如下顺序查找:

- CPATH/foo.cr					(1) 简单的 foo.cr
- CPATH/foo/foo.cr				(2)	foo 替换为 foo/foo.cr
- CPATH/foo/src/foo.cr			(3) 和 (2) 类似，只不过 `第一级` 文件夹后面加了一个 src 文件夹。

上面的 foo 可以扩展成 `a/b/c` 这种形式，例如，`require "foo/bar/baz"`, 会查找：

- CPATH/foo/bar/baz.cr
- CPATH/foo/bar/baz/baz.cr
- CPATH/foo/src/bar/baz.cr

可见仍旧满足上面的策略，只不过将 foo 替换为 foo/bar/baz 而已。

这里举一个例子，方便大家理解为何要支持这么复杂的路径。

例如，你写了一个俄罗斯方块 app, 它依赖另一个叫做 [sleepinginsomniac/pixelfaucet](https://github.com/sleepinginsomniac/pixelfaucet) 
的基于 sdl2 的图形库，当你在 shard.yml 中加入如下内容，并且运行 shard install 成功之后，
你的项目的 lib 文件夹下会被安装了一个 pixelfaucet 文件夹，大概这个样子（省略一些文件）

├── pixelfaucet
│   └── src
│       ├── entity.cr
│       ├── flags.cr
│       ├── fps.cr
│       ├── frame_timer.cr
│       ├── game.cr
│       ├── lehmer32.cr
│       ├── lib_sdl.cr
│       ├── noise.cr
│       ├── particle.cr
│       ├── pixel.cr
│       ├── shape.cr
│       ├── sprite.cr
│       └── version.cr


现在你需要用到 pixelfaucet 的 game 库，即：lib/pixelfaucet/src/game.cr

一个办法是，你使用相对路径的 require, 像这个样子： 

```crystal
require "./lib/pixelfaucet/src/game"
```

但是如果你理解 Crystal 是如何查找库的，你可能会尝试：


```crystal
require "pixelfaucet/game"
```

是的，这样写是完全工作的。（参见上面的 a/b/c 的例子）

__注意__：require 绝对路径是不支持的。例如：require "/some/aboslote/path"
Crystal 没有类似于 Ruby 中 load 方法的等价物，但是可以通过下面的 
read_file 宏(macro) 来达到同样的目的

```crystal
# 这个 macro 相当于把文件 path.cr 里面的内容物理粘贴到宏调用位置
{{ read_file("/some/alsolute/path.cr").id }} 
```

## 整除

Ruby中的除法运算符 `/` 当两边同为整数时进行 `floored division`，即：默认会向较小的数四舍五入。
当调用 `#fdiv` 时，才会返回浮点数。

```ruby
 ╰──➤ $ pry
[1] pry(main)> 9/5
=> 1
[2] pry(main)> 9/-5
=> -2
[3] pry(main)> 9.fdiv(5)
=> 1.8
[4] pry(main)> 9.fdiv(-5)
=> -1.8
```

这是一个坑，因为似乎大部分其他语言 `/` 默认都不是这样，未来版本的 Ruby 也计划移除这个特性。

相比较而言，Crystal 处理方式则比较大众化, `9/5` 和 `9.fdiv(5)` [完全是一样的](https://github.com/crystal-lang/crystal/blob/3f369d2c7/src/int.cr#L155)。
`floored division` 则使用专门的 `//` 运算符。


```ruby
ic(1.16.3):001> 9/5
 => 1.8
ic(1.16.3):002> 9/-5
 => -1.8
ic(1.16.3):003> 9.fdiv(5)
 => 1.8
ic(1.16.3):004> 9//5
 => 1
ic(1.16.3):005> 9//-5
 => -2
```

## 正则表达式

Crystal 使用 PCRE2 正则表达式。
而 Ruby 则使用来自日本开发者的 [Onigmo](https://github.com/k-takata/Onigmo) 正则引擎，对中文支持更好，同时支持很多简单但是强大的正则。

两者性能比较，PCRE2 针对复杂的正则性能更优，但是 Ruby 则简单的正则性能更优。

很多非常方便的写法，在 Ruby 下是支持的，但是在 PCRE2 下则非常难写，甚至非常晦涩。

一个非常简单的例子就是匹配类似于：`abba` `abcba` `abccba` 这种的 `回文`(palindrome)。

使用 Ruby 的正则引擎非常简单：

```ruby
[1] pry(main)> "abba".match? /(.)(.)\k<-1>\k<-2>/
=> true
[2] pry(main)> "abcba".match? /(.)(.)\k<-1>\k<-2>/
=> false
[3] pry(main)> "abccba".match? /(.)(.)\k<-1>\k<-2>/
=> true
[4] pry(main)> "abab".match? /(.)(.)\k<-1>\k<-2>/
=> false
```

同样的是使用 PCRE2，则需要用到递归 (recursive)，极其晦涩。


```crystal
ic(1.16.3):001> "abba".matches? /^((.)(?1)\2|.?)$/
 => true
ic(1.16.3):002> "abcba".matches? /^((.)(?1)\2|.?)$/
 => true
ic(1.16.3):003> "abccba".matches? /^((.)(?1)\2|.?)$/
 => true
ic(1.16.3):004> "abab".matches? /^((.)(?1)\2|.?)$/
 => false
```

这里的 (?1) 是递归表达式，数字 1 表示分组 1, 即：最外面的那个括号，引用了整个表达式。
你可以想象 (?1) 出现的地方，会被再次使用整个表达式替换，就如同我们写递归时一样。

针对 "abba", 上面的正则会展开三次，第一次和第二次，(?1) 两侧的 (.) 和 \2 匹配回文总是成功。

1. /^((.)(?1)\2|.?)$/
2. /^((.)((.)(?1)\2|.?)\2|.?)$/

但是第三次， `|` 左侧匹配失败，因为无法继续匹配回文，因此会继续匹配右侧的`.?`, 
它总是会被匹配到，并返回递归的上一层。

3. /^((.)((.)((.)(?1)\2|.?)\2|.?)\2|.?)$/

作为一个用惯了 Ruby 正则表达式的程序员，会觉得使用 PCRE2 不方便，常常不支持这个，或不支持那个。

## 如何检测一段代码是使用 Ruby 还是 Crystal 运行？

```crystal
if Array.to_s == "Array(T)"
  puts "Crystal"
else
  puts "Ruby"
end
```
