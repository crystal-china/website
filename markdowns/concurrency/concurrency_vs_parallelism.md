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
计划在 1.20 版本中默认启用该功能！

在当前 1.X 版本 Crystal 中，除了语言的 GC（[Boehm GC](https://en.wikipedia.org/wiki/Boehm_garbage_collector)）使用单独的一个线程之外，
默认总是使用单线程模式执行，在未来的 2.X 版本中，会默认开启多线程模式。

下面介绍 Crystal 实现 concurrency 的一些基础概念：

## Fibers

Fiber 的概念，类似于 Erlang/Elixir, go 中轻量级用户线程, 不同于操作系统线程(Thread)
的`抢占式`( pre-emptive), 操作系统可以在任何时候中断一个线程并开始执行另一个线程,
而纤维（Fibers）是`协作式`(cooperative)的。

- `轻量`，是因为它可以轻易创建成千上万，而相比较操作系统线程，非常少的开销，它虽然
  拥有一个与之关联的 8M 堆栈内存空间（和线程一样的），但是刚创建时，实际只占用 4K 内存空间。

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
UNIX 的 systems selectors（Linux/Android 使用 epool，BSD/macOS 使用 kqueue，linux 的 io_uring 也在集成中）
因此 libevent 不再作为外部依赖。

## The Runtime Scheduler

Scheduler 有一个队列，负责：

1. 检查那些 fiber 需要被执行
2. 在一个单独的 Fiber 中，运行事件循环
3. 处理 Fiber 的主动请求等待，例如，通过 `Fiber.yield` 让出资源，可以理解为：
   “我可以继续执行，但如果其他协程想执行，你可以先运行它们”。

## 使用 Channel 进行数据通讯

一旦语言开启 parallelism，在多个 Fiber 中访问或修改一个实例变量，将变得不再安全。
建议的数据通讯方式是，使用 Channel 发送消息。一个 Channnel 内部实现了所有的锁机制
来避免 race 竞争

## 执行上下文(Execution Contexts)

一个执行上下文（Fiber::ExecutionContext ），创建并管理一个专门的 pool，
这个池关联一个或多个操作系统线程，需要时增加/减少 worker threads（以及对应的 schedulers）
通常一个 scheduler 运行在一个操作系统线程之上

执行上下文主要负责管理如何运行，挂起，以及 fiber 在上下文内部的 Fiber 交换。

应用程序可以并行的创建任意多个执行上下文，它们彼此之间是隔离的。但是仍然可能通过
常见的线程安全的同步原语(synchronization primitives), 例如：Channel，Mutex 进行通讯。

一个执行上下文管理一组 Fibers。

- 在引入执行上下文之前，一个Fiber 总是关联一个线程。
- 现在，一个 Fiber 仅关联一个执行上下文，与线程解耦。

当使用 ::spawn 创建一个子纤程（Child fibers）时, 默认 `当前纤程` 所在的执行上下文
所在的 Runnable fiber queues，因此，默认情况下，子纤程会在与父纤程相同的上下文中执行，
我们也可以手动发送一个 Fiber 到其他（新建的）执行上下文去执行（见后面 parallel 上下文例子）
但是 Fiber 一旦创建并属于某个上下文, 不可以转移到其他执行上下文，挂起(suspend) 以及 恢复(resume) 操作只能在同一个执行上下文内部执行。

标准库实现了如下执行上下文实现：

### 并行原语 ExecutionContext::Parallel

#### ExecutionContext::Parallel 

下面 executon context 简称 EC，Thread 特指操作系统线程。

会创建并管理一个由 1 个或多个 scheduler 组成的专用池。
EC 管理 scheduler 池, 并对 scheduler 在 thread 上运行进行调度 (M:N schedulers:threads)，

scheduler 不是绑定在某个 Thread 的执行单元，可以在不同 thread 上运行。

例如：

- 当 Fiber 数量上升时，随着对并行性的需求增加，将会激活更多的调度器（从而启动更多系统线程）
- 如果 Fiber 数量下降，并行性需求降低，调度器会暂停（不是退出），并行度下降。
  调度器对应的 Thread 咨询员可能被释放
- 当 Fiber 数量再次上升时，同一个调度器，可能关联另一个新起的操作系统线程。

这样做的好处是，scheduler 不必永远绑定某一个 thread，减少 thread 维护成本，这同样
也可以根据负载，动态的 增加/暂停 scheduler 的数量。

schedulers 和 Threads 的关系由 Crystal 运行时（EC) 自己维护的，

