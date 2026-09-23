---
Feature Name: execution_contexts
Start Date: 2024-02-05
RFC PR: "https://github.com/crystal-lang/rfcs/pull/2"
Issue: "https://github.com/crystal-lang/crystal/issues/15342"
---

# 概述

重新设计 Crystal 中的 MT(multi-method support) 以提高效率.
例如, 在存在 sleeping 线程的时候, 总是避免 block 纤程, 同时允许开发者手动的
创建以及选择不同的 execution contexts 来运行 Fiber.

```info
这个特性灵感来自于: Golang 和 Kotlin
```

# 动机 (以及引入这个 RFC 之前，当前工作方式的分析)

## 术语

- **Thread**: 线程, 被操作系统管理的程序 ([wikipedia](https://en.wikipedia.org/wiki/Thread_(computing))).
- **Fiber**: 纤程, 可以 “暂停并稍后恢复” 的工作单元,  ([wikipedia](https://en.wikipedia.org/wiki/Coroutine)), 每个线程上可以同时运行多个纤程。
- **Scheduler**: 调度器，管理程序内部 Fiber 的执行，由 Crystal 内部控制，而非和线程一样，在程序之外由操作系统调度。
- **Event Loop**: 等待特定事件的抽象，例如： timer （等待一小段时间）或 IO （等待一个 socket 变得可读或可写的）
- **Multi-threaded (MT)**: 使用多个线程，Fiber 可以不同的 CPU 核心上并发的(concurrently)以及并行的(parallel)运行
- **Single-threaded (ST)**: 使用单个纤程，Fiber 无法并行(in parallel), 但是并发是可能的。

## 并发（Concurrency）

```info
本 RFC 主要讨论 parallelism, 这里仅快速总结一下 concurrency.
```

Fibers(纤程)，其他语言可能被称为 coroutines, lightweight-threds 或 user-threads，是 Crystal 中实现 concurrency 的基础。

Fiber 总是使用 block 方式来调用, 在 block 中的代码，在当前 Fiber 运行时中被执行，并且不会返回任何值 (这点不同于 Kotlin).
纤程中如果有操作导致 block，当前纤程被 blocked 并挂起（suspended)，在稍后 blocked 操作恢复后，纤程可以被恢复（resume).

这里需要理解的关键是，当一个纤程 A 挂起时，另一个纤程 B 会被自动运行，并在 B block 或执行完成之后，等待 event-loop 报告
是继续执行下一个 Fiber C 还是，恢复前一个纤程或其他纤程的运行。

在并发场景下，一个操作系统纤程，可以同时关联很多个纤程，这意味着，可能同一时间总有一个纤程在运行，这就是 concurrency.

例如，以常见的 IO 操作为例，假设我们从一个 socket 读取内容，高速的处理器需要等待慢速的 IO 返回数据，从开发者角度来看，
这个操作是 block 的，此时 CPU 如果什么都不做等待 IO 完成，完全是 CPU 资源的浪费，在并发(concurrency)场景下，此时，
访问 IO 操作的 Fiber 会立即挂起，释放操作系统线程资源去完成其他任务，等 IO 数据返回后，再立即切换回来继续执行。

纤程是 cooperative（协作式的），无法从程序外部中断或抢占，但是纤程所在的线程它自己有可能被操作系统中断或抢占，
进而阻塞在该线程上运行的所有纤程。

不过 “纤程无法被抢占” 并非并发模型的一部分。在未来的演化中，有可能实现，程序内部主动抢占运行时间过长的纤程，
或者在可抢占的点上要求它们主动让出执行权。

Fiber 的创建以及切换都是非常轻量的。

## 并行（Parallelism）

新派生(spawning) 的 fiber 可以可选的允许在当前线程上派发新的 Fiber，来将一些纤程分组在一起，
或者使用简单的轮询(robin-ish) 方式（无法手动指定），派发到某个正在运行的随机线程上。

当前实现，一个 Fiber 只能在之前挂起(suspend)的线程上被恢复(resume)，不可能恢复到另一个线程上。

Thread <=> scheduler <=> event loop(queue)，当前实现它们之间都是 `唯一的一对一` 关系。

从逻辑角度来说，Fiber 应该总是属于一个 scheduler，反倒不太关心具体在那个线程上运行。
因为，也许将来某个实现，Thread 和 scheduler 之间，并非一一对应, 而是 [golang M:N scheduler](https://medium.com/@rezauditore/introducing-m-n-hybrid-threading-in-go-unveiling-the-power-of-goroutines-8f2bd31abc84) 的关系。 
一个 Fiber 恢复时， scheduler 可能选择最空闲的线程，而这个线程和之前挂起时的线程可能是不同的线程。

在不同线程之上运行的 Fibers 可以并行(in parallel) 运行, 但是同一个线程之上运行的
一组纤程，可以并发（concurrency）的方式运行，但是永远不会并行（in parallel）。

同一个线程之上运行的一组纤程，如果操作同一数据，那么这些数据会在 CPU cache 中缓存以提高性能。

如果线程数超过 CPU 可利用线程的数量，或者操作系统非常忙碌，带来大量线程切换，
并不会提高性能，反而有害于性能。

### Fiber 分组

在同一个 Thread 之上运行的一组 Fiber 无法并发(in parallel), 这极大的简化了逻辑，并且
更加快速，因为你不需要担心同组 Fiber 之间的原子同步操作。

## Issues

1. 新派生的 Fiber 使用简单的轮询方式来选择一个新的线程，这有一个问题，它不考虑忙碌的线程，
   Fiber 可能被派发到一个繁忙的线程之上，而同时，另一个线程空闲。

2. scheduler 会等待处理 event loop(queue) 上的事件，当 queue 为空时，这个饥饿的线程
(starving thread) 会立即进入睡眠状态, 甚至其他线程非常忙碌的情况下，而新的 Fiber 
可能继续不断的入队繁忙线程的队列。


### CPU bound fiber blocks other fibers queued on the same thread/scheduler

如果当前 Fiber 是一个 CPU 密集型（CPU bound) 任务, 执行过程中可能没有 `可抢占点`
（preemptible point）来允许同一个分组的其他 Fibers 执行, 显然这些被 blocked 的 
fibers 也没有机会在其他线程上被执行。

最坏的情况下，整个应用程序等待一个 CPU 密集型 fiber 执行完成，而其他有负载的 fibers 
一直被阻塞，这限制了并行性。（理想情况下，负载 Fiber 应该尽可能分布在不同的线程之上）

## 限制

### 无法在运行时控制 threads/scheduler 的数量

目前没有提供 API 来指定初始 threads/schedulers 的数量，也无法调整大小。
变大其实不是一个问题，但是变小，不得不等待 queue 为空才能停止线程。
如果一个 Fiber 执行的是长期 (long running) 操作, 例如：信号处理循环，或日志处理(logger),
这个线程根本无法被停止掉。

### 无法启动一个没有 scheduler/event-loop 的线程

创建一个线程时（例如通过未公开的类似于 Ruby 用法的 Thread.new 方法），也会自动创建对应的
scheduler/event-loop，这样做会引发许多复杂的潜在问题。

下面的话不好翻译，继续引用原内容

```info
Technically we can (`Thread.new` is undisclosed API but can be called), 
yet calling anything remotely related to fibers or the event-loop is dangerous as 
it will immediately create a scheduler for the thread, and/or an event-loop for
that thread, and possibly block the thread from doing any progress if the thread 
puts itself to sleep waiting for an event, or other issues.
```

一个可能的解决方案是，允许创建 `bare` 线程，当在这样的线程之上 spawning a fiber, 
新派发的 Fiber 会被发送到其他线程或直接抛异常。

### Fiber 无法独占一个线程

有时候，我们需要一个 fiber 在一个线程之上独占运行一段时间，或一直运行，在运行期间，
不可以有新的 Fiber 被调度到这个线程，例如：

1. GTK 或 QT 用来处理来自于 UI 组件的 callback 的主循环，需要和 Crystal 程序的其他部分通讯，
   必须在一的单独的线程运行。
2. 耗时的，CPU-bound 的任务（例如计算一个 BCrypt 密码哈希）会阻塞在同一个线程之上运行的其他纤程。
Fiber 可以被设计为一个独立于线程的纤程，它可以在某个线程上运行一段时间，或一直运行。

当前模式下，无法做到，当前线程被独占，运行专门的纤程，同时将 scheduler 以及其他纤程
移动到新的线程，如果可以，那么专门的纤程和移动的其他纤程是并行，这破坏了纤程之间因该并发的约定。

# 当前提案 (指南级别的解释)

综合考虑当前方案的优点（局部性）以及缺点（阻塞 fiber), 我提案打破 “一个 fiber 只能
被同一个线程 resume” 的约定，代之，一个 fiber 可以在任意线程之上 resume 。

这使得更多的优化场景成为可能，例如：现代多线程模型的工作窃取(work stealing)，允许空闲的
纤程窃取其他线程的任务队列中的任务，可以有效解决单个线程空闲、其他线程任务繁重的负载不均问题。

这个实现，不必是一个类似于 go 提案的，一个支持 work stealing 的单个 MT 环境，代之，
在运行时，在运行时可以动态创建新的环境。

## 执行上下文的分类

下面是标准库中实现的执行上下文:

**单线程上下文**

所有的 Fiber 不会并行运行，而是使用我们已知的正常的 concurrency 并发原语。
缺点：一个 blocking fiber 将会阻塞当前线程，其他 Fiber 无法继续执行。

**多线程上下文**

Fiber 在多个线程上并行运行，并且挂起后可以被再恢复到任何一个线程上。
scheduler 和 thread 可以动态增长、减少，并且 scheduler 可以转移到其他线程之上(M:N 模型)，
并且线程之间可以 steal fibers。

这种方式的优点是：只要操作系统线程资源可用，可以运行的 Fiber 一定会在某个线程之上运行。

**隔离上下文**

这样的线程之上，只有一个 fiber 被允许运行，独占线程的全部资源，没有竟态条件，也无需
concurrency, 例如：GUI主循环（Git.main）, 游戏循环(game loop) 以及 CPU 密集型计算
（ CPU heavy computation），使用隔离上下文，可以避免这些任务被打扰。

当创建一个隔离上下文时，可以指定一个 context 作为默认 Fiber 将要发送到的上下文。 
默认是： `Fiber::ExecutionContext.default`

一些细节:

- 上面的列表不是互斥的，你可以创建一个不同于以上任意规则的上下文，例如：多线程，i
  但是不开启 work stealing

- 一个应用程序可以并行的启动任意多的 context

- context 应该是可包装的（wrappable), 允许开发者在现有的 context 之上新增方便的功能，
  例如：监控 Fiber, 并在 Fiber 执行完之后，自动关闭它。例如：允许额外添加 monitor 功能来自动关闭

