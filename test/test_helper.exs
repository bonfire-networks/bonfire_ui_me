IO.puts("Start app...")
Application.ensure_all_started(:bonfire)

IO.puts("Prepare to run tests...")
Code.ensure_loaded!(Bonfire.Testing)
Bonfire.Testing.configure_start_test()