Fibers : Schedulers : Threads
   F        M           N
   
Fiber::ExecutionContext::Parallel.new("workers", 8) # 这里指定了 M 为 8
   
这里 M 是 scheduler 允许启动的最大数量（#capacity)，可能一开始只是启动了 2 个 scheduler, 
对应两个 thread，此时 N 就是 2 (#size)，然后运行过程中不断变大, 最大到 8。（见后面的示例代码）

M -> N 之间的关系是根据 Fiber 的数量及对并行需求的增加/降低，动态变化的, M >= N, 即：
Thread 数量 N 绝对不可能超过 scheduler 数量

#### scheduler 负责 fibers 的运行、挂起和切换。

同一个 EC 中，不同 scheduler 上运行的 fibers 可以 (in parallel )并行.
不同 execution contexts 中的 fibers 也可以并行运行。

fiber 不能跨 EC，但是同一个 Fiber 可能在生命周期中，在不同的 Thread 上运行。

这种同一个 Fiber 跨 Thread 运行的情况，又分为如下几种情况：

1. Fiber 没有跨 scheduler，但 scheduler 被 EC 调度到一个另一个线程
2. Fiber 跨同一个 EC 中的 scheduler，例如： 在 scheduler1 suspend，但是在 scheduler2
  (运行在另一个线程之上的) 上 resume，同一个 EC 内的 scheduler 之间 Work-stealing（工作窃取）
  是促成这种情况的机制之一。例如：当某个调度器手头没活了（队列空/快空），它会去同一个 
  EC 的别的调度器那里“偷” 一些尚未执行的可运行 fiber（以及子 fiber 树) 来跑。
  这带来的好处是，只要有可用的 Thread，那些可运行的 Fiber 总是能够更快被空闲 scheduler
  接手执行，提高负载均衡和并行利用率。