## 默认执行上下文

当 Fiber 被派生时，Crystal 默认会启动一个包含 work-stealing 能力的多线程（MT）context.

这个默认上下文提供一个满足绝大多数用例的环境，除了针对 concurrency 访问外部资源
需要特别注意之外，或者开发者只需要通过首选的 Channel 方式通讯，开发者就可以在无需
过多考虑如何利用多核的情况下，就可以很好的使用多核。

执行上下文可以配置仅使用一个线程，因此关闭了默认 context 内部并行能力。然而，仍旧
可以和其他 context 并行运行！

```info
直到 Crystal 2.0 之前，默认的 execution context 仍然是单线程（ST）模式。
需要一个编译时选项，例如：-Dmt 来让默认 context 使用多线程模式。
```

## 额外的执行上下文

应用程序可以创建除了默认执行上下文之外其他执行上下文。

这些执行上下文配置为不同的行为，例如，使用 ST 模式，或隔离上下文，甚至允许调整
`线程优先级` 及 `CPU 相关性`, 以便于在 CPU 内核上更好的分配。

理想情况下，开发者可以自己实现一个定制的上下文，或包装一个现有的上下文以增强它。

## 可以实现的方案演示

1. 我们可以创建完全隔离的单线程执行上下文，这和当前 MT 实现类似（当前 MT 就类似于
   多个独立的单线程执行上下文）

