ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Mindwendel.Repo, :manual)

# for file upload tests
upload_path = "priv/static/uploads/"
File.mkdir_p!(Path.dirname(upload_path))

# Define mocks - they will be configured per-test via test case setups
Mox.defmock(Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock,
  for: Mindwendel.Services.ChatCompletions.ChatCompletionsService
)

Mox.defmock(Mindwendel.AI.Config.Mock, for: Mindwendel.AI.Config)

# Configure to use mocks in tests
# Each test case (ChatCompletionsCase, ConnCase, DataCase) will set up appropriate stubs/expectations
Application.put_env(
  :mindwendel,
  :chat_completions_service,
  Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
)

Application.put_env(:mindwendel, :ai_config_service, Mindwendel.AI.Config.Mock)
