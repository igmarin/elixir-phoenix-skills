defmodule MyApp.Blog.Article do
  use Ecto.Schema
  import Ecto.Changeset

  schema "articles" do
    field :title, :string
    field :body, :string
    belongs_to :author, MyApp.Accounts.User, foreign_key: :author_id

    timestamps()
  end

  @doc false
  def changeset(article, attrs) do
    article
    |> cast(attrs, [:title, :body, :author_id])
    |> validate_required([:title, :body, :author_id])
    |> validate_length(:title, min: 1, max: 255)
    |> foreign_key_constraint(:author_id)
  end
end