2 我们可以建立一个专门用来处理 UI 或 游戏循环的 execution context，然后使用默认的
context来处理复杂的计算或处理 Web 请求，彼此不影响，UI 会会被卡住。

3. 创建一个单独的 MT execution context 专门执行 CPU 密集算法（例如，BCrypt)，这将
   阻塞当前线程，并且允许操作系统抢占线程，而默认的上下文（例如 Web 应用登录）就不会
   在成千上万用户同时尝试登录时（需要使用 BCrypt 算法验证密码），被阻塞。

4. Crystal 编译器在 parsing 以及 semantic 阶段不需要 MT, 因此我们可以配置这些阶段
 的 execution context 只使用一个独占的线程，当进入 codegen 阶段时，选择另一个支持
 MT 的 context，当  spawn fiber 时使用尽可能多的 Thread 和 CPU。

5. 不同的上下文可能具有不同的优先级和偏好，以便操作系统能够在异构计算架构
   （例如 ARM big.LITTLE）中更高效地分配线程

# Reference-level explanation

An execution context shall provide:

- configuration (e.g. number of threads, …);
- methods to spawn, enqueue, yield and reschedule fibers within its premises;
- a scheduler to run the fibers (or many schedulers for a MT context);
- an event loop (IO & timers):

  => this might be complex: I don’t think we can share a libevent across event bases? we already need to have a “thread local” libevent object for IO objects as well as for PCRE2 (though this is an optimization).

  => we might want to move to our own primitives on top of epoll (Linux) and kqueue (BSDs) since we already wrap IOCP (Win32) and a PR for `io_uring` (Linux) so we don’t have to stick to libevent2 limitations (e.g. we may be able to allocate events on the stack since we always suspend the fiber).

