IO.puts("Prepare to run tests...")

Application.ensure_all_started(:bonfire)

Code.ensure_loaded!(Bonfire.Common.Testing)
Bonfire.Common.Testing.configure_start_test()
