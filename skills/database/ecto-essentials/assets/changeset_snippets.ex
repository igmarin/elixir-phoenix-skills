# Ecto Changeset Snippets

## Basic Changeset

```elixir
defmodule MyApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :body, :string
    field :status, Ecto.Enum, values: [:draft, :published, :archived]
    field :published_at, :utc_datetime
    belongs_to :author, MyApp.Accounts.User
    timestamps()
  end

  @doc """
  Creates a changeset for post creation/update.
  """
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body, :status, :author_id])
    |> validate_required([:title, :body])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:body, min: 10)
    |> unique_constraint(:title)
    |> foreign_key_constraint(:author_id)
  end
end
```

## Custom Changeset with Conditional Validation

```elixir
def publish_changeset(post) do
  post
  |> change(status: :published, published_at: DateTime.utc_now())
  |> validate_required([:title, :body])
  |> validate_change(:status, fn :status, :published ->
    if post_has_comments?(post), do: [], else: [status: "cannot publish post without comments"]
  end)
end
```

## Changeset with prepare_changes

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body, :slug])
  |> validate_required([:title, :body])
  |> prepare_changes(fn changeset ->
    slug = get_field(changeset, :title) |> slugify()
    put_change(changeset, :slug, slug)
  end)
end

defp slugify(title) when is_binary(title) do
  title
  |> String.downcase()
  |> String.replace(~r/[^a-z0-9\s-]/, "")
  |> String.replace(~r/[\s]+/, "-")
end
```

## Insert with Ecto.Multi

```elixir
alias Ecto.Multi

def create_post_with_tags(attrs, tag_names) do
  Multi.new()
  |> Multi.insert(:post, Post.changeset(%Post{}, attrs))
  |> Multi.run(:tags, fn repo, %{post: post} ->
    tags =
      Enum.map(tag_names, fn name ->
        %Tag{name: name} |> Tag.changeset(%{})
      end)

    repo.insert_all(Tag, tags, on_conflict: :nothing)
  end)
  |> Repo.transaction()
end
```

## Validate with Custom Function

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body, :author_id])
  |> validate_required([:title, :body])
  |> validate_author_exists()
end

defp validate_author_exists(changeset) do
  author_id = get_field(changeset, :author_id)

  if author_id && Repo.get(User, author_id) do
    changeset
  else
    add_error(changeset, :author_id, "does not exist")
  end
end
```

## Safe String Casting with put_change

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :body])
  |> put_change(:title, String.trim(get_field(post, :title) || ""))
  |> put_change(:body, String.trim(get_field(post, :body) || ""))
  |> validate_required([:title, :body])
end
```
