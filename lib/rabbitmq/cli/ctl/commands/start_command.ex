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
    init_config(opts)
    start_distribution(opts)
    Helpers.add_plugins_to_load_path(opts)
    # RABBITMQ_CONFIG_ARG
    :ok = Application.load(:mnesia)
    :ok = Application.load(:rabbit)
    Application.put_env(:rabbit, :tcp_listeners,
      [{get_env("RABBITMQ_NODE_IP_ADDRESS", opts), get_env("RABBITMQ_NODE_PORT", opts)}])

    case System.get_env("RABBITMQ_MNESIA_DIR") do
      nil -> :ok
      val -> Application.put_env(:mnesia, :dir, to_charlist(val))
    end

    case Config.get_option(:enabled_plugins_file, opts) do
      nil ->
        Application.put_env(:rabbit, :enabled_plugins_file,
                            to_charlist(Path.join(:rabbit_mnesia.dir(), "enabled_plugins")))
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
    configure_kernel()
    RabbitMQ.CLI.Core.Distribution.start_as(opts[:node], opts)
  end

  def usage, do: "start"

  def banner(_, _), do: "Starting an embedded RabbitMQ server"

  defp configure_kernel() do
    env = :application_controller.prep_config_change()
    :application.set_env(:kernel, :inet_default_connect_options, [{:nodelay,true}])
    :application.set_env(:kernel, :inet_dist_listen_min, System.get_env("RABBITMQ_DIST_PORT"))
    :application.set_env(:kernel, :inet_dist_listen_max, System.get_env("RABBITMQ_DIST_PORT"))
    :application_controller.config_change(env)
  end


  defp init_config(opts) do
    init_dist_port(opts)

    init_config_arg(opts)

    RABBITMQ_NODE_PORT and RABBITMQ_NODE_IP_ADDRESS

    RABBITMQ_CONFIG_FILE=$RABBITMQ_CONFIG_FILE \
    ERL_MAX_ETS_TABLES=$ERL_MAX_ETS_TABLES \
    ERL_CRASH_DUMP=$ERL_CRASH_DUMP \

    -sasl errlog_type error \
    -sasl sasl_error_logger "$SASL_ERROR_LOGGER" \
    -rabbit lager_log_root "\"$RABBITMQ_LOG_BASE\"" \
    -rabbit lager_default_file "$RABBIT_LAGER_HANDLER" \
    -rabbit lager_upgrade_file "$RABBITMQ_LAGER_HANDLER_UPGRADE" \
    -rabbit enabled_plugins_file "\"$RABBITMQ_ENABLED_PLUGINS_FILE\"" \
    -rabbit plugins_dir "\"$RABBITMQ_PLUGINS_DIR\"" \
    -rabbit plugins_expand_dir "\"$RABBITMQ_PLUGINS_EXPAND_DIR\"" \
    -os_mon start_cpu_sup false \
    -os_mon start_disksup false \
    -os_mon start_memsup false \
    -mnesia dir "\"${RABBITMQ_MNESIA_DIR}\"" \


  end

  defp init_dist_port(opts) do
    [ "x" = "x$RABBITMQ_DIST_PORT" ] && RABBITMQ_DIST_PORT=${DIST_PORT}
    [ "x" = "x$RABBITMQ_DIST_PORT" ] && [ "x" = "x$RABBITMQ_NODE_PORT" ] && RABBITMQ_DIST_PORT=$((${DEFAULT_NODE_PORT} + 20000))
    [ "x" = "x$RABBITMQ_DIST_PORT" ] && [ "x" != "x$RABBITMQ_NODE_PORT" ] && RABBITMQ_DIST_PORT=$((${RABBITMQ_NODE_PORT} + 20000))
  end

  defp init_config_arg(opts) do



ENABLED_PLUGINS_FILE=${SYS_PREFIX}/etc/rabbitmq/enabled_plugins
GENERATED_CONFIG_DIR=${SYS_PREFIX}/var/lib/rabbitmq/config
ADVANCED_CONFIG_FILE=${SYS_PREFIX}/etc/rabbitmq/advanced
SCHEMA_DIR=${SYS_PREFIX}/var/lib/rabbitmq/schema