Ideally developers would be able to create custom execution contexts. That means we must have public APIs for at least the EventLoop and maybe the Scheduler (at least its resume method), which sounds like a good idea.

In addition, synchronization primitives, such as `Channel(T)` or `Mutex`, must allow communication and synchronization across execution contexts, and thus be thread-safe.

## Changes

```crystal
class Thread
  # reference to the current execution context
  property! execution_context : Fiber::ExecutionContext

  # reference to the current MT scheduler (only present for MT contexts)
  property! execution_context_scheduler : Fiber::ExecutionContext::Scheduler

  # reference to the currently running fiber (simpler access + support scenarios
  # where a whole scheduler is moved to another thread when a fiber has blocked
  # for too long: the fiber would still need to access `Fiber.current`).
  property! current_fiber : Fiber
end

class Fiber
  def self.current : Fiber
    Thread.current.current_fiber
  end

  def self.yield : Nil
    ::sleep(0.seconds)
  end

  property execution_context : Fiber::ExecutionContext

  def initialize(@name : String?, @execution_context : Fiber::ExecutionContext)
  end

  def enqueue : Nil
    @execution_context.enqueue(self)
  end

  @[Deprecated("Use Fiber#enqueue instead")]
  def resume : Nil
    # can't call Fiber::ExecutionContext#resume directly (it's protected)
    Fiber::ExecutionContext.resume(self)
  end
end

def spawn(*, name : String?, execution_context : Fiber::ExecutionContext = Fiber::ExecutionContext.current, &block) : Fiber
  Fiber.new(name, execution_context, &block)
end

def sleep : Nil
  Fiber::ExecutionContext.reschedule
end

def sleep(time : Time::Span) : Nil
  Fiber.current.resume_event.add(time)
  Fiber::ExecutionContext.reschedule
end
```

