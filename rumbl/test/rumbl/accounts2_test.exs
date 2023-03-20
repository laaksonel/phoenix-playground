defmodule Rumbl.Accounts2Test do
  use Rumbl.DataCase

  alias Rumbl.Accounts2

  import Rumbl.Accounts2Fixtures
  alias Rumbl.Accounts2.{User2, User2Token}

  describe "get_user2_by_email/1" do
    test "does not return the user2 if the email does not exist" do
      refute Accounts2.get_user2_by_email("unknown@example.com")
    end

    test "returns the user2 if the email exists" do
      %{id: id} = user2 = user2_fixture()
      assert %User2{id: ^id} = Accounts2.get_user2_by_email(user2.email)
    end
  end

  describe "get_user2_by_email_and_password/2" do
    test "does not return the user2 if the email does not exist" do
      refute Accounts2.get_user2_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user2 if the password is not valid" do
      user2 = user2_fixture()
      refute Accounts2.get_user2_by_email_and_password(user2.email, "invalid")
    end

    test "returns the user2 if the email and password are valid" do
      %{id: id} = user2 = user2_fixture()

      assert %User2{id: ^id} =
               Accounts2.get_user2_by_email_and_password(user2.email, valid_user2_password())
    end
  end

  describe "get_user2!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts2.get_user2!(-1)
      end
    end

    test "returns the user2 with the given id" do
      %{id: id} = user2 = user2_fixture()
      assert %User2{id: ^id} = Accounts2.get_user2!(user2.id)
    end
  end

  describe "register_user2/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts2.register_user2(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts2.register_user2(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts2.register_user2(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = user2_fixture()
      {:error, changeset} = Accounts2.register_user2(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts2.register_user2(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users2 with a hashed password" do
      email = unique_user2_email()
      {:ok, user2} = Accounts2.register_user2(valid_user2_attributes(email: email))
      assert user2.email == email
      assert is_binary(user2.hashed_password)
      assert is_nil(user2.confirmed_at)
      assert is_nil(user2.password)
    end
  end

  describe "change_user2_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts2.change_user2_registration(%User2{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_user2_email()
      password = valid_user2_password()

      changeset =
        Accounts2.change_user2_registration(
          %User2{},
          valid_user2_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_user2_email/2" do
    test "returns a user2 changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts2.change_user2_email(%User2{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_user2_email/3" do
    setup do
      %{user2: user2_fixture()}
    end

    test "requires email to change", %{user2: user2} do
      {:error, changeset} = Accounts2.apply_user2_email(user2, valid_user2_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{user2: user2} do
      {:error, changeset} =
        Accounts2.apply_user2_email(user2, valid_user2_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{user2: user2} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts2.apply_user2_email(user2, valid_user2_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user2: user2} do
      %{email: email} = user2_fixture()
      password = valid_user2_password()

      {:error, changeset} = Accounts2.apply_user2_email(user2, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{user2: user2} do
      {:error, changeset} =
        Accounts2.apply_user2_email(user2, "invalid", %{email: unique_user2_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{user2: user2} do
      email = unique_user2_email()
      {:ok, user2} = Accounts2.apply_user2_email(user2, valid_user2_password(), %{email: email})
      assert user2.email == email
      assert Accounts2.get_user2!(user2.id).email != email
    end
  end

  describe "deliver_user2_update_email_instructions/3" do
    setup do
      %{user2: user2_fixture()}
    end

    test "sends token through notification", %{user2: user2} do
      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_update_email_instructions(user2, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user2_token = Repo.get_by(User2Token, token: :crypto.hash(:sha256, token))
      assert user2_token.user2_id == user2.id
      assert user2_token.sent_to == user2.email
      assert user2_token.context == "change:current@example.com"
    end
  end

  describe "update_user2_email/2" do
    setup do
      user2 = user2_fixture()
      email = unique_user2_email()

      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_update_email_instructions(%{user2 | email: email}, user2.email, url)
        end)

      %{user2: user2, token: token, email: email}
    end

    test "updates the email with a valid token", %{user2: user2, token: token, email: email} do
      assert Accounts2.update_user2_email(user2, token) == :ok
      changed_user2 = Repo.get!(User2, user2.id)
      assert changed_user2.email != user2.email
      assert changed_user2.email == email
      assert changed_user2.confirmed_at
      assert changed_user2.confirmed_at != user2.confirmed_at
      refute Repo.get_by(User2Token, user2_id: user2.id)
    end

    test "does not update email with invalid token", %{user2: user2} do
      assert Accounts2.update_user2_email(user2, "oops") == :error
      assert Repo.get!(User2, user2.id).email == user2.email
      assert Repo.get_by(User2Token, user2_id: user2.id)
    end

    test "does not update email if user2 email changed", %{user2: user2, token: token} do
      assert Accounts2.update_user2_email(%{user2 | email: "current@example.com"}, token) == :error
      assert Repo.get!(User2, user2.id).email == user2.email
      assert Repo.get_by(User2Token, user2_id: user2.id)
    end

    test "does not update email if token expired", %{user2: user2, token: token} do
      {1, nil} = Repo.update_all(User2Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts2.update_user2_email(user2, token) == :error
      assert Repo.get!(User2, user2.id).email == user2.email
      assert Repo.get_by(User2Token, user2_id: user2.id)
    end
  end

  describe "change_user2_password/2" do
    test "returns a user2 changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts2.change_user2_password(%User2{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts2.change_user2_password(%User2{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user2_password/3" do
    setup do
      %{user2: user2_fixture()}
    end

    test "validates password", %{user2: user2} do
      {:error, changeset} =
        Accounts2.update_user2_password(user2, valid_user2_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user2: user2} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts2.update_user2_password(user2, valid_user2_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{user2: user2} do
      {:error, changeset} =
        Accounts2.update_user2_password(user2, "invalid", %{password: valid_user2_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{user2: user2} do
      {:ok, user2} =
        Accounts2.update_user2_password(user2, valid_user2_password(), %{
          password: "new valid password"
        })

      assert is_nil(user2.password)
      assert Accounts2.get_user2_by_email_and_password(user2.email, "new valid password")
    end

    test "deletes all tokens for the given user2", %{user2: user2} do
      _ = Accounts2.generate_user2_session_token(user2)

      {:ok, _} =
        Accounts2.update_user2_password(user2, valid_user2_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(User2Token, user2_id: user2.id)
    end
  end

  describe "generate_user2_session_token/1" do
    setup do
      %{user2: user2_fixture()}
    end

    test "generates a token", %{user2: user2} do
      token = Accounts2.generate_user2_session_token(user2)
      assert user2_token = Repo.get_by(User2Token, token: token)
      assert user2_token.context == "session"

      # Creating the same token for another user2 should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%User2Token{
          token: user2_token.token,
          user2_id: user2_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_user2_by_session_token/1" do
    setup do
      user2 = user2_fixture()
      token = Accounts2.generate_user2_session_token(user2)
      %{user2: user2, token: token}
    end

    test "returns user2 by token", %{user2: user2, token: token} do
      assert session_user2 = Accounts2.get_user2_by_session_token(token)
      assert session_user2.id == user2.id
    end

    test "does not return user2 for invalid token" do
      refute Accounts2.get_user2_by_session_token("oops")
    end

    test "does not return user2 for expired token", %{token: token} do
      {1, nil} = Repo.update_all(User2Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts2.get_user2_by_session_token(token)
    end
  end

  describe "delete_user2_session_token/1" do
    test "deletes the token" do
      user2 = user2_fixture()
      token = Accounts2.generate_user2_session_token(user2)
      assert Accounts2.delete_user2_session_token(token) == :ok
      refute Accounts2.get_user2_by_session_token(token)
    end
  end

  describe "deliver_user2_confirmation_instructions/2" do
    setup do
      %{user2: user2_fixture()}
    end

    test "sends token through notification", %{user2: user2} do
      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_confirmation_instructions(user2, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user2_token = Repo.get_by(User2Token, token: :crypto.hash(:sha256, token))
      assert user2_token.user2_id == user2.id
      assert user2_token.sent_to == user2.email
      assert user2_token.context == "confirm"
    end
  end

  describe "confirm_user2/1" do
    setup do
      user2 = user2_fixture()

      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_confirmation_instructions(user2, url)
        end)

      %{user2: user2, token: token}
    end

    test "confirms the email with a valid token", %{user2: user2, token: token} do
      assert {:ok, confirmed_user2} = Accounts2.confirm_user2(token)
      assert confirmed_user2.confirmed_at
      assert confirmed_user2.confirmed_at != user2.confirmed_at
      assert Repo.get!(User2, user2.id).confirmed_at
      refute Repo.get_by(User2Token, user2_id: user2.id)
    end

    test "does not confirm with invalid token", %{user2: user2} do
      assert Accounts2.confirm_user2("oops") == :error
      refute Repo.get!(User2, user2.id).confirmed_at
      assert Repo.get_by(User2Token, user2_id: user2.id)
    end

    test "does not confirm email if token expired", %{user2: user2, token: token} do
      {1, nil} = Repo.update_all(User2Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts2.confirm_user2(token) == :error
      refute Repo.get!(User2, user2.id).confirmed_at
      assert Repo.get_by(User2Token, user2_id: user2.id)
    end
  end

  describe "deliver_user2_reset_password_instructions/2" do
    setup do
      %{user2: user2_fixture()}
    end

    test "sends token through notification", %{user2: user2} do
      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_reset_password_instructions(user2, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert user2_token = Repo.get_by(User2Token, token: :crypto.hash(:sha256, token))
      assert user2_token.user2_id == user2.id
      assert user2_token.sent_to == user2.email
      assert user2_token.context == "reset_password"
    end
  end

  describe "get_user2_by_reset_password_token/1" do
    setup do
      user2 = user2_fixture()

      token =
        extract_user2_token(fn url ->
          Accounts2.deliver_user2_reset_password_instructions(user2, url)
        end)

      %{user2: user2, token: token}
    end

    test "returns the user2 with valid token", %{user2: %{id: id}, token: token} do
      assert %User2{id: ^id} = Accounts2.get_user2_by_reset_password_token(token)
      assert Repo.get_by(User2Token, user2_id: id)
    end

    test "does not return the user2 with invalid token", %{user2: user2} do
      refute Accounts2.get_user2_by_reset_password_token("oops")
      assert Repo.get_by(User2Token, user2_id: user2.id)
    end

    test "does not return the user2 if token expired", %{user2: user2, token: token} do
      {1, nil} = Repo.update_all(User2Token, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts2.get_user2_by_reset_password_token(token)
      assert Repo.get_by(User2Token, user2_id: user2.id)
    end
  end

  describe "reset_user2_password/2" do
    setup do
      %{user2: user2_fixture()}
    end

    test "validates password", %{user2: user2} do
      {:error, changeset} =
        Accounts2.reset_user2_password(user2, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user2: user2} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts2.reset_user2_password(user2, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user2: user2} do
      {:ok, updated_user2} = Accounts2.reset_user2_password(user2, %{password: "new valid password"})
      assert is_nil(updated_user2.password)
      assert Accounts2.get_user2_by_email_and_password(user2.email, "new valid password")
    end

    test "deletes all tokens for the given user2", %{user2: user2} do
      _ = Accounts2.generate_user2_session_token(user2)
      {:ok, _} = Accounts2.reset_user2_password(user2, %{password: "new valid password"})
      refute Repo.get_by(User2Token, user2_id: user2.id)
    end
  end

  describe "inspect/2 for the User2 module" do
    test "does not include password" do
      refute inspect(%User2{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
