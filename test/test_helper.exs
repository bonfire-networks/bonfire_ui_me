IO.puts("Prepare to run tests...")

Application.ensure_all_started(:bonfire)

Code.ensure_loaded!(Bonfire.Testing)
Bonfire.Testing.configure_start_test()