And the proposed API. There are two distinct modules that each handle a specific
parts:

1. `Fiber::ExecutionContext` is the module aiming to implement the public facing API,
   for context creation and cross context communication; there can only be one
   instance object of an execution context at a time.

2. `Fiber::ExecutionContext::Scheduler` is the module aiming to implement internal API
   for each scheduler; there should be one scheduler per thread, and there may
   be one or more schedulers at a time for a single execution context (e.g. MT).

There is some overlap between each module, especially around spawning and
enqueueing fibers, but the context they're expected to run differ: while the
former need thread safe methods (i.e. cross context enqueues), the latter can
assume thread local safety.

```crystal
module Fiber::ExecutionContext
  # the default execution context (always started)
  class_getter default = MultiThreaded.new("DEFAULT", size: System.cpu_count.to_i)

  def self.current : ExecutionContext
    Thread.current.execution_context
  end

  # the following methods delegate to the current execution context, they expose
  # the otherwise protected instance methods which are only safe to call on the
  # current execution context:

  # Suspends the current fiber and resumes the next runnable fiber.
  def self.reschedule : Nil
    Scheduler.current.reschedule
  end

  # Resumes `fiber` in the execution context. Raises if the fiber
  # doesn't belong to the context.
  def self.resume(fiber : Fiber) : Nil
    if fiber.execution_context == current
      Scheduler.current.resume(fiber)
    else
      raise RuntimeError.new
    end
  end

  # the following methods can be called from whatever context and must be thread
  # safe (even ST):

  abstract def spawn(name : String?, &block) : Fiber
  abstract def spawn(name : String?, same_thread : Bool, &block) : Fiber
  abstract def enqueue(fiber : Fiber) : Nil

  # the following accessors don’t have to be protected, but their implementation
  # must be thread safe (even ST):

  abstract def stack_pool : Fiber::StackPool
  abstract def event_loop : Crystal::EventLoop
end

module Fiber::ExecutionContext::Scheduler
  def self.current : ExecutionContext
    Thread.current.execution_context_scheduler
  end

  abstract def thread : Thread
  abstract def execution_context : ExecutionContext

  # the following methods are expected to only be called from the current
  # execution context scheduler (aka current thread):

  abstract def spawn(name : String?, &block) : Fiber
  abstract def spawn(name : String?, same_thread : Bool, &block) : Fiber
  abstract def enqueue(fiber : Fiber) : Nil

  # the following methods must only be called on the current execution context
  # scheduler, otherwise we could resume or suspend a fiber on whatever context:

  protected abstract def reschedule : Nil
  protected abstract def resume(fiber : Fiber) : Nil

  # General wrapper of fiber context switch that takes care of the gc rwlock,
  # releasing the stack of dead fibers safely, ...
  protected def swapcontext(fiber : Fiber) : Nil
  end
end
```

Then we can implement a number of default execution contexts. For example a
single threaded context might implement both modules as a single type, taking
advantage of only having to deal with a single thread. For example:

```crystal
class SingleThreaded
  include Fiber::ExecutionContext
  include Fiber::ExecutionContext::Scheduler

  def initialize(name : String)
    # todo: start one thread
  end

  # todo: implement abstract methods
end
```

A multithreaded context should implement both modules as different types, since
there will be only one execution context but many threads that will each need a
scheduler. For example:

```crystal
  class MultiThreaded
    include Fiber::ExecutionContext

    class Scheduler
      include Fiber::ExecutionContext::Scheduler

      # todo: implement abstract methods
    end

    getter name : String

    def initialize(name : String, @size : Int32)
      # todo: start @size threads
    end

    def spawn(name : String?, same_thread : Bool, &block) : Fiber
      raise RuntimeError.new if same_thread
      self.spawn(name, &block)
    end

    # todo: implement abstract methods
  end
```

Finally, an isolated context could extend the singlethreaded context, taking
advantage of its —in practice we might want to have a distinct implementation
since we should only have to deal with two fibers (one isolate + one main loop
for its event loop).