简单总结：每一个 EC 管理若干个 scheduler，每一个 scheduler 维护自己可运行 fibers 队列，
并运行在一个单独的 system thread 上, 因此，同一个 EC 的多个 scheduler 可以并行 (in parallel) 运行，
在概念上接近 golang 的 [M:N concurrency](https://pauldigian.com/advanced-go-goroutines-the-basics#mn-concurrency) 的实现

下面是一个例子：

```crystal
require "wait_group"

# 消费者创建 8 个 scheduler, 允许运行在最大 8 个 Thread 之上
consumers = Fiber::ExecutionContext::Parallel.new("consumers", 8)
puts "before spawn: size=#{consumers.size}, capacity=#{consumers.capacity}" # before spawn: size=0, capacity=8

channel = Channel(Int32).new(64) # 典型的，生产者 buffered channel 入队的场景。见 （1）
wg = WaitGroup.new(32) # 这里增加基数，确保执行 32 次 wg.done 之后，主 Fiber 才会退出。见 （2）,（3）

result = Atomic.new(0) # 因为是 parallel, 所以必须使用 Atomic 避免数据竞争、保证原子更新。

32.times do |i|
  consumers.spawn name: "fiber-#{i}" do # 新建一个 fiber, 并且加入到 consumers 这个 EC

    if sch = Fiber::ExecutionContext::Scheduler.current?
	  # 打印 debug 信息，看看到底有启动几个 scheduler
      puts "Fibers: [#{Fiber.current.name}] scheduler=#{sch.name} status=#{sch.status}"
    end

    while value = channel.receive?
      result.add(value)
    end
  ensure
    wg.done # (3) 每个 fiber 内，退出 while 才会执行 wg.done
  end
end

puts "after spawn: size=#{consumers.size}, capacity=#{consumers.capacity}" # after spawn: size=2, capacity=8，size 是变化的

1024.times { |i| channel.send(i) } # (1) 生产者入队

puts "after produce: size=#{consumers.size}, capacity=#{consumers.capacity}" # after produce: size=8, capacity=8，size 是变化的

channel.close # 入队完之后，关闭通道，最终，消费完后，channel.receive? 都会返回 nil

wg.wait  # (2) wait for all workers to be done

# after wait: size=8, capacity=8，size 是变化的，但是和 after produce 完全一致
#  因为 size 表示启动过(started)的线程，虽然活已经干完了，但这些线程/对应 scheduler 还没有被销毁，甚至可能只是空闲/暂停
puts "after wait: size=#{consumers.size}, capacity=#{consumers.capacity}" 

p result.get # => 523776，从 0 加 到 1023 的结果
```

它是非常典型的生产者/消费者模型：

producer -> buffered channel -> many consumers


初始状态：

scheduler0  (thread running)
scheduler1  (paused)
scheduler2  (paused)
scheduler3  (paused)

负载上升：

scheduler0  (thread running)
scheduler1  (thread running)
scheduler2  (paused)
scheduler3  (paused)

再上升：

scheduler0  (thread running)
scheduler1  (thread running)
scheduler2  (thread running)
scheduler3  (paused)

负载下降：

scheduler0  running
scheduler1  running
scheduler2  paused
scheduler3  paused

例如：scheduler 0 queue empty，steal fiber from scheduler 1

scheduler0: [f1 f2 f3]
scheduler1: []

变成：

scheduler0: [f2 f3]
scheduler1: [f1]



例如：

初始：

thread0 running scheduler0

负载增加：

thread0 running scheduler0
thread1 running scheduler1

再过一会儿：

thread1 idle -> 停止

之后 runtime 可能：

thread2 start
scheduler1 -> thread2 # 此时 scheduler1 关联的 thread2 而不是 thread1

为什么 runtime 这样设计？

scheduler pause
=> thread 必须存在

现在可以：

scheduler idle
=> thread 直接退出

目前计划在 1.20 版本中默认开启

The actual parallelism is controlled by the execution context. As the need for parallelism increases, for example more fibers running longer, the more schedulers will start (and thus system threads), as the need decreases, for example not enough fibers, the schedulers will pause themselves and parallelism will decrease.

The parallelism can be as low as 1, in which case the context becomes a concurrent context (no parallelism) until resized.

For example: we can start a parallel context to run consumer fibers, while the default context produces values. Because the consumer fibers can run in parallel, we must protect accesses to the shared value variable. Running the example without Atomic#add would produce a different result every time!

-------------

- 

- Grow / shrink dynamically（动态扩缩容并行度）
  默认先启动 1 个线程/1 个 scheduler，随后按需（可能用启发式）最多扩到 System.cpu_count，
  并且未来可以在“活多”时加线程、“饥饿”时减线程，也可以手动通过 Parallel#resize 增加。

使用这种模式运行需要开启编译参数： -Dpreview_mt -Dexecution_context

在 Crystal 2.0，将会和 golang 一样，ExecutionContext::Parallel 作为默认。

### 并发原语 ExecutionContext::Concurrent 

这是当前默认模式，他其实就是上面 M 参数为 1 的 ExecutionContext::Parallel

在同一个上下文中的 Fibers，可以并发的（Concurrently) 运行，但是绝对不会并行(parallel)的运行，
即：在同一个时间，只有一个 Fiber 在执行中。（虽然，多个不同 EC 下的 fiber 仍旧可以并行运行）

它们可以在内部使用更简单、更快的同步原语（无需原子操作，有限的线程安全），但是，
与不同的 context 的 Fiber 进行通讯，必须通过线程安全原语（例如：Channel)，并需要被保护 （例如：Mutex）

一个繁忙的纤程，将会阻塞整个线程以及该上下文中的其他 Fiber 继续执行。

下面是一个例子：

我们可以启动一个 concurrency 上下文来运行消费者纤程(consumer fiber)，而默认上下文则负责生成值。
由于消费者纤程永远不会 in parallel 运行，，因此我们无需同步对值的访问：

例如，你正在执行繁忙的 CPU 敏感性数学计算，同时想打印一个滚动条，是无法做到的。

```crystal
Fiber::ExecutionContext.default.class # => Fiber::ExecutionContext::Concurrent
```

并发原语（ExecutionContext::Concurrent ）继承自下面即将要要介绍得并行原语（ExecutionContext::Parallel）

我们可以将其看作仅允许单线程的并行原语的一个特例。

### ExecutionContext::Isolated

只允许一个 Fiber 在一个线程中执行，没有切换，无需调度，这特别适合那种高 CPU 负载，
（CPU heavy computation），或运行很长时间的任务，例如: GUI main loop, game loop。

当 Fiber sleep 之后，整个线程会暂停，因为它是 Thread 唯一的 Fiber

当需要和其他 execution context 通讯时，需要线程安全原语。

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

