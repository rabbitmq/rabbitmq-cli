## The contents of this file are subject to the Mozilla Public License
## Version 1.1 (the "License"); you may not use this file except in
## compliance with the License. You may obtain a copy of the License
## at http://www.mozilla.org/MPL/
##
## Software distributed under the License is distributed on an "AS IS"
## basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
## the License for the specific language governing rights and
## limitations under the License.
##
## The Original Code is RabbitMQ.
##
## The Initial Developer of the Original Code is GoPivotal, Inc.
## Copyright (c) 2007-2017 Pivotal Software, Inc.  All rights reserved.

defmodule RabbitMQCtl.MixfileBase do
  use Mix.Project

  def project do
    deps_dir = case System.get_env("DEPS_DIR") do
      nil -> "deps"
      dir -> dir
    end
    [
      app: :rabbitmqctl,
      version: "0.0.1",
      elixir: "~> 1.4.4 or ~> 1.5",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      escript: [main_module: RabbitMQCtl,
                emu_args: "-hidden",
                path: "escript/rabbitmqctl"],
      deps_path: deps_dir,
      deps: deps(deps_dir),
      aliases: aliases()
   ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger],
     env: [scopes: ['rabbitmq-plugins': :plugins,
                    rabbitmqctl: :ctl,
                    'rabbitmq-diagnostics': :diagnostics]]
    ]
    |> add_modules(Mix.env)
  end


  defp add_modules(app, :test) do
    # There are issues with building a package without this line ¯\_(ツ)_/¯
    Mix.Project.get
    path = Mix.Project.compile_path
    mods = modules_from(Path.wildcard("#{path}/*.beam"))
    test_modules = [RabbitMQ.CLI.Ctl.Commands.DuckCommand,
                    RabbitMQ.CLI.Ctl.Commands.GrayGooseCommand,
                    RabbitMQ.CLI.Ctl.Commands.UglyDucklingCommand,
                    RabbitMQ.CLI.Plugins.Commands.StorkCommand,
                    RabbitMQ.CLI.Plugins.Commands.HeronCommand,
                    RabbitMQ.CLI.Custom.Commands.CrowCommand,
                    RabbitMQ.CLI.Custom.Commands.RavenCommand,
                    RabbitMQ.CLI.Seagull.Commands.SeagullCommand,
                    RabbitMQ.CLI.Seagull.Commands.PacificGullCommand,
                    RabbitMQ.CLI.Seagull.Commands.HerringGullCommand,
                    RabbitMQ.CLI.Seagull.Commands.HermannGullCommand,
                    RabbitMQ.CLI.Wolf.Commands.CanisLupusCommand,
                    RabbitMQ.CLI.Wolf.Commands.CanisLatransCommand,
                    RabbitMQ.CLI.Wolf.Commands.CanisAureusCommand
                  ]
    [{:modules, mods ++ test_modules |> Enum.sort} | app]
  end
  defp add_modules(app, _) do
    app
  end

  defp modules_from(beams) do
    Enum.map beams, &(&1 |> Path.basename |> Path.rootname(".beam") |> String.to_atom)
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps(deps_dir) do
    [
      # We use `true` as the command to "build" rabbit_common and
      # amqp_client because Erlang.mk already built them.
      {
        :rabbit_common,
        path: Path.join(deps_dir, "rabbit_common"),
        compile: "true",
        override: true
      },
      {
        :amqp_client,
        only: :test,
        path: Path.join(deps_dir, "amqp_client"),
        compile: "true",
        override: true
      },
      {:amqp, "~> 0.2.2", only: :test},
      {:temp, "~> 0.4", only: :test},
      {:json, "~> 1.0.0"},
      {:csv, "~> 2.0.0"},
      {:simetric, "~> 0.2.0"}
    ]
  end

  defp aliases do
    [
      make_deps: [
        "deps.get",
        "deps.compile",
      ],
      make_app: [
        "compile",
        "escript.build",
      ],
      make_all: [
        "deps.get",
        "deps.compile",
        "compile",
        "escript.build",
      ],
    ]
  end
end