```crystal
class Isolated < SingleThreaded
  def initialize(name : String, @spawn_context = Fiber::ExecutionContext.default, &@func : ->)
    super name
    @fiber = Fiber.new(name: name, &@func)
    enqueue @fiber
  end

  def spawn(name : String?, &block) : Fiber
    @spawn_context.spawn(name, &block)
  end

  def spawn(name : String?, same_thread : Bool, &block) : Fiber
    raise RuntimeError.new if same_thread
    @spawn_context.spawn(name, &block)
  end

  # todo: prevent enqueue/resume of anything but @fiber
end
```

### Example

```crystal
# (main fiber runs in the default context)
# shrink the main context to a single thread:
Fiber::ExecutionContext.default.resize(maximum: 1)

# create a dedicated context with N threads:
ncpu = System.cpu_count
codegen = Fiber::ExecutionContext::MultiThreaded.new(name: "CODEGEN", minimum: ncpu, maximum: ncpu)
channel = Channel(CompilationUnit).new(ncpu * 2)
group = WaitGroup.new(ncpu)

spawn do
  # (runs in the default context)
  units.each do |unit|
    channel.send(unit)
  end
end

ncpu.times do
  codegen.spawn do
    # (runs in the codegen context)
    while unit = channel.receive?
      unit.compile
    end
  ensure
    group.done
  end
end

group.wait
```

## Breaking changes

The default execution context moving from 'a fiber is always resumed on the same thread" to the more lenient 'a fiber can be resumed by any thread", this introduces a couple breaking changes over `preview_mt`.

1. Drop the "one fiber will always be resumed on the same thread" assumption, instead:
   - limit the default context to a single thread (disabling parallelism in the default context);
   - or start an additional, single threaded, execution context.

2. Drop the `same_thread` option on `spawn`, instead:
   - limit the default context to a single thread (disables parallelism in the default context);
   - or create a single-threaded execution context for the fibers that must live on the same thread.

3. Drop the `preview_mt` flag and make execution contexts the only compilation mode (at worst introduce `without_mt`):
   - one can limit the default context to a single thread to (disabling parallelism at runtime);
   - sync primitives must be thread-safe, because fibers running on different threads or in different execution contexts will need to communicate safely;
   - sync primitives must be optimized for best possible performance when there is no parallelism;
   - community maintained shards may propose alternative sync primitives when we don’t want thread-safety to squeeze some extra performance inside a single-threaded context.

4. The `Fiber#resume` public method is deprecated because a fiber can't be resumed into any execution context:
   - shall we raise if its context isn't the current one?
   - shall we enqueue into the other context and reschedule? that would change the behavior: the fiber is supposed to be resumed _now_, not later, and the current fiber could be resumed before it (oops);
   - the feature is also not used in the whole stdlib, and only appears within a single spec;
   - raising might be acceptable, and the deprecation be removed if someone can prove that explicit continuations are interesting in Crystal.

> [!NOTE]
> The breaking changes can be postponed to Crystal 2 by making the default execution context be ST, keep supporting `same_thread: true` for ST while MT would raise, and `same_thread: false` would be a NOOP. A compilation flag can be introduced to change the default context to be MT in Crystal 1 (e.g. keep `-Dpreview_mt` but consider just `-Dmt`). Crystal 2 would drop the `same_thread` argument, make the default context MT:N, and introduce a `-Dwithout_mt` compilation flag to return to ST to ease the transition.
>
> Alternatively, since the `-Dpreview_mt` compilation flag denotes an experimental feature, we could deprecate `same_thread` in a Crystal 1.x release, then make it a NOOP and set the default context to MT:1 in a further Crystal 1.y release. Crystal 2 would then drop the `same_thread` argument and change the default context to MT:N.

# Drawbacks

Usages of the `Crystal::ThreadLocalValue` helper class might break with fibers moving across threads. We use this because the GC can't access the Thread Local Storage space of threads. Some usages might be replaceable with direct accessors on `Thread.current` but some usages link a particular object instance to a particular thread; those cases will need to be refactored.

