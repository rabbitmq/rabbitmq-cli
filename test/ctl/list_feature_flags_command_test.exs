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
## Copyright (c) 2018-2019 Pivotal Software, Inc.  All rights reserved.

defmodule ListFeatureFlagsCommandTest do
  use ExUnit.Case, async: false
  import TestHelper

  @command RabbitMQ.CLI.Ctl.Commands.ListFeatureFlagsCommand

  @flag1 :implicit_default_bindings
  @flag2 :quorum_queue

  setup_all do
    RabbitMQ.CLI.Core.Distribution.start()

    name_result = [
      [{:name, @flag1}],
      [{:name, @flag2}]
    ]

    full_result = [
      [{:name, @flag1}, {:state, :enabled}],
      [{:name, @flag2}, {:state, :enabled}]
    ]

    {
      :ok,
      name_result: name_result,
      full_result: full_result
    }
  end

  setup context do
    {
      :ok,
      opts: %{node: get_rabbit_hostname(), timeout: context[:test_timeout]}
    }
  end

  test "merge_defaults with no command, print just use the names" do
    assert match?({["name", "state"], %{}}, @command.merge_defaults([], %{}))
  end

  test "validate: return bad_info_key on a single bad arg", context do
    assert @command.validate(["quack"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:quack]}}
  end

  test "validate: multiple bad args return a list of bad info key values", context do
    assert @command.validate(["quack", "oink"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:oink, :quack]}}
  end

  test "validate: return bad_info_key on mix of good and bad args", context do
    assert @command.validate(["quack", "name"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:quack]}}
    assert @command.validate(["name", "oink"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:oink]}}
    assert @command.validate(["name", "oink", "state"], context[:opts]) ==
      {:validation_failure, {:bad_info_key, [:oink]}}
  end

  test "run: on a bad RabbitMQ node, return a badrpc" do
    target = :jake@thedog
    opts = %{node: target, timeout: :infinity}
    assert @command.run(["name"], opts) == {:badrpc, :nodedown}
  end

  @tag test_timeout: :infinity
  test "run: with the name tag, print just the names", context do
    matches_found = @command.run(["name"], context[:opts])
    assert Enum.all?(context[:name_result], fn(vhost) ->
      Enum.find(matches_found, fn(found) -> found == vhost end)
    end)
  end

  @tag test_timeout: :infinity
  test "run: duplicate args do not produce duplicate entries", context do
    # checks to ensure that all expected vhosts are in the results
    matches_found = @command.run(["name", "name"], context[:opts])
    assert Enum.all?(context[:name_result], fn(vhost) ->
      Enum.find(matches_found, fn(found) -> found == vhost end)
    end)
  end

  @tag test_timeout: 30000
  test "run: sufficiently long timeouts don't interfere with results", context do
    matches_found = @command.run(["name", "state"], context[:opts])
    assert Enum.all?(context[:full_result], fn(vhost) ->
      Enum.find(matches_found, fn(found) -> found == vhost end)
    end)
  end

  @tag test_timeout: 0, username: "guest"
  test "run: timeout causes command to return a bad RPC", context do
    assert @command.run(["name", "state"], context[:opts]) ==
      {:badrpc, :timeout}
  end

  @tag test_timeout: :infinity
  test "banner", context do
    assert @command.banner([], context[:opts]) =~ ~r/Listing feature flags \.\.\./
  end
end
