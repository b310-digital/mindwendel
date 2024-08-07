ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Mindwendel.Repo, :manual)

# Mock Chat Completions Service:
Mox.defmock(Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock,
  for: Mindwendel.Services.ChatCompletions.ChatCompletionsService
)

Application.put_env(
  :mindwendel,
  :chat_completions_service,
  Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
)
