defmodule ListChannelsCommandTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  import TestHelper

  @user "guest"
  @default_timeout :infinity

  setup_all do
    :net_kernel.start([:rabbitmqctl, :shortnames])
    :net_kernel.connect_node(get_rabbit_hostname)

    on_exit([], fn ->
      :erlang.disconnect_node(get_rabbit_hostname)
      :net_kernel.stop()
    end)

    :ok
  end

  setup context do
    {
      :ok,
      opts: %{
        node: get_rabbit_hostname,
        timeout: context[:test_timeout] || @default_timeout
      }
    }
  end

  test "return bad_info_key on a single bad arg", context do
    capture_io(fn ->
      assert ListChannelsCommand.run(["quack"], context[:opts]) ==
        {:error, {:bad_info_key, [:quack]}}
    end)
  end

  test "multiple bad args return a list of bad info key values", context do
    capture_io(fn ->
      assert ListChannelsCommand.run(["quack", "oink"], context[:opts]) ==
        {:error, {:bad_info_key, [:quack, :oink]}}
    end)
  end

  test "return bad_info_key on mix of good and bad args", context do
    capture_io(fn ->
      assert ListChannelsCommand.run(["quack", "pid"], context[:opts]) ==
        {:error, {:bad_info_key, [:quack]}}
      assert ListChannelsCommand.run(["user", "oink"], context[:opts]) ==
        {:error, {:bad_info_key, [:oink]}}
      assert ListChannelsCommand.run(["user", "oink", "pid"], context[:opts]) ==
        {:error, {:bad_info_key, [:oink]}}
    end)
  end

  @tag test_timeout: 0
  test "zero timeout causes command to return badrpc", context do
    capture_io(fn ->
      assert ListChannelsCommand.run([], context[:opts]) ==
        [{:badrpc, :timeout}]
    end)
  end

  test "no channels by default", context do
    capture_io(fn ->
      assert [] == ListChannelsCommand.run([], context[:opts])
    end)
  end

  test "default channel info keys are pid, user, consumer_count, and messages_unacknowledged", context do
    capture_io(fn ->
      with_channel("/", fn(_channel) ->
        [chan] = ListChannelsCommand.run([], context[:opts])
        assert Keyword.keys(chan) == ~w(pid user consumer_count messages_unacknowledged)a
        assert [user: "guest", consumer_count: 0, messages_unacknowledged: 0] == Keyword.delete(chan, :pid)
      end)
    end)
  end

  test "multiple channels on multiple connections", context do
    capture_io(fn ->
      with_channel("/", fn(_channel1) ->
        with_channel("/", fn(_channel2) ->
          [chan1, chan2] = ListChannelsCommand.run(["pid", "user", "connection"], context[:opts])
          assert Keyword.keys(chan1) == ~w(pid user connection)a
          assert Keyword.keys(chan2) == ~w(pid user connection)a
          assert "guest" == chan1[:user]
          assert "guest" == chan2[:user]
          assert chan1[:pid] !== chan2[:pid]
          assert chan1[:connection] !== chan2[:connection]
        end)
      end)
    end)
  end

  test "multiple channels on single connection", context do
    capture_io(fn ->
      with_connection("/", fn(conn) ->
        {:ok, _} = AMQP.Channel.open(conn)
        {:ok, _} = AMQP.Channel.open(conn)

        [chan1, chan2] = ListChannelsCommand.run(["pid", "user", "connection"], context[:opts])
        assert Keyword.keys(chan1) == ~w(pid user connection)a
        assert Keyword.keys(chan2) == ~w(pid user connection)a
        assert "guest" == chan1[:user]
        assert "guest" == chan2[:user]
        assert chan1[:pid] !== chan2[:pid]
        assert chan1[:connection] == chan2[:connection]
      end)
    end)
  end

  test "info keys order is preserved", context do
    capture_io(fn ->
      with_channel("/", fn(_channel) ->
        [chan] = ListChannelsCommand.run(~w(connection vhost name pid number user), context[:opts])
        assert Keyword.keys(chan) == ~w(connection vhost name pid number user)a
      end)
    end)
  end
end