- `Reference` (`#exec_recursive` and `#exec_recursive_clone`): a fiber may be preempted and moved to another thread while detecting recursion (should be a fiber property?)...

> [!CAUTION]
> This might actually be a bug even with ST: the thread could switch to another fiber while checking for recursion. I assume current usages are cpu-bound and never reach a preemptible point, but still, there are no guarantees.

- `Regex` (PCRE2): not affected (no fiber preemption within usages of JIT stack and match data objects);

- `IO::Evented`: will need an overhaul depending on the event loop details (still one per thread? or one per context?);

> [!WARNING]
> The event loop will very likely need an interface to fully abstract OS specific details around nonblocking calls (epoll, kqueue, IOCP, io_uring, …). See [#10766](https://github.com/crystal-lang/crystal/issues/10766).

# Rationale and alternatives

The rationale is to have efficient parallelism to make the most out of the CPU cores, to provide an environment that should usually work, yet avoid limiting the choices for the developer to squeeze the last remaining drops of potential parallelism.

The most obvious alternative would be to keep the current MT model. Maybe we could fix a few shortcomings, for example shrink/resize, start a thread without a scheduler, allow fibers non explicitly marked as same thread to be moved across threads (though it might be hard to efficiently steal fibers), ...

Another alternative would be to implement Go's model and make it the only possible environment. This might not be the ideal scenario, since Crystal can't preempt a fiber (unlike Go) having specific threads might be a better solution to running CPU heavy computations without blocking anything (if possible).

One last, less obvious solution, could be to drop MT completely, and assume that crystal applications can only live on a single thread. That would heavily simplify synchronization primitives. Parallelism could be achieved with multiple processes and IPC (Inter Process Communication), allowing an application to be distributed inside a cluster.

# Prior art

As mentioned in the introduction, this proposal takes inspiration from Go and Kotlin ([coroutines guide](https://kotlinlang.org/docs/coroutines-guide.html)).

Both languages have coroutines and parallelism built right into the language. Both declare that coroutines may be resumed by whatever thread, and both runtimes expose an environment where multiple threads can resume the coroutines.

**Go** provides one execution context: their MT optimized solution. Every coroutine runs within that global context.

**Kotlin**, on the other hand, provides a similar environment to Go by default, but allows to [create additional execution contexts](https://kotlinlang.org/docs/coroutine-context-and-dispatchers.html) with one or more threads. Coroutines then live inside their designated context, which may each be ST or MT.

The **Tokio** crate for **Rust** provides a single-threaded scheduler or a multi-threaded scheduler (with work stealing), but it must be chosen at compilation time. Apparently the MT scheduler is selected by default (to be verified).

# Unresolved questions

## Introduction of the feature

The feature will likely require both the `preview_mt` and `execution_contexts` flags for the initial implementations.

~~Since it is a breaking change from stable Crystal, unrelated to `preview_mt`, MT and execution contexts may only become default with a Crystal major release?~~

~~Maybe MT could be limited to 1 thread by default, and `spawn(same_thread)` be deprecated, but what to do with `spawn(same_thread: true)`?~~

## Default context configuration

This proposal doesn’t solve the inherent problem of: how can applications configure the default context at runtime (e.g. number of MT schedulers) since we create the context before the application’s main can start. 

We could maybe have sensible defaults + lazily started schedulers & threads, which means that the default context would only start 1 thread to run 1 scheduler, then start up to `System.cpu_count` on demand (using some heuristic).

The application would then be able to scale the default context programmatically, for example to a minimum of 4 schedulers which will immediately start the additional schedulers & threads.

# Future possibilities

MT execution contexts could eventually have a dynamic number of threads, adding new threads to a context when it has enough work, and removing threads when threads are starving (always within min..max limits). Ideally the threads could return to a thread pool (up to a total limit, like GOMAXPROCS in Go) and be reused by other contexts.
