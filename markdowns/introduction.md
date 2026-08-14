[Crystal Programming Langauge](https://crystal-lang.org/), 由 [Manas](https://manas.tech/) 的
[Ary Borenszweig @asterite](https://github.com/asterite) 作为一个业余个人项目在 **2012年9月4日** 被创建,
当前主要维护者是来自 manas 的 Johannes Müller [@straight-shoota](https://github.com/straight-shoota)
以及社区贡献。

Manas 是一家来自于阿根廷的软件服务公司，他们使用 **Ruby On Rails** 以及各种其他语言为客户交付项目，
而 Crystal 的诞生来源于一个想法，对程序员很友好的 Ruby 程序语言，常常被人诟病性能太差，
如果可以结合 Ruby 的良好可读性以及静态强类型语言的优点，性能是不是可以变得更好一些？

确实，Crystal 早期的宣传卖点主要是：`fast as C, Slick as Ruby` (速度和 C 语言一样快，代码和 Ruby 一样漂亮)

事实上，Crystal 的确是一个性能非常好的语言，在著名的 [Programming-Language-Benchmarks](https://programming-language-benchmarks.vercel.app/crystal) 上，
Crystal 在大部分 CPU 主导的测试中，性能介于 Go 和 Rust 之间。

现在不知道什么原因，部分核心开发者试图淡化 Crystal 与 Ruby 的关系，并尝试吸引非
Ruby 社区的开发者加入，甚至部分核心开发者认为学习 Crystal 是不必学习 Ruby 的，这点我**不认同**。
至少到目前 2024 年截至，大量的 Ruby 优秀图书仍旧是新手上手 Crystal 的最佳材料。事实上，[最早版本的 Crystal](https://github.com/asterite/crystal) 
的确是使用 Ruby 编写的，直到 14 个月之后的 **2013年11月14日** 才实现自举（即：使用 Crystal 编写 Crystal）

现在官方对 Crystal 的介绍如下：

 - 类似于 Ruby 的语法（但是兼容 Ruby 语法不是最终目标）
 - 静态类型检测 (但是变量或方法参数不必强制添加类型)
 - 调用 C 代码极其容易
 - 使用宏来在编译时生成代码，避免大量的模板代码重复。
 - 使用 llvm 编译到高性能 native 代码

但是，笔者（一个十年的老 Rubyist）认为，官方忽略了 Crystal 语言一个可能最重要特性！

## 空安全（Null Safety）

```info
> “I call it my billion-dollar mistake. It was the invention of the null reference in 1965.”

> At that time, I was designing the first comprehensive type system for references
in an object oriented language (ALGOL W). My goal was to ensure that all use of
references should be absolutely safe, with checking performed automatically by the compiler.
But I couldn't resist the temptation to put in a null reference, simply because
it was so easy to implement.

> This has led to innumerable errors, vulnerabilities, and system crashes, which have
probably caused a billion dollars of pain and damage in the last forty years.”

我在 1965 年发明的 null 引用我称之为 “我的十亿美元错误”。

当时，我正在设计第一个涵盖引用的完整面向对象的语言（ALGOL W）类型系统。我的目标是
确保所有引用的使用都应该绝对安全，由编译器自动执行检查。但是我没有抵制住加入
“null 引用” 的诱惑，因为它实现起来太简单了。

这一行为导致了不计数的错误、漏洞和系统崩溃，很可能在过去四十年造成数十亿美元的痛苦和损失！

<br>

----------------------------------------------- 图灵奖（1980）获得者

----------------------------------------------- `快速排序` 以及下面将要提及的 `CSP` 发明人

----------------------------------------------- 托尼·霍尔 （Tony Hoare）在 2019 年 QConf 上的演讲
```

写过 Ruby 或类似动态语言的对下面的错误应该一点儿都不陌生！

```bash
undefined method `???' for nil (NoMethodError)
```

Crystal 从一开始就设计了称作 `union type` 的类型系统，来尽可能的保证类型安全。

类似于 Rust, 编译器会在 **编译时** 最大限度捕获有关类型安全的错误，当编译通过时，
用户可以避免绝大部分的 **运行时空引用错误** 或 **类型错误**。

下面是一段 union 类型的示例。

```crystal
if true
  a = 1
else
  a = "hello"
end

a # : Int32 | String，代表 a 可能是一个 Int32 或 String

# 编译时（compile-time）类型，编译时类型检查使用这个结果
typeof(a) # => Int32 | String

# 返回运行时类型
a.class # => Int32

# 取消注释后编译时错误，因为 a 编译时类型可能是一个字符串，"hello", "hello" + 3 失败
# a + 3 # Error: expected argument #1 to 'String#+' to be Char or String, not Int32

# 取消注释后编译时错误，因为 a 编译时类型可能是一个数字，1 + "!" 失败
# a + "!" # Error: expected argument #1 to 'Int32#+' to be a Number, not String

a.inspect # 编译通过，因为 String 和 Int2 都有 inspect 方法
```

编译时的空引用 (nil) 检测

```crystal
if rand > 0.5
  a = "hello"
end

typeof(a) # (String | Nil)，或简写为 String?

a.size # Error: undefined method 'size' for Nil (compile-time type is (String | Nil))
```

``union type + 强大的类型自动推断（type inference)``, 让 Crystal 这样一门静态类型的编译型语言，
代码看起来和 Ruby 一样易读、漂亮的同时，还拥有极好的性能，以及强大的编译时类型安全检查，
这带来了一个额外的好处，只需编写非常少的测试（甚至不写测试）的情况下，做更大胆的重构，
笔者特别享受这种根据编译时错误驱动的开发模式，只要编译器通过通过之后，你已经解决了绝大多数有关
类型的错误，这当然也包括 Ruby 里面造成上面 “十亿美金错误” 的空引用(nil)错误。

另一个需要提及的 feature 是：

## 基于 [CSP](http://www.usingcsp.com/cspbook.pdf) 实现的并发原语 Concurrent Fiber

提起 CSP(Communicating Sequential Processes), 大多数接触过的人首先会想到 golang 的 goroutine/Chan。

```info
Crystal 同样从设计之初就使用 Fiber/Chanel 实现了同样的 CSP 模型。

没错，这就是 Ruby 一直想做，但是一直没做到的事情。

据说 Ruby 3.3 引入了基于 M:N 的 [Thread Scheduler](https://bugs.ruby-lang.org/issues/19842), 我还没有用过
```

这里强调一下 Crystal 语言在国内社区（例如某乎）上最被误解的一点，那就是 
**Crystal 不支持多线程**,这显然是对 Crystal 极大的误解。

Crystal __从一开始就支持和 Ruby 一样的多线程使用方式__，例如, 下面的代码一开始就像
Ruby 一样工作。

```crystal
thread1 = Thread.new { sleep 1 };
thread2 = Thread.new { sleep 2 };
thread3 = Thread.new { sleep 3 };

thread1.join
thread2.join
thread3.join
```

这里指的多线程其实是指的 Fiber，并且 `允许 Fibers 在多个线程之上同时执行`.

Crystal [早在 2019 年](https://crystal-lang.org/2019/09/06/parallelism-in-crystal/)，就实现了一个简单的基于多线程的 Fiber 实现，
但是其实现方式只是使用非常简单的轮询(round-robin fashion)方式，标准库也未完全为
Fiber 安全做好准备。

新的基于多线程的 Fiber 实现 [RFC0002](https://github.com/crystal-lang/rfcs/pull/2) 在社区成员的共同呼吁下，即将在 2025 年完成，

但是，作为新的 Fiber 多线程支持的一部分，版本 1.15.0 开始，为 UNIX 兼容的系统
引入了一个[新的 Event Loop 实现（已合并）](https://crystal-lang.org/2024/11/05/lifetime-event-loop), 它几乎完全重写，允许编写并发(concurrency)
的代码，并实际并行(parallel)的方式运行，而操作系统线程(Thread) 的概念，则完全被
隐藏了起来，成为了实现细节。

详情见 [concurrency](concurrency.md)

## Windows 支持

对于大部分之前了解过这门语言的开发者，Windows 支持可能是除了上面的多线程之外，呼声
最大的一个 feature，经过漫长的修改，以及对语言自身的重构（Crystal 需要考虑其他支持
的平台和 Windows 的统一接口），然后随着 [Coordinate porting to Windows](https://github.com/crystal-lang/crystal/issues/5430) 已经关闭，
所有的预定义 todo 已经完成，这意味这 Windows 支持已经接近完成，预计将来，Windows
支持将和 macOS, linux 一起作为 Tier 1 级别被支持。

我个人对 Windows 支持不怎么关注，而且对于 Crystal 背后这么小的核心团队（开始时所有人都
没有 Windows 开发背景），非要死磕 Windows 的决定是不支持的。我到现在也认为，这应该
是被部分 `上社区怒吼两声，为啥不支持 Windows`，然后此后再也消失不见的开发者误导的。

Ruby 发展这么多年了，我也算是个老人了，有人用 windows 做开发吗？ 应该很少吧。
反倒是，Crystal 早就应该集中更多的资源探索 [incremental compilation](https://forum.crystal-lang.org/t/incremental-compilation-exploration/5224) 以及更好的
LSP 支持（说起这点都是泪，看看 Dart, Go 和 Rust）


## 其他特性

其他提及的特性，包括：

- 类似于 Rust 的强大的编译时宏(macro)处理, Ruby 这种动态语言中的 method_missing, 模块的混入(mixin)，都是在编译时通过宏实现的
- Multiple dispatch 允许根据方法参数的名称、个数、类型不同，甚至方法返回值不同，来定义同名方法。

## 缺点

Crystal 的缺点也是非常明显的：

- 作为一个发源于阿根廷的小众程序语言，社区目前还很小，背后也没有金主爸爸
- 变量或方法参数不强制要求任何类型签名，Crystal 代码写起来完全就像一门动态语言，
  这是有代价的，模块化增量编译很难实现（甚至在不改变现有行为前提下，几乎是不可能的）
