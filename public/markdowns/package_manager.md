这是 [**官方 shards 手册**](https://crystal-lang.org/reference/1.15/man/shards/index.html) 直接翻译的文档。

Crystal 通常会搭配其依赖管理器 shards 命令使用。

它负责管理 Crystal 项目和库的依赖，确保在不同计算机和系统上都能实现可重复安装。

## 安装

Shards 通常随 Crystal 自身一起分发。或者，你的系统可能会提供单独的 shards 包。

要从源代码安装，请下载或克隆[该仓库](https://github.com/crystal-lang/shards)，然后运行

```bash
make CRFLAGS=--release
```

编译后的二进制文件位于 `bin/shards`，需要将其添加到 `PATH` 中。

## 用法

`shards` 需要在项目根目录（工作目录）中存在一个 `shard.yml` 文件，该文件描述了项目并列出了构建项目所需的依赖。你可以通过运行 `shards init` 来生成一个默认的 `shard.yml` 文件。关于该文件的详细说明，请参阅官网[Writing a Shard](https://crystal-lang.org/reference/1.15/guides/writing_shards.html)指南以及 [shard.yml 的规格说明](https://github.com/crystal-lang/shards/blob/master/docs/shard.yml.adoc)。

运行 `shards install` 命令会解析并安装指定的依赖。安装后，依赖的版本信息会记录在 `shard.lock` 文件中，以便下次执行 `shards install` 时确保使用相同的依赖版本。

如果你的 shard 构建的是一个应用程序，建议将 `shard.yml` 和 `shard.lock` 一同提交到版本控制中，以保证依赖安装的可重复性；如果它仅仅是一个供其他 shard 依赖的库，则只需要提交 `shard.yml`，而不必提交 `shard.lock`。通常建议将 `shard.lock` 添加到 `.gitignore` 文件中（使用 `crystal init lib` 初始化库仓库时会自动处理这一点）。

## shards 命令

```bash
shards [<options>...] [<command>]
```

如果未指定命令，默认会执行 `install`。

- **shards build**: 构建可执行文件
- **shards check**: 检查依赖是否已安装
- **shards init**: 生成一个新的 `shard.yml` 文件
- **shards install**: 解析并安装依赖
- **shards list**: 列出已安装的依赖
- **shards prune**: 移除未使用的依赖
- **shards update**: 解析并更新依赖
- **shards version**: 显示 shard 的版本信息

要查看特定命令的可用选项，可在命令后添加 `--help`。

### 常用选项

- `--version`: 输出 shards 的版本信息
- `-h, --help`: 显示使用说明
- `--no-color`: 禁用彩色输出
- `--production`: 以生产模式运行，此模式下不会安装开发依赖，只安装锁定的依赖；如果 `shard.yml` 与 `shard.lock` 中的依赖不一致（适用于 `install`、`update`、`check` 和 `list` 命令），命令将会失败
- `-q, --quiet`: 降低日志详细级别，仅输出警告和错误信息
- `-v, --verbose`: 提高日志详细级别，输出所有调试信息

## shards build

```bash
shards build [<targets>] [<options>...]
```

构建 `bin` 目录下指定的目标。如果未指定目标，则构建所有目标。该命令会确保所有依赖都已安装，因此无需预先运行 `shards install`。

所有跟随在命令之后的选项将传递给 `crystal build`。

## shards check

```bash
shards check
```

检查所有依赖是否已安装且满足要求。

退出状态：
- `0`: 成功，依赖满足
- `1`: 失败，依赖不满足

## shards init

```bash
shards init
```

初始化一个 shard 文件夹，并创建一个 `shard.yml` 文件。

## shards install

```bash
shards install
```

解析并安装依赖到 `lib` 文件夹中。如果尚不存在 `shard.lock` 文件，则会从解析后的依赖生成该文件，锁定版本号或 Git 提交记录。

如果存在 `shard.lock` 文件，则命令会读取并强制使用锁定的版本和提交。若锁定的版本与要求不符，安装可能失败；但如果只是新增依赖且未产生冲突，则会生成一个新的 `shard.lock` 文件。

## shards list

```bash
shards list
```

列出已安装的依赖及其版本。

## shards prune

```bash
shards prune
```

从 `lib` 文件夹中移除未使用的依赖。

## shards update

```bash
shards update
```

重新解析并更新所有依赖到 `lib` 文件夹中，无论 `shard.lock` 文件中锁定的版本和提交如何。最终会生成一个新的 `shard.lock` 文件。

## shards version

```bash
shards version [<path>]
```

输出 shard 的版本信息。

## 修复依赖版本冲突

可以通过创建 `shard.override.yml` 文件来覆盖依赖的来源和版本限制。你也可以通过环境变量 `SHARDS_OVERRIDE` 指定该文件的其他位置。

该文件是一个 YAML 文档，其中包含一个 `dependencies` 键，其语义与 `shard.yml` 中相同。文件中的依赖配置会优先于 `shard.yml` 或任何依赖的 `shard.yml` 中的配置。

适用场景包括：本地开发副本、在依赖约束不匹配时强制使用特定版本、修复依赖问题、检查未发布版本的兼容性等。

shard.override.yml 示例：

```yaml
dependencies:
  # 假设我们在 Redis shard 的版本上出现冲突
  # 这里将覆盖任何指定的版本，改为使用 `master` 分支
  redis:
    github: jgaskins/redis
    branch: master
```
