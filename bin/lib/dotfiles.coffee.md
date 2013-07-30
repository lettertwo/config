dotfiles
========

A util for managing dotfiles and the shell.
The dotfiles util is really a collection of utils organized
into subcommands.


definitions
-----------

    {ArgumentParser} = require 'argparse'
    deferred = require 'deferred'
    colors = require 'colors'
    pkgmeta = require '../../package'

Create the argument parser.

    parser = new ArgumentParser(
      version: "#{pkgmeta.version}"
      addHelp: true
      description: 'Manage dotfiles and the shell')

    subparsers = parser.addSubparsers(
      title: 'commands'
      dest: 'command')


subcommand: `use`
-----------------

The argument parser for the `use` subcommand requires a `shell` argument,
which can be one of either `bash` or `zsh`. It also looks for an optional
`--default` flag, which will tell `use` to configure the specified shell
as the default.

    useParser = subparsers
      .addParser('use',
        addHelp: true
        description: 'Use a particular shell')

    useParser
      .addArgument(
        ['shell'],
        {
          action: 'store'
          choices: ['bash', 'zsh']
          help: 'The shell to use'
        })

    useParser
      .addArgument(
        [ '-d', '--default'],
        {
          action: 'storeTrue'
          help: 'Use this shell by default'
          dest: 'save'
        })


The use subcommand configures the specified `shell` for immediate use.
If `save` is `true`, the specified `shell` is also configured as the
default shell.

This subcommand abuses the process exit code to communicate with the
parent shell process.

An exit code of `10` indicates that `bash` has been selected for use.
An exit code of `20` indicates that `zsh` has been selected for use.

    use = (shell, save=false) ->
      user = null
      path = null

      defer =
        if save
          exec('whoami', silent: true)
            .then((u) ->
              user = u.trim()
              if shell is 'bash'
                exec ['which', 'bash'], silent: true
              else if shell is 'zsh'
                exec ['which', 'zsh'], silent: true)
            .then((p) ->
              path = p.trim()
              log.info "Changing default shell to #{path} for #{user}"
              exec ['chsh', '-s', path, user], silent: true)
        else
          deferred true

      defer.then(
        ->
          log.info "Activating #{shell}..."
          if shell is 'bash'
            process.exit(10)
          else if shell is 'zsh'
            process.exit(20)
        errorAndExit)


---

utils
=====

    {spawn} = require 'child_process'
    deferred = require 'deferred'
    colors = require 'colors'

exec
----

    exec = (cmd, options = {}) ->
      options.silent ?= false
      options.log ?= true

      defer = deferred()
      if typeof cmd is 'string' then cmd = cmd.split ' '
      proc =
        unless options.log
          spawn cmd[0], cmd[1..], stdio: 'inherit'
        else
          spawn cmd[0], cmd[1..]
      stdout = stderr = ''

      if options.log
        proc.stdout.on 'data', (buffer) ->
          out = buffer.toString()
          stdout += out
          log(out) unless options.silent
        proc.stderr.on 'data', (buffer) ->
          err = buffer.toString()
          stderr += err
          log(err) unless options.silent

      proc.on 'exit', (status) ->
        if status != 0
          defer.resolve new Error stderr or stdout
        else
          defer.resolve stdout
      defer.promise


log
---

    log = (msg, color = 'white', prefix = '   ') ->
      if msg then for line in msg.trim().split '\n'
        line = line.trim()
        console.log prefix + if color then line[color] else line

    log.info = (msg) ->
      log msg, 'green', '>> '.bold

    log.error = (msg) ->
      msg = msg?.message or msg
      log msg, 'red', '>> '.bold


errorAndExit
------------

    errorAndExit = (msg, code = 1) ->
      log.error msg
      process.exit code


---

main
====

Parse the arguments.

    args = parser.parseArgs()

Collect some constant info about the environment.

    BASH = '/bin/bash'
    ZSH = '/usr/local/bin/zsh'
    USER = 'ede'

Call the appropriate subcommand.

    switch args.command
      when 'use' then use(args.shell, args.save)
