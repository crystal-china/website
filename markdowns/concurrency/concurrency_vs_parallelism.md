# Concurrency vs. Parallelism

一部分内容翻译自 https://crystal-lang.org/reference/latest/guides/concurrency.html
有可能一部分信息已经过时了，会随时更正。


我们经常会谈起并行(in parallel)和并发（concurrent），他们其实是两个不同的东西。

一个并发的系统，是指能够处理多个任务的系统，虽然，不一定是同时执行的。

你可以想象自己在厨房做菜，你切一个洋葱，放到油锅里炸的同时，你再切一份番茄。
但是你并没有在同一时间做所有事情，你需要分配你的时间来做上面不同的事情，这是并发。
而并行，则是在同一时间，左手炸洋葱，右手切番茄。

截至这篇文章写作日期(2025年六月)，Crystal 已经完成了 execution context 的 
RFC 大部分开发，在 Crystal 1.16.3 中，已经可以直接使用类似于 golang 的 M:N 混合线程模型，
但是默认并没有开启，需要通过打开 -Dpreview_mt -Dexecution_context 编译时标记来开启。

在当前 1.X 版本 Crystal 中，除了语言的 GC（[Boehm GC](https://en.wikipedia.org/wiki/Boehm_garbage_collector)）使用单独的一个线程之外，
默认总是使用单线程模式执行，在未来的 2.X 版本中，会默认开启多线程模式。

下面介绍 Crystal 实现 concurrency 的一些基础概念：

## Fibers

Fiber 的概念，类似于 Erlang/Elixir, go 中轻量级用户线程, 不同于操作系统线程(Thread)
的`抢占式`( pre-emptive), 它是`协作式`(cooperative)的。

纤维（Fibers），与线程不同，是协作式的。线程是抢占式的：操作系统可以在任何时候中
断一个线程并开始执行另一个线程

- `轻量`，是因为它可以轻易创建成千上万，而相比较操作系统线程，非常少的开销，它虽然
  拥有一个与之关联的 8M 堆栈内存空间（和线程一样的），但是其初始只实际占用 4K 内存空间。

- `用户线程`，是因为它被程序语言自己管理，而不是由操作系统管理它。

- `协作式`，操作系统线程是抢占式，可以在任何时候中断一个线程并开始执行另一个线程, 
  而协作式，必须明确的通知运行时调度器，其可以切换到其他纤程。例如，如果一个协程需要
  等待 I/O 操作完成， 它会告诉调度器：“你看，我必须等待这个 I/O 操作可用，你可以
  继续执行其他协程，并在 I/O 准备好后回来唤醒我。”
  协作式的好处是，大量（不必要的）线程间切换的开销都消失了

Crystal 程序可以创建任意多的 Fiber, 在一个 64 位机器上，允许创建数百万个 Fiber，
而在 32 位机器上，只允许创建 512 个 Fiber。

Crystal 来确保在合适的时候执行它。

## Event loop 事件循环

event loop 与 IO 操作相关，当事件循环等待慢速的操作（例如，等待数据通过 socket 传输) 时，
程序可以执行其他的 fiber.

当所有 Fiber 空闲时，事件循环会检测是否有异步操作（例如：文件操作）准备好，如果有，
会执行等待这个操作的 fiber, 早期版本 event loop 使用 libevent（前者抽象了其他 event 
机制， 例如：epool、kqueue)。

