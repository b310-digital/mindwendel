ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Mindwendel.Repo, :manual)

# for file upload tests
upload_path = "priv/static/uploads/"
File.mkdir_p!(Path.dirname(upload_path))
