ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Mindwendel.Repo, :manual)

# for file upload tests
upload_path = "priv/static/uploads/"
File.mkdir_p!(Path.dirname(upload_path))

# Mock Chat Completions Service:
Mox.defmock(Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock,
  for: Mindwendel.Services.ChatCompletions.ChatCompletionsService
)

Application.put_env(
  :mindwendel,
  :chat_completions_service,
  Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
)
