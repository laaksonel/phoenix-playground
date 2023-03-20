defmodule Rumbl.Accounts2Fixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Rumbl.Accounts2` context.
  """

  def unique_user2_email, do: "user2#{System.unique_integer()}@example.com"
  def valid_user2_password, do: "hello world!"

  def valid_user2_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user2_email(),
      password: valid_user2_password()
    })
  end

  def user2_fixture(attrs \\ %{}) do
    {:ok, user2} =
      attrs
      |> valid_user2_attributes()
      |> Rumbl.Accounts2.register_user2()

    user2
  end

  def extract_user2_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
