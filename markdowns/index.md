```
Crystal 是一门受 Ruby 高度启发的计算机程序语言，并且最终编译到 LLVM。

对于同时具备系统编程经验（例如 C）以及 Ruby 开发经验的程序员来说，Crystal 是一门
很容易掌握的语言。
```

```
目前这个版本，写作计划为具有 Ruby (或类似经验) 的开发者的 Crystal 介绍，因此，
现阶段不会特意讲解 Ruby 相关的基础知识，代之，会使用类似当前 "小提示" 对话框的方式
指出 Crystal 和 Ruby 的异同。

建议在学习 Crystal 文档之前，掌握一些 Ruby 的基本概念，会减少很多摩擦。
```

一直以来，为 Crystal 在中国的普及做贡献，都是自己的一个美好愿望，但一直因故未能实现，
这次，以翻译 Crystal 官方文档作为开始，将笔者学习 Crystal 过程中大量的笔记进行整理,
也算是对自己之前的知识的一个学习和再掌握。

正如 Ruby 一样，在看似简单的外表下，Crystal 又绝非一门简单的语言，希望笔者根据自己的
经验，能将这一门让人惊叹、并且唯一的的语言讲解清楚，对读者学习掌握 Crystal 带来帮助。

如有错误，[欢迎提出勘误指正](https://github.com/crystal-china/website/issues), 或在下面留言，我会及时更正，保证不对对读者产生误导。

## 本站技术栈

[本站](https://github.com/crystal-china/website) 自然使用 Crystal 编写，目前用到的库（shard）有：

- [baked_file_system_mounter](https://github.com/crystal-china/baked_file_system_mounter), 用于将本站所需的 assets 文件
 （包含 js, css, 字体，markdown 等）打包进可执行文件，并在部署到新机器后自动 mount。
- [lucky](https://github.com/luckyframework/lucky) 是一个全功能的 web 框架，用来搭建本站以及计划中的论坛。
- [magic-haversack](https://github.com/crystal-china/magic-haversack) 使用 zig cc 来 build 一个 Crystal 静态 bianry（无需 docker）
- [markd](https://github.com/icyleaf/markd) 用于转换 markdown 格式到网页。
- [tartrazine](https://github.com/ralsina/tartrazine), 用于高亮 markdown 中的代码块。

更多的 shard，查看 [shard.yml](https://github.com/crystal-china/website/blob/master/shard.yml)。

前端部分，基于本人的喜好，本站**最大限度避免编写Javascript**, 并且本人也基本不会写 CSS，
有希望拿本项目练手的前端小将，欢迎报名！

下面笔者介绍的本站用到的前端项目，都是属于同一个 github 组织 **Big Sky Software** 下的项目。
他们组织的介绍老有意思了：`我们会发现行业中的***新兴热点**趋势，然后创造出与之`**相反**`的东西`。

- [htmx](https://htmx.org/) 高效率的 HTML 工具(high power tools for HTML)，这个官方介绍很模糊，其实
  作者专门写了本书介绍 [hypermedia](https://hypermedia.systems/) 的概念，建议读一读，非常有意思，这绝对是像我
  这种服务端工程师的最爱。
- [hyperscript](https://github.com/bigskysoftware/_hyperscript) 专门写在页面标签中的 `script` 或 `_` 属性中的脚本，语法非常接近于
  口语话的英文，是 htmx 一个非常好的补充，见本站 [src/components/doc/form.cr](https://github.com/crystal-china/website/blob/master/src/components/doc/form.cr) 中的例子。
- [missing.css](https://missing.style/) 一个非常简陋的 CSS 框架，非常轻量
- [stork](https://github.com/jameslittle230/stork) 很好用的本地全文搜索库，会编译为 wasm 因此性能很好，缺点是中文支持差一点，
  另外，作者不维护了，有点可惜，目前够用吧。

更多用到的前端库，查看 [pacakge.json](https://github.com/crystal-china/website/blob/master/package.json)。

## 本站如何部署

本站部署在一个树莓派5B (16G) 上，通过家里的 5G 网络（CPE + 广电流量卡）, 所以网速可能不太好。
使用静态编译，低负载情况下，内存占用在 43M 左右，因为资源占用很低，同时部署了好几个站点。

部署流程相较于 Ruby 也简单到爆！见项目 [README](https://github.com/crystal-china/website/blob/master/README.md) 以及有关 [交叉编译](https://crystal-china.org/docs/cross_compile) 的说明。

整个部署过程是非常简单而且快速的。

1. `shards run index` 创建所需的索引
2. `yarn prod` 打包 assets 文件到 ./dist 文件夹。
3. 交叉编译，生成一个静态的 binary (所有所需的 assets 文件也会被加入二进制文件)
4. 和服务器上最后部署版本比较，并生成 binary patchfile.
5. 复制 patchfile 到服务器，并应用。（相较于文件覆盖，服务器无需停止，既可以打 patch）
6. 成功后，本地做一个刚刚部署版本的备份

此网站编译后的 binary 大小大约 21M 左右（包含所有 assets 文件），修改不多的情况下，
生成的 patch 文件大小在 500K 左右, 大部分部署时间花在了编译 release 版本的静态 binary。

```bash
sb_static_arm64 --production --no-debug --link-flags="-s" --link-flags="-pie" --release crystal_china
```

如果还处在开发过程中，可以暂时移除 --release 参数，前者其实等价于： `-O3 --single-module`
-O 用来指定为了生成 `最优代码` 的 `代码生成(codegen)` 工作量，默认不指定是 -O0 无优化，-O3 最高级别优化。
较高的优化级别拥有更好的运行时(runtime)性能，但是需要花费更多的编译时间。

这是一个权衡，事实上，在开发阶段，总是使用 -O1 是一个不错的主意，除非项目是简单的 
hello world，否则默认不优化相较于 -O1 不会有明显的提升。

下面是来自 [PR 作者](https://github.com/crystal-lang/crystal/pull/13464#issue-1708224879) 不同优化级别的性能比较：

```bash
default: 初次编译: 7.4s, 增量编译(修改一个文件): 5.3s, 启动时间: 23.5s
-O1: 初次编译: 12s, 增量编译(修改一个文件): 5.2s, 启动时间: 7.5s
-O2: 初次编译: 12.6s, 增量编译(修改一个文件): 5.3s, 启动时间: 7s
--release: 初次编译: 61s, 增量编译(修改一个文件): 61s, 启动时间: 2s
```

可以看到，除了第一次编译时（只需要执行一次，对吧？）default 比 -O1 快不少 (7.4s -> 12s)，
但增量编译阶段，-O1 甚至还比 default 快了一点点 (5.3s -> 5.2s)。但是运行时性能，
则有显著的提升, (23.5s -> 7.5s), 足足快了三倍多，所以，对于 Web 开发这种 
`非常频繁的增量编译` 的项目，或者 `需要反复运行 spec` 的情况，使用 -O1 是一个
不错的注意，-O1 会输出较少的 backtrace, 但是带来大约 15% 的性能提升，需要加 `--debug` 
参数来输出和 default 同样的 backtrace, 所以，一切都是权衡。


```bash
 ╰──➤ $ binary_patch_crystal_china bin/crystal_china
Calculating patch file ... Done.
crystal_china.patchfile								100%  469KB 900.1KB/s   00:00
Patching file ... Done
deploy successful
'bin/crystal_china' -> 'latest_released/bin/crystal_china'
```


最后一步，ssh 登录服务器，重启 web 服务，例如，Crystal China 站点使用 systemd, 

```bash
 ╰──➤ $: systemctl restart crystal_china
```

如有数据库表改动, 会在第一次启动时执行，部署完成！


