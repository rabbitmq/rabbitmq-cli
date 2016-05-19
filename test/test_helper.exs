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


ExUnit.start()

defmodule TestHelper do
  import ExUnit.Assertions

  def get_rabbit_hostname() do
   "rabbit@" <> hostname() |> String.to_atom()
  end

  def hostname() do
    elem(:inet.gethostname,1) |> List.to_string()
  end

  def add_vhost(name) do
    :rpc.call(get_rabbit_hostname, :rabbit_vhost, :add, [name])
  end

  def delete_vhost(name) do
    :rpc.call(get_rabbit_hostname, :rabbit_vhost, :delete, [name])
  end

  def list_vhosts() do
    :rpc.call(get_rabbit_hostname, :rabbit_vhost, :info_all, [])
  end

  def add_user(name, password) do
    :rpc.call(get_rabbit_hostname, :rabbit_auth_backend_internal, :add_user, [name, password])
  end

  def delete_user(name) do
    :rpc.call(get_rabbit_hostname, :rabbit_auth_backend_internal, :delete_user, [name])
  end

  def list_users() do
    :rpc.call(get_rabbit_hostname, :rabbit_auth_backend_internal, :list_users, [])
  end

  def trace_on(vhost) do
    :rpc.call(get_rabbit_hostname, :rabbit_trace, :start, [vhost])
  end

  def trace_off(vhost) do
    :rpc.call(get_rabbit_hostname, :rabbit_trace, :stop, [vhost])
  end

  def set_user_tags(name, tags) do
    :rpc.call(get_rabbit_hostname, :rabbit_auth_backend_internal, :set_tags, [name, tags])
  end

  def authenticate_user(name, password) do
    :rpc.call(get_rabbit_hostname, :rabbit_access_control,:check_user_pass_login, [name, password])
  end

  def clear_parameter(vhost, component_name, key) do
    :rpc.call(get_rabbit_hostname, :rabbit_runtime_parameters, :clear, [vhost, component_name, key])
  end

  def list_parameters(vhost) do
    :rpc.call(get_rabbit_hostname, :rabbit_runtime_parameters, :list_formatted, [vhost])
  end

  def set_permissions(user, vhost, [conf, write, read]) do
    :rpc.call(get_rabbit_hostname, :rabbit_auth_backend_internal, :set_permissions, [user, vhost, conf, write, read])
  end

  def declare_queue(name, vhost, durable \\ false, auto_delete \\ false, args \\ [], owner \\ :none) do
    queue_name = :rabbit_misc.r(vhost, :queue, name)
    :rpc.call(get_rabbit_hostname,
              :rabbit_amqqueue, :declare,
              [queue_name, durable, auto_delete, args, owner])
  end

  def declare_exchange(name, vhost, type \\ :direct, durable \\ false, auto_delete \\ false, internal \\ false, args \\ []) do
    exchange_name = :rabbit_misc.r(vhost, :exchange, name)
    :rpc.call(get_rabbit_hostname,
              :rabbit_exchange, :declare,
              [exchange_name, type, durable, auto_delete, internal, args])
  end

  def list_permissions(vhost) do
    :rpc.call(
      get_rabbit_hostname,
      :rabbit_auth_backend_internal,
      :list_vhost_permissions,
      [vhost],
      :infinity
    )
  end

  def set_disk_free_limit(limit) do
    :rpc.call(get_rabbit_hostname, :rabbit_disk_monitor, :set_disk_free_limit, [limit])
  end

  def status do
    :rpc.call(get_rabbit_hostname, :rabbit, :status, [])
  end

  def error_check(cmd_line, code) do
    assert catch_exit(RabbitMQCtl.main(cmd_line)) == {:shutdown, code}
  end

  def with_channel(vhost, fun) do
    with_connection(vhost,
      fn(conn) ->
        {:ok, chan} = AMQP.Channel.open(conn)
        fun.(chan)
      end)
  end

  def with_connection(vhost, fun) do
    {:ok, conn} = AMQP.Connection.open(virtual_host: vhost)
    ExUnit.Callbacks.on_exit(fn ->
      try do
        AMQP.Connection.close(conn)
      catch
        :exit, _ -> :ok
      end
    end)
    fun.(conn)
    AMQP.Connection.close(conn)
  end

  def emit_list(list, ref, pid) do
    emit_list_map(list, &(&1), ref, pid)
  end

  def emit_list_map(list, fun, ref, pid) do
    :rabbit_control_misc.emitting_map(pid, ref, fun, list)
  end

end
