defmodule MyApp.Accounts do
  @moduledoc """
  The Accounts context manages user accounts.
  """

  alias MyApp.Repo
  alias MyApp.Accounts.User

  @doc """
  Fetches a user by ID. Returns nil if not found.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  @doc """
  Creates a new user.
  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing user.
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.
  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Lists all users.
  """
  def list_users do
    Repo.all(User)
  end
end
