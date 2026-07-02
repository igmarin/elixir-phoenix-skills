# Ecto Changeset Snippets
#
# Copy-paste reference snippets. Grouped by pattern; each block is standalone.
# Rename the duplicate `changeset/2` examples when combining them into one module.

# --- Basic Changeset ---

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

  # --- Custom Changeset with Conditional Validation ---

  def publish_changeset(post) do
    post
    |> change(status: :published, published_at: DateTime.utc_now())
    |> validate_required([:title, :body])
    |> validate_change(:status, fn :status, :published ->
      if post_has_comments?(post), do: [], else: [status: "cannot publish post without comments"]
    end)
  end

  # --- Changeset with prepare_changes ---

  def slug_changeset(post, attrs) do
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

  # --- Validate with Custom Function ---

  def author_changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body, :author_id])
    |> validate_required([:title, :body])
    |> validate_author_exists()
  end

  defp validate_author_exists(changeset) do
    author_id = get_field(changeset, :author_id)

    if author_id && MyApp.Repo.get(MyApp.Accounts.User, author_id) do
      changeset
    else
      add_error(changeset, :author_id, "does not exist")
    end
  end

  # --- Safe String Casting with put_change ---

  def trimmed_changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body])
    |> put_change(:title, String.trim(get_field(post, :title) || ""))
    |> put_change(:body, String.trim(get_field(post, :body) || ""))
    |> validate_required([:title, :body])
  end

  defp post_has_comments?(_post), do: true
end

# --- Insert with Ecto.Multi ---

defmodule MyApp.Blog.MultiSnippets do
  alias Ecto.Multi
  alias MyApp.Blog.{Post, Tag}
  alias MyApp.Repo

  def create_post_with_tags(attrs, tag_names) do
    Multi.new()
    |> Multi.insert(:post, Post.changeset(%Post{}, attrs))
    |> Multi.run(:tags, fn repo, %{post: _post} ->
      tags =
        Enum.map(tag_names, fn name ->
          %{name: name, inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}
        end)

      {count, _} = repo.insert_all(Tag, tags, on_conflict: :nothing)
      {:ok, count}
    end)
    |> Repo.transaction()
  end
end
