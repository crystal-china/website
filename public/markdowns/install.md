详细安装教程，请查看 [官方文档](https://crystal-lang.org/install)

这里仅介绍常见的几个系统安装方式：

# Linux

## Debian & RPM

```bash
curl -fsSL https://crystal-lang.org/install.sh | sudo bash
```


## Debian/Ubuntu

```bash
sudo apt install crystal ${hello}
```

## Alpine Linux

```bash
apk add crystal shards ${hello}
```

## Arch linux

```bash
sudo pacman -S crystal
```
## 编译安装

作为 Crystal 语言开发者，编译安装 Crystal 是首选的, 而且可以开启实现性的解释器支持。

以在 Arch Linux 编译当前最新的 Crystal 1.15.1 为例，假设我们希望编译并安装 Crystal 
到 ~/Crystal 文件夹，你需要将 ~/Crystal/bin 加入 $PATH 靠前的位置来直接使用 crystal 命令

### 安装编译及安装所需依赖

```bash
sudo pacman -S base-devel \
       automake \
       git rsync \
       gmp \
       pcre2 \
       openssl \
       libtool \
       libyaml \
       llvm lld \
       wasmer wasmtime \
    ;
```

### 使用 git clone 官方 github repo

```bash
git clone https://github.com/crystal-lang/crystal.git && cd crystal
git checkout 1.15.1
```

### 编译 Crystal

```bash
make clean
install_target=~/Crystal
mkdir -p output $install_target/bin $install_target/share $install_target/share/crystal/src/llvm/ext/
FLAGS="-Dpreview_mt" make crystal interpreter=1 stats=1 release=1
```

### 安装 Crystal

```bash
rm -rf tmp
DESTDIR=$PWD/tmp make install
cp -v tmp/usr/local/bin/crystal $install_target/bin/
rsync -ahP --delete tmp/usr/local/share/ $install_target/share/
```

然后将 ~/Crystal/bin 加入 $PATH 即可。

### 生成并安装静态文档

```bash
rm -rf docs && make docs
rsync -ahP --delete docs/ $install_target/docs
```

这样，你可以直接用浏览器浏览本地的文档 ~/Crystal/docs/index.html

### 安装包管理工具 shards

见 [package_manager](docs/package_manager)

---------


# macOS

## Homebrew 

```bash
brew install crystal
```

## MacPorts

```bash
port install crystal
```

## [tarball](https://github.com/crystal-lang/crystal/releases/download)

-----

# asdf (For linux/macos)

```bash
asdf plugin add crystal
asdf install crystal latest
```


----------


# Windows

# scoop

在一个非超级用户的 PowerShell 终端运行如下命令安装 scoop 到 *C:\Users\<YOUR USERNAME>\scoop*


```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

运行如下命令安装 Crystal

```powershell
scoop install git
scoop bucket add crystal-preview https://github.com/neatorobito/scoop-crystal
scoop install vs_2022_cpp_build_tools crystal
```

-------


# Docker

```bash
docker pull crystallang/crystal
```
