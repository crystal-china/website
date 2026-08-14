Crystal 通过 `--cross-compile` 支持交叉编译，但是你常常需要也传递一个 `--target TARGET`
来告诉编译器，为哪一个目标平台，编译生成目标(target)文件。

例如：下面的命令生成了一个适用于苹果 OSX ARM64 操作系统的的目标文件 `main.o`
当命令执行成功之后，会打印一段命令来期望 `在目标平台执行` 来生成可执行文件。

```bash
╰──➤ $ crystal --cross-compile --target aarch64-darwin -o main
cc start_server.o -o start_server  -rdynamic -L/home/zw963/.asdf/installs/crystal/1.15.0/bin/../lib/crystal -lxml2 -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -liconv

╰──➤ $ file main.o
main.o: Mach-O 64-bit arm64 object, flags:<|SUBSECTIONS_VIA_SYMBOLS>
```

完整的 target 列表可以参考 [platform_support](https://crystal-lang.org/reference/latest/syntax_and_semantics/platform_support.html) ，但常用的支持平台有如下几个：

| target | 描述 | 支持的版本 | 支持级别|
| --- | --- | --- | --- |
| aarch64-darwin | M 系列（ARM）苹果电脑(Apple Silicon) |  11+ | Tier 1 |
| x86_64-darwin |  Intel CPU 的苹果电脑 | 11+ | Tier 1 |
| x86_64-linux-gnu | 64 位 Linux | 内核 4.14+, `GNU` libc 2.26+ | Tier 1 |
| x86_64-linux-musl | 基于 Alpine 的 64 位 Linux  | 内核 4.14+, `MUSL` libc 1.2+ | Tier 1 |
| aarch64-linux-gnu | AARCH64 Linux  | GNU libc 2.26+ | Tier 2 |
| aarch64-linux-musl | AARCH64 Linux  | MUSL libc 1.2+ | Tier 2 |
| x86_64-windows-msvc | 64 位 Windows (MSVC)  | Win7+ | Tier 3 |

**备注**

- Tier 级别：1 为保证工作，2 期望工作，3 部分工作
- 基于 musl 的 target 主要用来编译生成该平台静态 binary.
- 随着 Windows 平台支持越来越完善，支持级别应该很快被提升。


## 静态链接

Crystal 支持静态链接，当传递  `--static` 参数时，会尝试查找依赖库的静态版本来创建
可执行文件，以使得稍后运行时不再需要这些库，带来的优点是，随便拷贝到同 target 的
任意一个机器上就可以运行，缺点，就是文件大小会增加。

你需要安装所有依赖库的静态版本，否则编译器会报错，假设某个库名称叫做 `foo`, 通常
该库的静态版本叫做 `foo-static`.

和动态库一样，Crystal 使用 `CRYSTAL_LIBRARY_PATH` 环境变量，从前往后查找依赖库。

作为一个编译型语言，可以编译生成一个没有外部依赖的静态的 binary，对于部署到
另一台机器(生产环境)来说，相较于 Ruby 这种使用源码部署的动态语言，是极其便利的。

当前，静态编译一个 Linux 下的静态 binary, 需要 [musl-libc](https://musl.libc.org/) 支持，常见的做法是
使用 Docker。


## 使用**基于Alpine Linux 的官方 Docker 镜像**编译一个静态 binary 

这里对如何使用 docker 不做过多的解释，参见下面的 `Dockerfile`，它做的事是将本地项目
目录挂载到 docker 容器中，在其中编译生成静态 binary，官方预发布的编译器也是这么做的。


<details>
<summary>Dockerfile</summary>

```dockerfile
ARG alpine_mirror=mirrors.ustc.edu.cn

FROM crystallang/crystal:1-alpine AS official_release

ARG alpine_mirror
RUN sed -i "s/dl-cdn.alpinelinux.org/$alpine_mirror/g" /etc/apk/repositories

# 在这里添加需要的静态版本依赖库（编译错误会告诉你）。
RUN --mount=type=cache,target=/var/cache/apk \
    set -eux; \
    apk add \
    --update \
    sqlite-static \
    ;

# 下面这一堆，只是为了使用 fixid 处理挂载目录到容器内新生成的文件的权限问题。
RUN addgroup -g 1000 docker && \
    adduser -u 1000 -G docker -h /home/docker -s /bin/sh -D docker
RUN wget -O - https://github.com/boxboat/fixuid/releases/latest | \
    grep -E -o "boxboat/fixuid/releases/tag/[^\"]*\" data-view-component" | \
    cut -d'"' -f1 | rev|cut -d'/' -f1 |rev |sed 's#^v##' > fixuid_version
RUN wget https://github.com/boxboat/fixuid/releases/download/v$(cat fixuid_version)/fixuid-$(cat fixuid_version)-linux-amd64.tar.gz -O - | tar zxvf - -C /usr/local/bin
RUN USER=docker && \
    GROUP=docker && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: $USER\ngroup: $GROUP\n" > /etc/fixuid/config.yml
USER docker:docker

WORKDIR /app

ENTRYPOINT ["fixuid"]

CMD ["shards", "build", \
     "-Dstrict_multi_assign", "-Dno_number_autocast", \
     "-Dpreview_overload_order", "-Duse_pcre2", \
     "--link-flags=-Wl,-L/app", "--link-flags=-s", \
     "--progress", "--static", "--stats", "--time", "--no-debug", \
     "--production", "--release"]
```

</details>

进入项目目录，将上面的文件保存为 Dockerfile，使用下面的命令构建 Docker 镜像：

```bash
docker build -t build_crystal_amd64_static_binary .
```

然后运行这个镜像，来创建静态的 binary

```bash
 ╰──➤ $ docker run -it -u $(id -u):$(id -g) -v $PWD:/app build_crystal_amd64_static_binary
fixuid: fixuid should only ever be used on development systems. DO NOT USE IN PRODUCTION
fixuid: runtime UID '1000' already matches container user 'docker' UID
fixuid: runtime GID '1000' already matches container group 'docker' GID
Dependencies are satisfied
Building: myip
Parse:                             00:00:00.000115461 (   1.26MB)
Semantic (top level):              00:00:00.327796720 ( 134.21MB)
Semantic (new):                    00:00:00.001296853 ( 134.21MB)
Semantic (type declarations):      00:00:00.028085586 ( 134.21MB)
Semantic (abstract def check):     00:00:00.008466714 ( 142.21MB)
Semantic (restrictions augmenter): 00:00:00.010456306 ( 142.21MB)
Semantic (ivars initializers):     00:00:00.009350086 ( 150.21MB)
Semantic (cvars initializers):     00:00:00.158940664 ( 174.28MB)
Semantic (main):                   00:00:00.377006249 ( 246.40MB)
Semantic (cleanup):                00:00:00.000630417 ( 246.40MB)
Semantic (recursive struct check): 00:00:00.000639605 ( 246.40MB)
Codegen (crystal):                 00:00:00.315987432 ( 270.40MB)
Codegen (bc+obj):                  00:00:14.472953394 ( 270.40MB)
Codegen (linking):                 00:00:00.263343233 ( 270.40MB)

Codegen (bc+obj):
 - no previous .o files were reused

```

如果你还希望 build 其他 target 的 Linux 静态 binary, 例如：aarch64-linux-musl
你需要采用 Docker 的 multi-stage 功能，在和当前 Linux 相同的 stage 生成 .o 中间
文件，然后在目标的 stage 执行 linking，会更加复杂一些，这里不做赘述。

因为我们有更好的方案，使用 zig cc, 甚至无需 Docker 容器，也可以在 Linux/OSX 下
使用交叉编译来生成下面平台的静态可执行文件！

- aarch64-darwin 
- x86_64-darwin
- x86_64-linux-musl 
- aarch64-linux-musl

## 使用 zig cc 来实现交叉编译

详细的信息见我写的 [这篇英文文章](https://github.com/crystal-china/magic-haversack/blob/main/docs/use_zig_cc_as_an_alternative_linker.md), 这里也同样不赘述，仅提供步骤：

### 1. 确保本地正确安装 zig

```bash
sudo pacman -S zig
```

### 2. 从 Github 克隆项目

```bash
https://github.com/crystal-china/magic-haversack
```

### 3. 下载必须的静态版本依赖库

如果你希望自己手动从 [alpinelinux CDN](https://dl-cdn.alpinelinux.org/alpine/) 以及 [Homebrew Formula](https://github.com/Homebrew/homebrew-core/tree/master/Formula) 安装所需的
依赖库的静态版本，你需要本地配置正确的 Ruby 环境，并运行如下命令：‘

```bash
bundle install && rake fetch:all
```

如果一切正常（可能需要梯子），你会看到新创建的 lib 文件夹下面会有类似下面的目录结构：

<details>
<summary>lib 目录结构</summary>

```bash
 ╰──➤ $ tree -L2 lib
lib
├── aarch64-linux-musl
│   ├── libcrypto.a
│   ├── libevent.a
│   ├── libevent_pthreads.a
│   ├── libgc.a
│   ├── libgmp.a
│   ├── libicudata.a
│   ├── libicuuc.a
│   ├── liblzma.a
│   ├── libpcre2-8.a
│   ├── libsodium.a
│   ├── libsqlite3.a
│   ├── libssl.a
│   ├── libxml2.a
│   ├── libyaml.a
│   ├── libz.a
│   └── pkgconfig
├── aarch64-monterey
│   ├── libcrypto.a
│   ├── libevent.a
│   ├── libevent_pthreads.a
│   ├── libgc.a
│   ├── libgmp.a
│   ├── libiconv.a
│   ├── liblzma.a
│   ├── libpcre2-8.a
│   ├── libsodium.a
│   ├── libsqlite3.a
│   ├── libssl.a
│   ├── libxml2.2.dylib
│   ├── libxml2.dylib
│   ├── libyaml.a
│   ├── libz.a
│   └── pkgconfig
├── x86_64-linux-musl
│   ├── libcrypto.a
│   ├── libevent.a
│   ├── libevent_pthreads.a
│   ├── libgc.a
│   ├── libgmp.a
│   ├── liblzma.a
│   ├── libpcre2-8.a
│   ├── libsodium.a
│   ├── libsqlite3.a
│   ├── libssl.a
│   ├── libxml2.a
│   ├── libyaml.a
│   ├── libz.a
│   └── pkgconfig
└── x86_64-monterey
    ├── libcrypto.a
    ├── libevent.a
    ├── libevent_pthreads.a
    ├── libgc.a
    ├── libgmp.a
    ├── libiconv.a
    ├── liblzma.a
    ├── libpcre2-8.a
    ├── libsodium.a
    ├── libsqlite3.a
    ├── libssl.a
    ├── libxml2.2.dylib
    ├── libxml2.dylib
    ├── libyaml.a
    ├── libz.a
    └── pkgconfig

9 directories, 58 files
```

</details>


```info
另一个更好的选择是，你无需配置 Ruby ，也无需搭梯子，直接从 [项目 release 页面](https://github.com/crystal-china/magic-haversack/releases/latest)
下载 `libs.tar.gz` 并解压缩到项目根目录即可。
```

### 4. 将 bin/ 加入 $PATH 

无论你当前使用什么 shell, 请确保 BASH 4.0+ 可用。

脚本中会使用到 sed, 这在 Linux 下没问题，OSX 下，请确保 GNU 工具链命令行下优先被使用。

确保设置完成后，`sb` 和 `sb_static` 命令均可以执行被执行。

```bash
 ╰──➤ $ which sb sb_static
/home/zw963/Crystal/bin/sb
/home/zw963/Crystal/bin/sb_static
```

### 5. 最后一步，确保你的项目使用 shards 包管理工具来编译并运行。

对于大部分项目来说，这应该都不是问题。

进入你的项目后，执行下面的命令来构建针对不同的 target 的 binary。

------

**x86_64 Linux 下运行的静态可执行文件**

```bash
╰─ $ sb --cross-compile --target=x86_64-linux-musl
zig cc -target x86_64-linux-musl bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/magic-haversack/lib/x86_64-linux-musl -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -lunwind

 ╰─ $ file bin/college
bin/college: ELF 64-bit LSB executable, x86-64, version 1 (SYSV), static-pie linked, with debug_info, not stripped
```

我还提供了一个脚本叫做 `sb_static`, 它可以帮你运行上面的命令，你自己只需要传递其他
需要的选项即可，例如：

```bash
sb_static --production --no-debug --link-flags=-s
```

```info
本站在部署时，正是使用上面的脚本构建，生成一个静态可执行文件，然后拷贝这一个文件
到远程服务器即可，非常简单！

为了避免正在运行的网站可执行文件无法直接被覆盖，需要停止服务才能覆盖的问题，并且
考虑节省流量，同时拷贝速度快一些，本站使用了 [二进制 diff/patch 工具](https://github.com/petervas/bsdifflib)，
在开发机本地针对上次部署的二进制文件生成 patch 文件， 然后仅拷贝 patch 文件到远程服务器，
最后在远程服务器应用 patch 文件，最后重启服务即可生效，**全程无需停止服务**。

本站生成的部署文件大概 17M 左右, 其中包含了大约 3M 的 assets（图片，JS, CSS 等）文件，
这些网站运行时必须的文件，在运行时会被自动挂载到文件系统中。
```
 
-----------

**AARCH64 linux 下运行的静态可执行文件** 

```bash
╰─ $ sb --cross-compile --target=aarch64-linux-musl
zig cc -target aarch64-linux-musl bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/magic-haversack/lib/aarch64-linux-musl -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -lunwind

 ╰─ $ file bin/college
bin/college: ELF 64-bit LSB executable, ARM aarch64, version 1 (SYSV), static-pie linked, with debug_info, not stripped
```

--------------
 
**Intel 处理器的苹果电脑可执行文件**

```bash
╰─ $ sb --cross-compile --target=x86_64-darwin
zig cc -target x86_64-macos-none bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/magic-haversack/lib/x86_64-monterey -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -liconv -lunwind

  ╰─ $ file bin/college
bin/college: Mach-O 64-bit x86_64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|NO_REEXPORTED_DYLIBS|PIE|HAS_TLV_DESCRIPTORS>
```

----------------
 
 **ARM64 处理器的苹果电脑可执行文件**
 
 ```bash

 ╰─ $ sb --cross-compile --target=aarch64-darwin
zig cc -target aarch64-macos-none bin/college.o -o bin/college  -rdynamic -static -L/home/zw963/Crystal/crystal-china/magic-haversack/lib/aarch64-monterey -lgmp -lyaml -lz `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto'` `command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto'` -lpcre2-8 -lgc -lpthread -ldl -levent -liconv -lunwind

 ╰─ $ file bin/college
bin/college: Mach-O 64-bit arm64 executable, flags:<NOUNDEFS|DYLDLINK|TWOLEVEL|NO_REEXPORTED_DYLIBS|PIE|HAS_TLV_DESCRIPTORS>
```

------

访问 [magic-haversack](https://github.com/crystal-china/magic-haversack) 项目主页的 REAME 以及 doc 了解更多的信息。

