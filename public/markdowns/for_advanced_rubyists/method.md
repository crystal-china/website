## 调用方法时传递关键字参数

```info
Crystal 中，当定义一个方法时，无需特殊的语法来声明关键字参数类型，因为他和普通的位置参数是一样的。

当调用一个方法并传递实参进来时，既可以使用正常的**位置参数方式**调用，也可以使用**关键字参数**方式调用
```


```crystal
def say_hello(recipient)
  puts "Hello #{recipient}!"
end

say_hello("Crystal") # => "Hello Crystal!"
say_hello(recipient: "Crystal") # => "Hello Crystal!"
```

Crystal 中提供了一个特殊的语法强制某些参数只能使用关键字参数方式调用。

```crystal
def foo(x, *, y)
end

foo 1, y: 2    # OK
foo y: 2, x: 3 # OK
foo 1, 2 # => Error: missing argument: y
```

## 定义方法名同名的方法


即使方法名相同的方法，可以通过 `参数名`不同、`参数个数`不同、`参数类型` 以及 `是否需要代码块 & ` 进行区分。

### 参数类型不同

```crystal
def foo(a : String)
  puts "foo(a : String)"
end

def foo(a : Int32)
  puts "foo(a : Int32)"
end

foo(100) # => foo(a : Int32)
foo("Hello") # => foo(a : String)
```



### 参数名不同

```crystal
def foo(*, a)
  puts "foo(a)"
end

def foo(*, b)
  puts "foo(b)"
end

foo(a: 100) # => foo(a)
foo(b: 100) # => foo(b)
```

```info
参数名不同的情况下，必须添加 *，强制要求必须使用关键字参数方式调用, 才能正确区分。
```

例如：

```crystal
def foo(x)
  puts "foo(x)"
end

# foo(y) 覆盖了 foo(x) 的定义。
def foo(y)
  puts "foo(y)"
end

foo(100) # => "foo(y)"，调用的是 foo(y)

# foo(x: 100) # Error: missing argument: y，因为 foo(x) 被覆盖不存在了

# 此时必须添加类型

def baz(x : Int32)
  puts "foo(x)"
end

def baz(y : String)
  puts "foo(y)"
end

baz(100)   # foo(x)
baz("100") # foo(y)

# 或强制必须关键字参数

def bar(*, x)
  puts "foo(x)"
end

def bar(*, y)
  puts "foo(y)"
end

bar(x: 100) # foo(x)
bar(y: 100) # foo(y)
```

### 参数个数不同

```crystal
def foo(a，b)
  puts "foo(a, b)"
end

def foo(a)
  puts "foo(a)"
end

foo(100,200) # => foo(a, b)
foo(100) # => foo(a)
```

### 是否包含代码块

```crystal
def foo
  puts "foo()"
end

def foo(&)
  puts "foo(&)"
end

foo # => "foo()"
foo {} # => "foo(&)"
```


## 方法名称的变更

方法名称的变更非常多，这里不一一列举，这里只是简要按照类别介绍下：

### Ruby 中很多存在别名的方法，Crystal 仅保留其中一个。

Ruby 为了追求代码的可阅读性，存在很多适合于不同上下文的别名，例如：


Array#~~lengh~~ => Array#**size**

Enumerable#~~detect~~ => Enumerable#**find**

Enumerable#~~collect~~ => Enumberable#**map**


但是这反而会造成新手的困惑，增加了负担，我认为这个改动是合理的。

### 一些方法名称的语法（习惯）变更，更符合西方人说话的习惯，

例如：

Object#~~respond_to?~~ => Object#respond**s**_to?

Array#~~include?~~ => Array#include**s**?

File#~~exist?~~ => File#exist**s**?

### 单纯的一些名称换了，换成 Crystal 开发者认为更合适的名字，

例如：

~~attr_reader~~ => getter

~~attr_writer~~ => setter

~~attr_accessor~~ => property

Hash#~~key~~ => Hash#key_for

~~\_\_dir\_\_~~ => \_\_DIR\_\_