但是，作为新的 Fiber 多线程支持的一部分，版本 1.15.0 开始，为 UNIX 兼容的系统
引入了一个[新的 Event Loop 实现](https://crystal-lang.org/2024/11/05/lifetime-event-loop), 自从 [this](https://github.com/crystal-lang/crystal/pull/14996) PR 被合并之后，的实现直接集成了
UNIX 的 systems selectors（Linux/Android 使用 epool，BSD/macOS 使用 kqueue）
因此 libevent 不再作为外部依赖。

## The Runtime Scheduler

Scheduler 有一个队列，负责：

1. 检查那些 fiber 需要被执行
2. 

1. Fibers ready to be executed: for example when you spawn a fiber, it's ready to be executed.

## 执行上下文(Execution Contexts)

一个执行上下文（Fiber::ExecutionContext ），创建并管理一个专门的 pool，
这个池关联一个或多个操作系统线程，需要时增加/减少 worker threads（以及对应的 schedulers）
通常一个 scheduler 绑定一个线程。

执行上下文主要负责管理如何运行，挂起，以及 fiber 在上下文内部的 Fiber 交换。

应用程序可以并行的创建任意多个执行上下文，它们彼此之间是隔离的。但是仍然可能通过
常见的线程安全的同步原语(synchronization primitives), 例如：Channel，Mutex 进行通讯。

一个执行上下文管理一组 Fibers。

- 在引入执行上下文之前，一个Fiber 总是关联一个线程。
- 现在，一个 Fiber 仅关联一个执行上下文，与线程解耦。

当使用 ::spawn 创建一个子纤程（Child fibers）时,  默认会加入 `当前纤程` 所在的执行上下文.
因此，默认情况下，子纤程会在与父纤程相同的上下文中执行，我们也可以手动发送一个 Fiber 
到其他（新建的）执行上下文去执行，但是 Fiber 一旦创建并属于某个上下文, 不可以转移
到其他执行上下文，挂起(suspend) 以及 恢复(resume) 操作只能在同一个执行上下文内部执行。

标准库实现了如下执行上下文实现：

### 并发原语

ExecutionContext::Concurrent 

这是当前默认模式

```crystal
Fiber::ExecutionContext.default.class # => Fiber::ExecutionContext::Concurrent
```

Fiber 支持完整的并发(concurrency)方式运行, 但绝不会并行(parallel)运行，即，在任意时间，
只会有一个 Fiber 正在运行。

它们可以在内部使用更简单、更快的同步原语（无需原子操作，有限的线程安全）。

与不同的 context 的 Fiber 进行通讯，必须通过线程安全原语，

一个繁忙的纤程，将会阻塞整个线程以及该上下文中的其他 Fiber 继续执行。

例如，你正在执行繁忙的 CPU 敏感性数学计算，同时想打印一个滚动条，是无法做到的。

### ExecutionContext::Parallel

Parallel Context: 

fibers will run in parallel and may be resumed by any thread, the number of schedulers and threads can grow or shrink, 
schedulers may move to another thread (M:N schedulers:threads) and steal fibers from each others; the advantage is that fibers that can run should be able to run, as long as a thread is available (i.e. no more starving threads) and we can be shrink the number of schedulers;

支持完整的并发、并行。

类似于 golang 的 [M:N concurrency](https://pauldigian.com/advanced-go-goroutines-the-basics#mn-concurrency) 的完整实现, 从 Crystal 角度来说，会同时启动
N 个操作系统线程，然后有 M 个 Fiber 在其上并行(parallel)执行。

- 一个 Fiber 可以被属于同一个 execution context 的不同的操作系统线程 suspend/resume。
- 属于同一个执行上下文的 Fibers 可以在不同的操作系统线程之上并行(parallel)
- 分属不同执行上下文你的 Fibers 也是并行(parallel)
- Work-stealing（工作窃取）
  同一个 Parallel context 内有多个 scheduler（通常各自绑定一个 worker thread）
  每个调度器维护自己的可运行 fiber 队列；当某个调度器手头没活了（队列空/快空），
  它会去别的调度器那里“偷”一些尚未执行的可运行 fiber 来跑
- Grow / shrink dynamically（动态扩缩容并行度）
  默认先启动 1 个线程/1 个 scheduler，随后按需（可能用启发式）最多扩到 System.cpu_count，
  并且未来可以在“活多”时加线程、“饥饿”时减线程，也可以手动通过 Parallel#resize 增加。

使用这种模式运行需要开启编译参数： -Dpreview_mt -Dexecution_context

在 Crystal 2.0，将会和 golang 一样，ExecutionContext::Parallel 作为默认。

### ExecutionContext::Isolated

Single fiber in a single system thread without concurrency. This is useful for tasks that can block thread execution for a long time (e.g. a GUI main loop, a game loop, or CPU heavy computation). The event-loop works normally (when the fiber sleeps, it pauses the thread). Communication with fibers in other contexts requires thread-safe primitives.

只允许一个 Fiber 在一个线程中执行，没有切换，无需调度，这特别适合那种高 CPU 负载，
（CPU heavy computation），或运行很长时间的任务，例如: GUI main loop, game loop。

当 Fiber sleep 之后，整个线程会暂停，因为它是 Thread 唯一的 Fiber

当需要和其他 execution context 通讯时，需要线程安全原语。

### 并发原语 ExecutionContext::Concurrent

Fibers 并发的（Concurrently) 运行，但是绝对不会并行(parallel)的运行，即：在同一个时间，
只有一个 Fiber 在执行中。

Fully concurrent with limited parallelism. Fibers run concurrently to each other, never in parallel (only one fiber at a time). They can use simpler and faster synchronization primitives internally (no atomics, limited thread safety). Communication with fibers in other contexts requires thread-safe primitives. A blocking fiber blocks the entire thread and all other fibers in the context.

## Channel

Channel 这个概念来自 [CSP](http://www.usingcsp.com/cspbook.pdf) ，它们允许光纤之间传递数据，无需共享内存，并且无需担
心锁（lock）、信号量（semaphores）或其他特殊结构。

# 执行一个程序

当程序启动时，首先会启动一个主Fiber（main fiber）来执行顶级(top-level)代码，
然后，会派生很多其他的 fiber 来执行下面的功能，它们包括：

1. 运行时调度器（Runtime Scheduler），负责所有的 fiber 在合适的时机执行。
2. 事件循环(Event Loop), 负责处理异步任务、例如：文件(file)，套接字(sockets)，
   管道(pipes)，信号(signals)以及定时器(timers, 例如：sleep)
3. 通道(Channel), 用于在 Fiber 之间传递数据，Runtime Scheduler 将协调 Fibers 和 
   Channels 以进行通讯。
4. 垃圾收集器(Garbage Collector): 清理不再使用的内存。（这个应该在一个单独的线程中执行？）

---------

下面是 golang 第一作者，来自 Google 的 Rob Pike 大神 2012 做的 slide 分享及对应视频版本。

[Concurrency is not Parallelism](https://go.dev/talks/2012/waza.slide) 及 [油管视频(带字幕)](https://www.youtube.com/watch?v=oV9rvDllKEg)

