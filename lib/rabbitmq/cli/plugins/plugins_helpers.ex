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

defmodule RabbitMQ.CLI.Plugins.Helpers do
  import Rabbitmq.Atom.Coerce
  import RabbitCommon.Records

  alias RabbitMQ.CLI.Core.Helpers, as: CliHelpers
  alias RabbitMQ.CLI.Core.Config, as: Config

  def requires_rabbit_app_running?(online, offline) do
    case get_mode(online, offline) do
      :online -> true
      :offline -> false
    end
  end

  def get_mode(online, offline) do
    case {online, offline} do
      {true, false}  -> :online
      {false, true}  -> :offline
      # fallback to online mode
      {false, false} -> :online
    end
  end

  def list(opts) do
    {:ok, dir} = CliHelpers.plugins_dir(opts)
    add_all_to_path(dir)
    :lists.usort(:rabbit_plugins.list(to_charlist(dir)))
  end

  def read_enabled(opts) do
    case enabled_plugins_file(opts) do
      {:ok, enabled} ->
        :rabbit_plugins.read_enabled(to_charlist(enabled));
      # Existence of enabled_plugins_file should be validated separately
      {:error, :no_plugins_file} ->
        []
    end
  end

  def enabled_plugins_file(opts) do
    case Config.get_option(:enabled_plugins_file, opts) do
      nil  -> {:error, :no_plugins_file};
      file -> {:ok, file}
    end
  end

  def set_enabled_plugins(plugins, opts) do
    plugin_atoms = :lists.usort(for plugin <- plugins, do: to_atom(plugin))
    CliHelpers.require_rabbit_and_plugins(opts)
    {:ok, plugins_file} = enabled_plugins_file(opts)
    write_enabled_plugins(plugin_atoms, plugins_file, opts)
  end

  def update_enabled_plugins(enabled_plugins, mode, node_name, opts) do
    {:ok, plugins_file} = enabled_plugins_file(opts)
    case mode do
      :online  ->
        case update_enabled_plugins(node_name, plugins_file) do
          {:ok, started, stopped} ->
            %{mode: :online,
              started: Enum.sort(started),
              stopped: Enum.sort(stopped),
              set: Enum.sort(enabled_plugins)};
          {:error, :offline} ->
            %{mode: :offline, set: Enum.sort(enabled_plugins)};
          {:error, {:enabled_plugins_mismatch, _, _}} = err ->
            err
        end;
      :offline ->
        %{mode: :offline,
          set: Enum.sort(enabled_plugins)}
    end
  end

  def validate_plugins(requested_plugins, opts) do
    ## Maybe check all plugins
    plugins = case opts do
      %{all: true} -> plugin_names(list(opts))
      _            -> requested_plugins
    end

    all = list(opts)
    deps = :rabbit_plugins.dependencies(false, plugins, all)

    deps_plugins = Enum.filter(all, fn(plugin) ->
      name = plugin_name(plugin)
      Enum.member?(deps, name)
    end)

    case :rabbit_plugins.validate_plugins(deps_plugins) do
      {_, []}     -> :ok;
      {_, invalid} -> {:error, :rabbit_plugins.format_invalid_plugins(invalid)}
    end
  end

  def plugin_name(plugin) do
    plugin(name: name) = plugin
    name
  end

  def plugin_names(plugins) do
    for plugin <- plugins, do: plugin_name(plugin)
  end

  defp to_list(str) when is_binary(str) do
    :erlang.binary_to_list(str)
  end

  defp to_list(lst) when is_list(lst) do
    lst
  end

  defp to_list(atm) when is_atom(atm) do
    to_list(Atom.to_string(atm))
  end

  defp write_enabled_plugins(plugins, plugins_file, opts) do
    all              = list(opts)
    all_plugin_names = Enum.map(all, &plugin_name/1)

    case MapSet.difference(MapSet.new(plugins), MapSet.new(all_plugin_names)) do
      %MapSet{} ->
        case :rabbit_file.write_term_file(to_charlist(plugins_file), [plugins]) do
          :ok ->
            all_enabled = :rabbit_plugins.dependencies(false, plugins, all)
            {:ok, Enum.sort(all_enabled)};
          {:error, reason} ->
            {:error, {:cannot_write_enabled_plugins_file, plugins_file, reason}}
        end;
      missing  ->
        {:error, {:plugins_not_found, missing}}
    end
  end

  defp update_enabled_plugins(node_name, plugins_file) do
    case :rabbit_misc.rpc_call(node_name, :rabbit_plugins,
                                          :ensure, [to_list(plugins_file)]) do
      {:badrpc, :nodedown} -> {:error, :offline};
      {:ok, start, stop}   -> {:ok, start, stop};
      {:error, _} = err    -> err
    end
  end

  defp add_all_to_path(plugins_directories) do
    directories = String.split(to_string(plugins_directories), CliHelpers.separator())
    Enum.map(directories, fn(directory) ->
        with {:ok, subdirs} <- File.ls(directory)
        do
          for subdir <- subdirs do
            Path.join([directory, subdir, "ebin"])
            |> Code.append_path
          end
        end
    end)
    :ok
  end
end
