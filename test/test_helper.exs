ExUnit.start(capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(Mindwendel.Repo, :manual)

# for file upload tests
upload_path = "priv/static/uploads/"
File.mkdir_p!(Path.dirname(upload_path))

# Define the mock - it will be configured per-test via test case setups
Mox.defmock(Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock,
  for: Mindwendel.Services.ChatCompletions.ChatCompletionsService
)

# Configure to use the mock in tests
# Each test case (ChatCompletionsCase, ConnCase, DataCase) will set up appropriate stubs/expectations
Application.put_env(
  :mindwendel,
  :chat_completions_service,
  Mindwendel.Services.ChatCompletions.ChatCompletionsServiceMock
)
