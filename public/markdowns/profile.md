正如在 [不要过早的优化](/docs/for_advanced_rubyists/performances#anchor-不要过早的优化) 中提到的那样，
macOS 和 Linux 都有一些很不错的 profile 工具，来帮助查找程序的性能瓶颈。

因为我使用 Linux ，这里以 Arch Linux，介绍使用方法。

## perf（Linux 内核自带的性能分析工具）

### 安装

```bash
sudo pacman -S perf
```

这同时会安装部分依赖，例如：elfutils libelf 等。

### 编译可执行文件

我们以本站用到的依赖包 [tartrazine](https://github.com/ralsina/tartrazine) 工具为例。

```bash
git clone https://github.com/ralsina/tartrazine
```

```bash
cd tartrazine && git checkout v0.1.0
```

```bash
shards install
```

```bash
crystal build --debug --release src/main.cr -o ./main
```

此时，可以看到可执行文件 `./main` 被创建了，这里有两点要注意：

- 总是开启 `--debug` 选项，这样才会拥有完整的调试符号信息（等价于 gcc -g 或 clang -g）
- 总是开启 `--release`，来找出**真正的瓶颈**在哪里。因为 llvm 会做很多深层次优化，你以为的
  瓶颈，可能已经被内联并优化了，不打开这个选项，结果可能差别很大。

### 使用 perf record 采集性能数据

```bash
perf record --call-graph dwarf -- ./main ./src/tartrazine.cr abap
```

执行此命令时，perf 将运行 `./main` 并记录性能相关的事件，比如 CPU 周期、指令执行、缓存命中率等，
以及采样调用栈（如果启用调用栈捕获的话），它最终会生成一个记录文件，通常命名为 `perf.data`。

这里我们通过 `--call-graph` 来指定 `采集调用栈` 的方式，dwarf 是一种基于 DWARF 调试信息的收集方法，
允许更细粒度和更准确的调用栈采样，它能函数的调用路径和调用关系，支持更复杂的优化代码，但可能会带来一定的性能开销。

### 查看结果

此时可以直接使用 perf report 查看结果。

```bash
perf report -g graph --no-children
```

大概会看到这个样子的结果

<details>
<summary>perf report 输出</summary>

```text
Samples: 6K of event 'cycles:Pu', Event count (approx.): 7418497477
  Overhead  Command  Shared Object         Symbol
+   47.21%  main     main                  [.] *String::char_bytesize_at<Pointer(UInt8)>:Int32                                                               ◆
+   21.24%  main     main                  [.] *Pointer(UInt8)@Pointer(T)#+<Int32>:Pointer(UInt8)                                                            ▒
+   13.83%  main     main                  [.] *String#char_index_to_byte_index<Int32>:(Int32 | Nil)                                                         ▒
+    6.24%  main     main                  [.] *String#char_bytesize_at<Int32>:Int32                                                                         ▒
+    3.03%  main     libpcre2-8.so.0.13.0  [.] 0x0000000000067ddb                                                                                            ▒
+    2.70%  main     libpcre2-8.so.0.13.0  [.] 0x0000000000067de1                                                                                            ▒
+    2.49%  main     main                  [.] *String#to_unsafe:Pointer(UInt8)                                                                              ▒
     0.29%  main     main                  [.] *String#byte_index_to_char_index<Int32>:(Int32 | Nil)                                                         ▒
     0.17%  main     libpcre2-8.so.0.13.0  [.] pcre2_match_8                                                                                                 ▒
     0.14%  main     main                  [.] *Hash(Thread, Pointer(LibPCRE2::MatchData))@Hash(K, V)#find_entry_with_index_linear_scan<Thread>:(Tuple(Hash::▒
     0.13%  main     libgc.so.1.5.4        [.] 0x000000000000970e                                                                                            ▒
     0.10%  main     libgc.so.1.5.4        [.] 0x0000000000009718                                                                                            ▒
     0.09%  main     main                  [.] *Regex+@Regex::PCRE2#match_data<String, Int32, Regex::MatchOptions>:(Pointer(LibPCRE2::MatchData) | Nil)      ▒
```

可以看到，perf 随机采样了大约 6000 条数据，数据类型是 CPU 的时钟周期(clock cycle)，
并根据采样估算总共消耗了 74.18 亿个 CPU 时钟周期。

P 是尽可能精确的采样，u 是用户态(user space), 排除掉内核态，只统计用户程序运行期间的事件

这里可以发现，程序大约 47.21% 的 CPU 时钟周期时间 消耗在 `String::char_bytesize_at` 这个方法/函数上，
明显不正常，为主要性能瓶颈。

</details>

可选的，如果你更喜欢火焰图，可以使用下面的代码生成它，然后使用浏览器查看。


```bash
perf script | stackcollapse-perf.pl | flamegraph.pl > perf.svg
```

你可以在 [FlameGraph github 页面](https://github.com/brendangregg/FlameGraph) 找到所需的 perl 脚本。

## 使用 hotspot 分析 perf.data

如果你的系统可以安装有 [hotspot](https://github.com/KDAB/hotspot) 一款用来分析
perf 的 GUI 工具，你可以使用它来直接打开 `./perf.data` 进行分析.

点击这个软件的 bottom-up (自底向上) 选项卡，你会看到很多行函数符号名称。
按照它们所消耗的 CPU 时钟周期，从高往低排序，一眼就可以找出性能问题最大的底层函数。

然后可以右击鼠标，选择 `View Caller/Callee`，打开对应选项卡，查看这些高耗时的代码
到底被哪里调用了。最下面有可视化的视图，可以看到函数 `byte_index_to_char_index`, 
`char_index_to_byte_index` 都最终调用了 `char_bytesize_at` 这个函数，我们可以继续
向上分析，看到 `entry_match?` `match` 调用了 `char_index_to_byte_index` ，你甚至可以
直接在右侧 location 面板，看到函数定义的位置 `string.cr:5402`, 右击鼠标，选择 
`Open in Editor`, 可以直接用编辑器打开方法定义的源码。

Caller/Callee 信息，结合另一个选项卡的 Top-down（自顶向下）视图，可以很方面的看到
从主程序顶层调用函数(main)出发, 到了哪一层开始消耗了非常多的资源。

## 分析函数调用次数

但是我们仍然有一个问题，我们知道性能瓶颈来自于：`String::char_bytesize_at`, 但是我们并不知道
瓶颈到底是是这个函数**调用频率过高** 还是 **单次执行时间太长** 造成的。

一个选项是：使用 perf probe 来为指定的函数添加一个追踪目的的 trace points，通俗的讲，叫做给程序**插入探针**

1. 首先我们需要重新编译它，关闭 llvm 方法内联优化，因为这些优化导致上面的方法不是在文本段方法全局可用的符号

```bash
crystal build src/main.cr -o1 --debug
```

2. 然后查看函数的调用次数，确保可以找到指定的符号，并且结果是一个**大写的 "T"**

```bash
nm -C ./main | grep String::char_bytesize_at
# => 00000000000e9390 T *String::char_bytesize_at<Pointer(UInt8)>:Int32
```

3. 为上面指定地址的函数，添加一个探针。

注意，下面的命令需要使用 sudo 来运行，最后传递的地址是上面返回的 16 进制函数地址

```bash
sudo perf probe -x ./main -a 0xe9390

# Added new event:
#  probe_main:abs_e9390 (on 0xe9390 in /home/zw963/Crystal/git/tartrazine/main)
```

4. 运行下面的命令来确保已经插针成功

```bash
sudo perf probe -l
#  probe_main:abs_e9390 (on char_bytesize_at@share/crystal/src/string.cr in /home/zw963/Crystal/git/tartrazine/main)
```

记住 probe_main:abs_e9390, 稍后会用到


5. 重新执行 perf record, 支持的事件类型，选择上面的事件类型


```bash
perf record -e probe_main:abs_e9390 -- ./main src/tartrazine.cr abap
```

这个步骤如果完整跑下来，会花费几分钟时间，并且生成一个很大的的 perf.data（我这里是 20G ）

好在，我们分析函数调用次数，并不需要完整的运行它才能知道，随便小跑一小会儿就好了，然后按下
`Ctrl + C` 等待 pref record 结束，再使用已知的工具分析它。

也可以使用 timeout 命令，例如，我们只想运行 10 秒钟

```bash
timeout 10s perf record -e probe_main:abs_e9390 -- ./main src/tartrazine.cr abap
```

这次，仅仅写入了 560M 的一个 perf.data，分析软件打开会很快。

如果你的程序确实需要完整执行综合分析，可以选择让 ./main 处理一个较小的文件，
或减少取样，例如：确保每秒只生成约 1000 个样本

```bash
perf record -e probe_main:abs_e9390 --freq 1000 -- ./main src/tartrazine.cr abap
```

这样生成样本也只有 16M 大小，分析完成之后，记得删除插针。

```bash
sudo perf probe -d abs_e9390
```

## 使用 valgrind 来分析性能瓶颈

valgrind 是一款通常用来查找内存泄漏的软件，也可以用于发现性能瓶颈，它生成的数据需要
使用 kcachegrind 查看，Arch linux 下可以直接安装这些包

安装

```bash
sudo pacman -S valgrind kcachegrind
```

使用 valgrind 来运行我们之前编译的 main

```bash
valgrind --tool=callgrind ./main ./src/tartrazine.cr abap
```

这会生成一个类似于 `callgrind.out.920542` 这样的文件，然后我们可以使用 kcachegrind 来打开它。

```bash
kcachegrind ./callgrind.out.920542
```

valgrind 输出的信息非常详细，包含 perf 拥有的所有信息，包括一个函数被调用的次数。

![callgrind](/docs/images/valgrind.webp)

如上图所示，根据 callgrind 输出，可以看到 `String#char_bytesize_at 以及它调用的函数` 占用了 52.39% 
CPU 时钟周期，而 `该函数自己` 则占用了 18.17% CPU 时钟周期，我们还看到这个函数被调用了**两亿七千万次**！

valgrind 非常方便, 唯一的缺点就是，速度非常慢(据称某些时候甚至可能慢80倍），在我AMD 7840hs 机器上，
我实际运行上面的 `./main ./src/tartrazine.cr abap` 只需要 **1.7** 秒，但是使用 valgrind 运行它需要 **1分40秒**, 
足足慢了 58 倍！


