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


alias RabbitMQ.CLI.Core.Helpers, as: Helpers
alias RabbitMQ.CLI.Core.Config, as: Config

defmodule RabbitMQ.CLI.Ctl.Commands.StartCommand do
  @behaviour RabbitMQ.CLI.CommandBehaviour
  use RabbitMQ.CLI.DefaultOutput

  def merge_defaults(args, opts), do: {args, opts}

  def formatter(), do: RabbitMQ.CLI.Formatters.Inspect

  def validate([], _), do: :ok

  def run([], opts) do
    start_distribution(opts)
    Helpers.add_plugins_to_load_path(opts)
    # RABBITMQ_CONFIG_ARG
    Application.load(:mnesia)
    Application.load(:rabbit)
    Application.put_env(:rabbit, :tcp_listeners,
      [{get_env("RABBITMQ_NODE_IP_ADDRESS", opts), get_env("RABBITMQ_NODE_PORT", opts)}])

    case System.get_env("RABBITMQ_MNESIA_DIR") do
      nil -> :ok
      val -> Application.put_env(:mnesia, :dir, to_charlist(val))
    end

    case Config.get_option(:enabled_plugins_file, opts) do
      nil ->
        Application.put_env(:rabbit, :enabled_plugins_file,
                            to_charlist(Path.join(:mnesia.dir(), "enabled_plugins")))
      val ->
        Application.put_env(:rabbit, :enabled_plugins_file, to_charlist(val))
    end
    case Config.get_option(:plugins_dir, opts) do
      nil -> :ok
      val ->
        Application.put_env(:rabbit, :plugins_dir, to_charlist(val))
    end
    case System.get_env("RABBITMQ_PLUGINS_EXPAND_DIR") do
      nil -> :ok
      val ->
        Application.put_env(:rabbit, :plugins_expand_dir, to_charlist(val))
    end

    :rabbit.boot()
    receive do
    end
  end

  defp get_env(env, opts) do
    case System.get_env(env) do
      nil -> default_env(env, opts);
      val -> val
    end
  end

  defp default_env("RABBITMQ_NODE_IP_ADDRESS", _) do
    'auto'
  end
  defp default_env("RABBITMQ_NODE_PORT", _) do
    5672
  end

  defp start_distribution(opts) do
    :ok = :net_kernel.stop()
    RabbitMQ.CLI.Core.Distribution.start_as(opts[:node], opts)
  end

  def usage, do: "start"

  def banner(_, _), do: "Starting an embedded RabbitMQ server"

end
