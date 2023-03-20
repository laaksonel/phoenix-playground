defmodule Rumbl.Accounts2 do
  @moduledoc """
  The Accounts2 context.
  """

  import Ecto.Query, warn: false
  alias Rumbl.Repo

  alias Rumbl.Accounts2.{User2, User2Token, User2Notifier}

  ## Database getters

  @doc """
  Gets a user2 by email.

  ## Examples

      iex> get_user2_by_email("foo@example.com")
      %User2{}

      iex> get_user2_by_email("unknown@example.com")
      nil

  """
  def get_user2_by_email(email) when is_binary(email) do
    Repo.get_by(User2, email: email)
  end

  @doc """
  Gets a user2 by email and password.

  ## Examples

      iex> get_user2_by_email_and_password("foo@example.com", "correct_password")
      %User2{}

      iex> get_user2_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user2_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user2 = Repo.get_by(User2, email: email)
    if User2.valid_password?(user2, password), do: user2
  end

  @doc """
  Gets a single user2.

  Raises `Ecto.NoResultsError` if the User2 does not exist.

  ## Examples

      iex> get_user2!(123)
      %User2{}

      iex> get_user2!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user2!(id), do: Repo.get!(User2, id)

  ## User2 registration

  @doc """
  Registers a user2.

  ## Examples

      iex> register_user2(%{field: value})
      {:ok, %User2{}}

      iex> register_user2(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user2(attrs) do
    %User2{}
    |> User2.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user2 changes.

  ## Examples

      iex> change_user2_registration(user2)
      %Ecto.Changeset{data: %User2{}}

  """
  def change_user2_registration(%User2{} = user2, attrs \\ %{}) do
    User2.registration_changeset(user2, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user2 email.

  ## Examples

      iex> change_user2_email(user2)
      %Ecto.Changeset{data: %User2{}}

  """
  def change_user2_email(user2, attrs \\ %{}) do
    User2.email_changeset(user2, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user2_email(user2, "valid password", %{email: ...})
      {:ok, %User2{}}

      iex> apply_user2_email(user2, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user2_email(user2, password, attrs) do
    user2
    |> User2.email_changeset(attrs)
    |> User2.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user2 email using the given token.

  If the token matches, the user2 email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user2_email(user2, token) do
    context = "change:#{user2.email}"

    with {:ok, query} <- User2Token.verify_change_email_token_query(token, context),
         %User2Token{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user2_email_multi(user2, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user2_email_multi(user2, email, context) do
    changeset =
      user2
      |> User2.email_changeset(%{email: email})
      |> User2.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user2, changeset)
    |> Ecto.Multi.delete_all(:tokens, User2Token.user2_and_contexts_query(user2, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user2.

  ## Examples

      iex> deliver_user2_update_email_instructions(user2, current_email, &url(~p"/users2/settings/confirm_email/#{&1})")
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user2_update_email_instructions(%User2{} = user2, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user2_token} = User2Token.build_email_token(user2, "change:#{current_email}")

    Repo.insert!(user2_token)
    User2Notifier.deliver_update_email_instructions(user2, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user2 password.

  ## Examples

      iex> change_user2_password(user2)
      %Ecto.Changeset{data: %User2{}}

  """
  def change_user2_password(user2, attrs \\ %{}) do
    User2.password_changeset(user2, attrs, hash_password: false)
  end

  @doc """
  Updates the user2 password.

  ## Examples

      iex> update_user2_password(user2, "valid password", %{password: ...})
      {:ok, %User2{}}

      iex> update_user2_password(user2, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user2_password(user2, password, attrs) do
    changeset =
      user2
      |> User2.password_changeset(attrs)
      |> User2.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user2, changeset)
    |> Ecto.Multi.delete_all(:tokens, User2Token.user2_and_contexts_query(user2, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user2: user2}} -> {:ok, user2}
      {:error, :user2, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user2_session_token(user2) do
    {token, user2_token} = User2Token.build_session_token(user2)
    Repo.insert!(user2_token)
    token
  end

  @doc """
  Gets the user2 with the given signed token.
  """
  def get_user2_by_session_token(token) do
    {:ok, query} = User2Token.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user2_session_token(token) do
    Repo.delete_all(User2Token.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user2.

  ## Examples

      iex> deliver_user2_confirmation_instructions(user2, &url(~p"/users2/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user2_confirmation_instructions(confirmed_user2, &url(~p"/users2/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user2_confirmation_instructions(%User2{} = user2, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user2.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user2_token} = User2Token.build_email_token(user2, "confirm")
      Repo.insert!(user2_token)
      User2Notifier.deliver_confirmation_instructions(user2, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user2 by the given token.

  If the token matches, the user2 account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user2(token) do
    with {:ok, query} <- User2Token.verify_email_token_query(token, "confirm"),
         %User2{} = user2 <- Repo.one(query),
         {:ok, %{user2: user2}} <- Repo.transaction(confirm_user2_multi(user2)) do
      {:ok, user2}
    else
      _ -> :error
    end
  end

  defp confirm_user2_multi(user2) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user2, User2.confirm_changeset(user2))
    |> Ecto.Multi.delete_all(:tokens, User2Token.user2_and_contexts_query(user2, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user2.

  ## Examples

      iex> deliver_user2_reset_password_instructions(user2, &url(~p"/users2/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user2_reset_password_instructions(%User2{} = user2, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user2_token} = User2Token.build_email_token(user2, "reset_password")
    Repo.insert!(user2_token)
    User2Notifier.deliver_reset_password_instructions(user2, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user2 by reset password token.

  ## Examples

      iex> get_user2_by_reset_password_token("validtoken")
      %User2{}

      iex> get_user2_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user2_by_reset_password_token(token) do
    with {:ok, query} <- User2Token.verify_email_token_query(token, "reset_password"),
         %User2{} = user2 <- Repo.one(query) do
      user2
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user2 password.

  ## Examples

      iex> reset_user2_password(user2, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User2{}}

      iex> reset_user2_password(user2, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user2_password(user2, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user2, User2.password_changeset(user2, attrs))
    |> Ecto.Multi.delete_all(:tokens, User2Token.user2_and_contexts_query(user2, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user2: user2}} -> {:ok, user2}
      {:error, :user2, changeset, _} -> {:error, changeset}
    end
  end
end
