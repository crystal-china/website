```info
Crystal 原生支持 `并发原语`，这可能是除了`编译语言性能`以及`类型安全`之外，最让人激动地事情。
```
自从 2024 年二月 25 日，[0002 有关执行上下文(execution context)草案](https://github.com/crystal-lang/rfcs/blob/rfc-0002-mt-execution-contexts/text/0002-execution-contexts.md) 被提交，
并被批准实现，来自法国的大神 Julien Portalier (@ysbaddaden) 开始了相关的开发。

[跟踪的 issues](https://github.com/crystal-lang/crystal/issues/15342) 被逐个的解决，随着 PR [RFC 2: ExecutionContext](https://github.com/crystal-lang/crystal/pull/15302) 的关闭
以及相关代码合并入 master 分支，从 Crystal 1.16.3 开始，我们已经可以通过新引入的
`Fiber::ExecutionContext::MultiThreaded` 开始体验和 golang [M:N Hybrid Threading Model](https://medium.com/@rezauditore/introducing-m-n-hybrid-threading-in-go-unveiling-the-power-of-goroutines-8f2bd31abc84)
一样的并行方案，**这是社区期待已久的一个功能！**

这一系列文章旨在使用最简单的语言，以及大量的例子，解释清楚 Crystal 如何设计使用
spawn 关键字原语，创建 Fibers(其他语言中的轻量级线程，例如，golang 中的 goroutine) 
实现并发，并通过 Channel 实现通讯，并在多个核之上并行的运行的。

下面分享几条有关 concurrency/parallelism 的铁律，如果你不理解没关系，看完所有文章
再回头看，你就会明白了。

```info
Concurrency is about struct, parallelism is about execution.

并发是一种程序结构设计方法，并行则是有关于如何执行。
```

```info
We do not write parallel code, only concurrent code that we hope will be run in parallel

parallelism is a property of the runtime of our program, not the code.

我们并不写并行代码，我们只按照某种方式编写并发代码, 它使得程序并行执行成为可能。

并行是我们程序的一个 `运行时` 可选项，跟代码无关（即，我们只需要 concurrency 的方式编写代码就够了）
```

```info
Do not communicate by sharing memory. Instead, share memory by communicating.

不要通过共享内存中数据来在进程间通讯，代之，通过通讯(即：Channel)来传递数据。
```

在之前的简介当中，有过关于 [CSP](http://127.0.0.1:3000/docs/introduction#anchor-%E5%9F%BA%E4%BA%8E%20) 的简单介绍，建议阅读相关 pdf 论文来试图了解它。

有一本书叫做 "concurrency in go"，也强烈推荐阅读。
