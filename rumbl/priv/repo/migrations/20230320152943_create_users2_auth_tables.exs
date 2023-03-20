defmodule Rumbl.Repo.Migrations.CreateUsers2AuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users2) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:users2, [:email])

    create table(:users2_tokens) do
      add :user2_id, references(:users2, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users2_tokens, [:user2_id])
    create unique_index(:users2_tokens, [:context, :token])
  end
end
