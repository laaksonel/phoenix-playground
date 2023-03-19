defmodule RumblWeb.UserHTML do
  require Logger
  alias Rumbl.Accounts
  use RumblWeb, :html

  embed_templates "user_html/*"

  @doc """
  Renders a user form.
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true

  def user_form(assigns)

  def first_name(name) do
    name
    |> String.split(" ")
    |> Enum.at(0)
  end

  attr :name, :string, required: true
  def test_name(assigns) do
    ~H"""
    <p><%= @name %></p>
    """
  end
end
