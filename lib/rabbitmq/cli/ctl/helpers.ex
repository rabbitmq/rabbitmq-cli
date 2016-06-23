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
## Copyright (c) 2007-2016 Pivotal Software, Inc.  All rights reserved.


# Small helper functions, mostly related to connecting to RabbitMQ and
# handling memory units.

defmodule RabbitMQ.CLI.Ctl.Helpers do
  alias RabbitMQ.CLI.Ctl.CommandModules, as: CommandModules

  ## module_map will use rabbitmqctl application environment
  ## to load enabled commands
  def commands do
    CommandModules.module_map
  end

  def is_command?([]), do: true
  def is_command?([head | _]), do: is_command?(head)
  def is_command?(str), do: implements_command_behaviour?(commands[str])

  defp implements_command_behaviour?(nil) do
    false
  end
  defp implements_command_behaviour?(module) do
    [RabbitMQ.CLI.CommandBehaviour] === module.module_info(:attributes)[:behaviour]
  end

  def get_rabbit_hostname(), do: ("rabbit@#{hostname}") |> String.to_atom

  def parse_node(nil), do: get_rabbit_hostname
  def parse_node(host) when is_atom(host), do: host
  def parse_node(host) do
    case String.split(host, "@", parts: 2) do
      [_,""] -> host <> "#{hostname}" |> String.to_atom
      [_,_] -> host |> String.to_atom
      [_] -> host <> "@#{hostname}" |> String.to_atom
    end
  end

  def connect_to_rabbitmq, do:        :net_kernel.connect_node(get_rabbit_hostname)
  def connect_to_rabbitmq(input) when is_atom(input), do: :net_kernel.connect_node(input)
  def connect_to_rabbitmq(input) when is_binary(input) do
    input
    |> String.to_atom
    |> :net_kernel.connect_node
  end

  defp hostname, do: :inet.gethostname() |> elem(1) |> List.to_string

  def memory_units do
    ["k", "kiB", "M", "MiB", "G", "GiB", "kB", "MB", "GB", ""]
  end

  def memory_unit_absolute(num, unit) when is_number(num) and num < 0, do: {:bad_argument, [num, unit]}

  def memory_unit_absolute(num, "k") when is_number(num),   do: power_as_int(num, 2, 10)
  def memory_unit_absolute(num, "kiB") when is_number(num), do: power_as_int(num, 2, 10)
  def memory_unit_absolute(num, "M") when is_number(num),   do: power_as_int(num, 2, 20)
  def memory_unit_absolute(num, "MiB") when is_number(num), do: power_as_int(num, 2, 20)
  def memory_unit_absolute(num, "G") when is_number(num),   do: power_as_int(num, 2, 30)
  def memory_unit_absolute(num, "GiB") when is_number(num), do: power_as_int(num, 2, 30)
  def memory_unit_absolute(num, "kB") when is_number(num),  do: power_as_int(num, 10, 3)
  def memory_unit_absolute(num, "MB") when is_number(num),  do: power_as_int(num, 10, 6)
  def memory_unit_absolute(num, "GB") when is_number(num),  do: power_as_int(num, 10, 9)
  def memory_unit_absolute(num, "") when is_number(num), do: num
  def memory_unit_absolute(num, unit) when is_number(num), do: {:bad_argument, [unit]}
  def memory_unit_absolute(num, unit), do: {:bad_argument, [num, unit]}

  def power_as_int(num, x, y), do: round(num * (:math.pow(x, y)))

  def global_flags, do: [:node, :quiet, :timeout, :longnames]

  def nodes_in_cluster(node, timeout \\ :infinity) do
    case :rpc.call(node, :rabbit_mnesia, :cluster_nodes, [:running], timeout) do
      {:badrpc, _} = err -> throw(err);
      value              -> value
    end
  end
end
