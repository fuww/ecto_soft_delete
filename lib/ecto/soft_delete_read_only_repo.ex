defmodule Ecto.SoftDelete.ReadOnlyRepo do
  @moduledoc """
  Adds the read only soft delete functionality to a repository.
      defmodule Repo do
        use Ecto.Repo,
          otp_app: :my_app,
          adapter: Ecto.Adapters.Postgres,
          read_only: true
        use Ecto.SoftDelete.ReadOnlyRepo
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Ecto.Query

      @doc """
      Overrides all query operations to exclude soft deleted records
      if the schema in the from clause has a deleted_at column
      NOTE: will not exclude soft deleted records if :with_deleted option passed as true
      """
      def prepare_query(_operation, query, opts) do
        schema_module = get_schema_module_from_query(query)
        fields = if schema_module, do: schema_module.__schema__(:fields), else: []
        soft_deletable? = Enum.member?(fields, :deleted_at)

        if has_include_deleted_at_clause?(query) || opts[:with_deleted] || !soft_deletable? do
          {query, opts}
        else
          query = from(x in query, where: is_nil(x.deleted_at))
          {query, opts}
        end
      end

      # Checks the query to see if it contains a where not is_nil(deleted_at)
      # if it does, we want to be sure that we don't exclude soft deleted records
      defp has_include_deleted_at_clause?(%Ecto.Query{wheres: wheres}) do
        Enum.any?(wheres, fn %{expr: expr} ->
          expr
          |> Inspect.Algebra.to_doc(%Inspect.Opts{
            inspect_fun: fn expr, _ ->
              inspect(expr, limit: :infinity)
            end
          })
          |> String.contains?(
            "{:not, [], [{:is_nil, [], [{{:., [], [{:&, [], [0]}, :deleted_at]}, [], []}]}]}"
          )
        end)
      end

      defp get_schema_module_from_query(%Ecto.Query{from: %{source: {_name, module}}}) do
        module
      end

      defp get_schema_module_from_query(_), do: nil
    end
  end
end