```info
类似这样的变更，使用脚本替换相对简单，可以参考 [port_ruby_to_crystal 脚本](https://github.com/crystal-china/port_ruby_to_crystal/blob/master/bin/port_ruby_to_crystal)。


这是一个使用 Ruby 正则表达式编写的脚本，用来对一些 `常见的方法名变更` 做一些简单且安全地替换, 这减少了从 Ruby 迁移到 Crystal 的摩擦。
```

### 看起来啥都没变，但是方法的部分行为改变了，这可能是个大坑，尤其值得注意

|						| Ruby					| Crystal								
| ---					| ----					| ----									
| Enumerable#each(&)	| 总是返回 self		| 总是返回 nil							
| Array#fetch			| 接受一个参数的形式	| 需提供第二参数或 `block` 指定默认值	

下面是一个更狡黠的例子。

例如，下面的是完全合法的 Ruby 代码, 它创建了一个新文件 out.txt，并以 a 模式写入字符串 "content"

```ruby
File.write("out.txt", "content", mode = "a")
```

但是，如果在 Crystal 下执行它，会抛出一大堆错误。

<details>
<summary>点击查看 backtrace</summary>

```sh
 error in line 0
Error: expanding macro


In <top-level>:1:6

 1 | File.write("out.txt", "content", mode = "a")
          ^----
Error: instantiating 'File.write(String, String, String)'


In /home/zw963/.asdf/installs/crystal/1.15.0/share/crystal/src/file.cr:823:3

 823 | def self.write(filename : Path | String, content, perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, mode = "w", blocking = true)
       ^----
Error: instantiating 'write(String, String, String, Nil, Nil, String, Bool)'


In /home/zw963/.asdf/installs/crystal/1.15.0/share/crystal/src/file.cr:824:5

 824 | open(filename, mode, perm, encoding: encoding, invalid: invalid, blocking: blocking) do |file|
       ^---
Error: instantiating 'open(String, String, String, encoding: Nil, invalid: Nil, blocking: Bool)'


In /home/zw963/.asdf/installs/crystal/1.15.0/share/crystal/src/file.cr:741:12

 741 | file = new filename, mode, perm, encoding, invalid, blocking
              ^--
Error: instantiating 'new(String, String, String, Nil, Nil, Bool)'


In /home/zw963/.asdf/installs/crystal/1.15.0/share/crystal/src/file.cr:175:53

 175 | fd = Crystal::System::File.open(filename, mode, perm: perm, blocking: blocking)
                                                       ^
Error: expected argument 'perm' to 'Crystal::System::File.open' to be (File::Permissions | Int32) or File::Permissions, not String

Overloads are:
 - Crystal::System::File.open(filename : String, mode : String, perm : Int32 | ::File::Permissions, blocking)
 - Crystal::System::File.open(filename : String, flags : Int32, perm : ::File::Permissions, blocking _blocking)
```

</details>

新手会完全懵逼，不知道发生了什么！看上面第 15 行，会发现一些端倪。

```sh
def self.write(filename, content, perm = DEFAULT_CREATE_PERMISSIONS, encoding = nil, invalid = nil, mode = "w", blocking = true)
```
 

我们发现，File.write 方法的签名中第三个位置参数是 `perm = DEFAULT_CREATE_PERMISSIONS`, 这是不同于 Ruby 实现的。
这个参数要求的类型必须是 DEFAULT_CREATE_PERMISSIONS 而不是 String, 我们通过 mode = "a"，传递字符串 "a" 给 perm，
因此报错，正确的写法应该是使用位置无关的关键字参数：

```crystal
File.write("out.txt", "content", mode: "a")
```

### 同名，但是完全不同的含义

例如：

|		| Ruby				| Crystal
| ----	| ----				| -----
| alias	| 创建方法的别名	| 为（通常比较复杂的）类型定义一个别名
| $0	| 当前程序的名称	| 前一个正则匹配的内容字符串 (Ruby 中同样的东西是 $&)
| &.    | 短路运算符		|  block 调用简写形式