[ "x" = "x$RABBITMQ_GENERATED_CONFIG_DIR" ] && RABBITMQ_GENERATED_CONFIG_DIR=${GENERATED_CONFIG_DIR}
[ "x" = "x$RABBITMQ_ADVANCED_CONFIG_FILE" ] && RABBITMQ_ADVANCED_CONFIG_FILE=${ADVANCED_CONFIG_FILE}
[ "x" = "x$RABBITMQ_SCHEMA_DIR" ] && RABBITMQ_SCHEMA_DIR=${SCHEMA_DIR}


if [ ! -d ${RABBITMQ_SCHEMA_DIR} ]; then
    mkdir -p "${RABBITMQ_SCHEMA_DIR}"
fi

if [ ! -d ${RABBITMQ_GENERATED_CONFIG_DIR} ]; then
    mkdir -p "${RABBITMQ_GENERATED_CONFIG_DIR}"
fi

if [ ! -f "${RABBITMQ_SCHEMA_DIR}/rabbit.schema" ]; then
    cp "${RABBITMQ_HOME}/priv/schema/rabbit.schema" "${RABBITMQ_SCHEMA_DIR}"
fi


RABBITMQ_ADVANCED_CONFIG_FILE_NOEX="${RABBITMQ_ADVANCED_CONFIG_FILE%.*}"
if [ "${RABBITMQ_ADVANCED_CONFIG_FILE_NOEX}.config" = "${RABBITMQ_ADVANCED_CONFIG_FILE}" ]; then
    RABBITMQ_ADVANCED_CONFIG_FILE="${RABBITMQ_ADVANCED_CONFIG_FILE_NOEX}"
fi


    [ "x" = "x$RABBITMQ_CONFIG_FILE" ] && RABBITMQ_CONFIG_FILE=${CONFIG_FILE}

    rmq_check_if_shared_with_mnesia \
    RABBITMQ_CONFIG_FILE \


    RABBITMQ_CONFIG_FILE_NOEX="${RABBITMQ_CONFIG_FILE%.*}"
    if [ "${RABBITMQ_CONFIG_FILE_NOEX}.config" = "${RABBITMQ_CONFIG_FILE}" ]; then
    if [ -f "${RABBITMQ_CONFIG_FILE}" ]; then
        RABBITMQ_CONFIG_ARG="-config ${RABBITMQ_CONFIG_FILE_NOEX}"
    fi
elif [ "${RABBITMQ_CONFIG_FILE_NOEX}.conf" = "${RABBITMQ_CONFIG_FILE}" ]; then
    RABBITMQ_CONFIG_ARG="-conf ${RABBITMQ_CONFIG_FILE_NOEX} \
                         -conf_dir ${RABBITMQ_GENERATED_CONFIG_DIR} \
                         -conf_script_dir `dirname $0` \
                         -conf_schema_dir ${RABBITMQ_SCHEMA_DIR}"
    if [ -f "${RABBITMQ_ADVANCED_CONFIG_FILE}.config" ]; then
        RABBITMQ_CONFIG_ARG="${RABBITMQ_CONFIG_ARG} \
                             -conf_advanced ${RABBITMQ_ADVANCED_CONFIG_FILE} \
                             -config ${RABBITMQ_ADVANCED_CONFIG_FILE}"
    fi
else
    if [ -f "${RABBITMQ_CONFIG_FILE}.config" ]; then
        RABBITMQ_CONFIG_ARG="-config ${RABBITMQ_CONFIG_FILE}"
    elif [ -f "${RABBITMQ_CONFIG_FILE}.conf" ]; then
        RABBITMQ_CONFIG_ARG="-conf ${RABBITMQ_CONFIG_FILE} \
                             -conf_dir ${RABBITMQ_GENERATED_CONFIG_DIR} \
                             -conf_script_dir `dirname $0` \
                             -conf_schema_dir ${RABBITMQ_SCHEMA_DIR}"
        if [ -f "${RABBITMQ_ADVANCED_CONFIG_FILE}.config" ]; then
            RABBITMQ_CONFIG_ARG="${RABBITMQ_CONFIG_ARG} \
                                 -conf_advanced ${RABBITMQ_ADVANCED_CONFIG_FILE} \
                                 -config ${RABBITMQ_ADVANCED_CONFIG_FILE}"
        fi
    fi
fi
  end

end
