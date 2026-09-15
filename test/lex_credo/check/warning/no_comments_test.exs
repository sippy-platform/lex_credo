defmodule LexCredo.Check.Warning.NoCommentsTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NoComments

  defp run(
         source,
         filename \\ "priv/repo/migrations/20260915000000_create_users.exs",
         params \\ []
       ) do
    source
    |> Credo.SourceFile.parse(filename)
    |> NoComments.run(params)
  end

  test "flags hash comments in migration files" do
    source = """
    defmodule MyApp.Repo.Migrations.CreateUsers do
      use Ecto.Migration

      # Users need an email address.
      def change do
        create table(:users)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.line_no == 4
    assert issue.trigger == "# Users need an email address."
    assert issue.message =~ "Comments do not belong in migration files"
  end

  test "flags documentation attributes in migration files" do
    source = """
    defmodule MyApp.Repo.Migrations.CreateUsers do
      @moduledoc "Creates the users table."
      @doc "Creates the table."
      @typedoc "A user identifier."
      @shortdoc "Creates users"
      use Ecto.Migration
    end
    """

    issues = run(source)

    assert Enum.map(issues, & &1.line_no) == [2, 3, 4, 5]
    assert Enum.map(issues, & &1.trigger) == ["@moduledoc", "@doc", "@typedoc", "@shortdoc"]
  end

  test "does not flag hash characters inside strings or sigils" do
    source = """
    defmodule MyApp.Repo.Migrations.CreateUsers do
      use Ecto.Migration

      def change do
        execute("create index \#{index_name}")
        execute(~s(SELECT '#not-a-comment'))
      end
    end
    """

    assert run(source) == []
  end

  test "allows a Credo disable-for-this-file directive as the explicit opt-out" do
    source = """
    # credo:disable-for-this-file LexCredo.Check.Warning.NoComments
    defmodule MyApp.Repo.Migrations.CreateUsers do
      use Ecto.Migration

      # This migration has an exceptional operational constraint.
      def change do
        create table(:users)
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag comments outside the default migration paths" do
    source = """
    defmodule MyApp.Users do
      # A normal code comment.
      @moduledoc "User operations."
    end
    """

    assert run(source, "lib/my_app/users.ex") == []
  end

  test "supports an exact file path" do
    source = """
    # This file is intentionally targeted.
    defmodule MyApp.Generated.Schema do
    end
    """

    assert [_issue] =
             run(source, "lib/my_app/generated/schema.ex",
               paths: ["lib/my_app/generated/schema.ex"]
             )
  end

  test "supports a directory path" do
    source = """
    # This directory is intentionally targeted.
    defmodule MyApp.Generated.Schema do
    end
    """

    assert [_issue] =
             run(source, "lib/my_app/generated/schema.ex", paths: ["lib/my_app/generated"])
  end

  test "supports regular expression paths" do
    source = """
    # This file is intentionally targeted.
    defmodule MyApp.Generated.Schema do
    end
    """

    assert [_issue] =
             run(source, "lib/my_app/generated/schema.ex", paths: [~r{/generated/.*\.ex$}])
  end

  test "recognizes migration files in umbrella applications" do
    source = """
    # Migration comment
    defmodule MyApp.Repo.Migrations.CreateUsers do
      use Ecto.Migration
    end
    """

    assert [_issue] =
             run(source, "apps/my_app/priv/repo/migrations/20260915000000_create_users.exs")
  end
end
