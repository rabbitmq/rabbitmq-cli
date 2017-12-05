
%%! +A 200 -pa .
main(_) ->
    io:format("Extra ~p~n", [init:get_arguments()]),
    io:format("Thread pool is ~p~n", [erlang:system_info(thread_pool_size)]),

    io:format("Applications ~p~n", [application:which_applications()]),

    Env = application_controller:prep_config_change(),

    io:format("Env before ~p~n", [Env]),

    io:format("Global groups ~p~n", [global_group:global_groups()]),

    application:set_env(kernel, global_groups, [{cli, hidden, [node@MacBookdfedotov]}]),

    io:format("Config change ~p~n", [application_controller:config_change(Env)]),

    io:format("Kernel ~p~n", [application:get_all_env(kernel)]),

    {ok, _} = net_kernel:start([node@MacBookdfedotov, shortnames]),


    receive after 100000 -> ok end.
