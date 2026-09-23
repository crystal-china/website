## 第一步：首先需要替换所有 '单引号字符串' 到 "双引号字符串"

你可以使用 Ruby 社区中大名鼎鼎的 [rubocop](https://github.com/rubocop/rubocop) 来完成它。

首先安装 rubocop gem, `gem install rubocop`

然后你可以进入 gem 目录，运行[这个脚本](https://github.com/crystal-china/port_ruby_to_crystal/blob/master/bin/rubocop_double_quotes) 执行替换。


## 第二步：对一些重命名的方法名做一些简单的替换。

进入 gem 目录，执行前面提到的 [port_ruby_to_crystal 脚本](https://github.com/crystal-china/port_ruby_to_crystal/blob/master/bin/port_ruby_to_crystal) 即可。

## 第三步：添加必要的类型

作为一个高度依赖于类型推断的静态类型语言，大多数情况下，代码写起来和 Ruby 没什么不同，
但是某些特殊的类型，强制类型声明是必须的。

例如：

### 空数组和空哈希

```crystal
ary = [] of String # => 空数组必须指定数组元素的类型。

ary << "Hello" # => ["Hello"]
ary << 123 # => Error: expected argument #1 to 'Array(String)#<<' to be String, not Int32

h = {} of String => String
```

### 包含代码块参数的 block

下面的代码是合法的 Ruby 代码，但是 Crystal 会报错。

```crystal
def foo(&block)
  [1,2,3].map &block
end

foo {|x| x * 2 } # Error: wrong number of block parameters (given 1, expected 0)
```

因为，你没有为 &block 指定签名，默认假设这是一个没有代码块参数的 block，正确的做法是：


```crystal
def foo(&block : Int32 -> Int32)
  [1,2,3].map &block
end

p foo {|x| x * 2 } # => [2, 4, 6]
```

等等

## 第四步，如果使用了第三方 gem，替换它或暂时移除它

当前 Ruby 项目依赖的第三方库，Crystal 可能需要寻找或没有替代库, 此时，你不得不暂时
隔离它，等编译通过后，再寻找替代或自己实现它。

Crystal 没有一个类似于 https://rubygems.org 这样的中心化网站，包含所有的 Ruby gem.

但是社区仍然提供了几个网站，让你可以方便的查找存在的 shards

https://shards.info/

https://shardbox.org/

上面的网站都尝试找一找，也可以去 [官方 forum](forum.crystal-lang.org) 去搜索或提问

要明白的是，很多著名的 shards, 并非托管自 github，可能来自非常小众的托管平台，
例如：https://codeberg.org，https://sr.ht, 甚至有些项目使用 git 之外的其他 SCM 系统，
例如：fossil


## 第五步：修复编译时错误，尤其是类型相关错误。

取决于你的 Ruby 代码，如果你没有炫技，使用太多诸如元编程之类的动态特性，这一步可能
很简单就可以达到。否则，可能需要大量的更改，甚至重写，这往往是最困难的一步。

总之，理解每一个对象正确的类型，对于 porting gem 到 shard 非常关键，当你真正完全 
读懂代码，这一步并没有想象中那么难。

## 第六步，修复运行时错误

虽然 Crystal 是一个非常安全的语言，能帮助你阻止绝大部分空指针错误，但并不是绝对。
你仍然需要确保你的运行时逻辑正确、可用。

## 最后一步，为方法的参数，返回值添加类型

[cr-source-typer](https://github.com/vici37/cr-source-typer) 是一个极好的辅助工具，可以自动帮助你为所有**方法参数**以及**返回值**增加类型，
但是你必须首先保证修改后的代码可以通过编译。

作为一个被使用的库，添加了类型的代码，对于后来的维护者（可能就是之后的你），极大地
提高了可读性，这绝对是相对于 Ruby 来说一个巨大的优势！

