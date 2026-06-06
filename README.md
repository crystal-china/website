# The website for https://crystal-china.org

# Development dependencies

- Crystal
- pg
- bun
- podman (or docker)

## Development

1. First, install Crystal. You can check out the instructions here: https://crystal-lang.org/install/

3. Run `script/setup`, Just make sure you’ve got `pg` and `bun` installed before running this.

4. Finally, run `lucky dev`, and you're all set!

## deployment

There are no runtime dependencies when deploying to a remote Linux environment except
one static binary with all assets baked into it, and will auto mount when running.

Following is the process for create the static binary:

1. Run `shards run index` to create an index for all markdown docs into `public/docs/index.st`, using `bin/stork`.

2. Run `bun run prod` to build and precompress assets into `public/assets`.

3. To build a static binary use `script/build_amd64_static_binary.sh`, you need 
   install `podman` or `docker`.

   alternatively, you can use [sb_static](https://github.com/crystal-china/magic-haversack/blob/main/bin/sb_static) script with zigcc, for more details 
   instructions on building a static binary use zigcc, check [use zig gcc as an an alternative linker](https://github.com/crystal-china/magic-haversack/blob/main/docs/use_zig_cc_as_an_alternative_linker.md)
   
4. copy the built static binary(`bin/crystal_china`) into remote linux host as `bin/crystal_china`, then 
   set the necessary ENV in file `.env`, check the [.env.sample](/.env.sample) for a example.
   You will have the following directory structure.
	```
	   .
	   ├── .env
	   └── bin/crystal_china
	```
    If server was started, you have to stop it before copy the binary successful. a more robust way to do this is
    use a [binary diff tools](https://github.com/petervas/bsdifflib/) create patch locally, and then send patch file
    to remote server apply it, this way you can update the binary on the fly, then reboot systemd service is all done.

5. Add a systemd service to start the server, review the configuration for the [crystal_china.service](/nginx/crystal_china.service)
   consider using [procodile](https://github.com/crystal-china/procodile) as an alternative for above .env and systemd services.

6. Optionally, use nginx as a reverse proxy. You can find configuration details in [nginx folder](/nginx)

## Contributing

1. Fork it (<https://github.com/zw963/website/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Billy.Zheng](https://github.com/zw963) - creator and maintainer
