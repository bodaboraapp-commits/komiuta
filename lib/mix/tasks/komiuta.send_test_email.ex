defmodule Mix.Tasks.Komiuta.SendTestEmail do
  @shortdoc "Sends a test transactional email (email OTP delivery check)"

  @moduledoc """
  Sends a test email through the configured Swoosh mailer.

      mix komiuta.send_test_email --to you@example.com

  Use this after configuring an email provider to confirm credentials and DNS
  are correct. In development the Swoosh Local adapter captures the email; open
  http://localhost:4000/dev/mailbox to read it. In production it is delivered
  through Resend / Mailgun / Brevo.
  """

  use Mix.Task

  @impl true
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _argv, invalid} = OptionParser.parse(args, strict: [to: :string])
    to = opts[:to]

    if is_nil(to) or String.trim(to) == "" do
      Mix.raise("Usage: mix komiuta.send_test_email --to you@example.com")
    end

    if invalid != [] do
      Mix.raise("Invalid option(s): #{inspect(invalid)}")
    end

    from_address = Application.get_env(:xpressbus, :mailer_from, "no-reply@komiuta.com")

    email =
      Swoosh.Email.new()
      |> Swoosh.Email.to(String.trim(to))
      |> Swoosh.Email.from({"Komiuta", from_address})
      |> Swoosh.Email.subject("Komiuta test email")
      |> Swoosh.Email.text_body("""
      Komiuta email delivery works.

      Sent at #{DateTime.utc_now()} using from address #{from_address}.
      """)

    case Xpressbus.Mailer.deliver(email) do
      {:ok, _email} ->
        Mix.shell().info("Test email accepted by the configured mailer.")

        if adapter() == Swoosh.Adapters.Local do
          Mix.shell().info("Local adapter: open /dev/mailbox to read the message.")
        end

      {:error, reason} ->
        Mix.raise("Email delivery failed: #{inspect(reason)}")
    end
  end

  defp adapter do
    config = Application.get_env(:xpressbus, Xpressbus.Mailer) || Keyword.new()
    Keyword.get(config, :adapter)
  end
end
