defmodule ListProcessor do
  @moduledoc """
  Processes lists of integer records for the reporting pipeline.
  """

  def slow_path(records) do
    records
    |> Enum.map(&(&1 * 2))
    |> Enum.filter(&(rem(&1, 3) == 0))
    |> Enum.sort()
    |> Enum.uniq()
  end

  def fast_path(records) do
    records
    |> Stream.map(&(&1 * 2))
    |> Stream.filter(&(rem(&1, 3) == 0))
    |> Enum.sort()
    |> Enum.uniq()
  end
end
