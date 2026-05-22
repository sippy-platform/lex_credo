defmodule LexCredo.Check.Warning.NoEnumAllAssertTest do
  use ExUnit.Case, async: true

  alias LexCredo.Check.Warning.NoEnumAllAssert

  defp run(source, filename \\ "test/my_test.exs") do
    source
    |> Credo.SourceFile.parse(filename)
    |> NoEnumAllAssert.run([])
  end

  test "flags assert Enum.all? in a test file" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "checks all posts" do
        posts = get_posts()
        assert Enum.all?(posts, &match?(%Post{}, &1))
      end
    end
    """

    assert [issue] = run(source)
    assert issue.message =~ "for` with individual assertions"
    assert issue.trigger == "Enum.all?"
  end

  test "flags assert Enum.all? with an anonymous function" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "all valid" do
        assert Enum.all?([1, 2, 3], fn x -> x > 0 end)
      end
    end
    """

    assert [issue] = run(source)
    assert issue.trigger == "Enum.all?"
  end

  test "does not flag a bare Enum.all? not wrapped in assert" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "all valid" do
        result = Enum.all?([1, 2, 3], fn x -> x > 0 end)
        assert result
      end
    end
    """

    assert run(source) == []
  end

  test "does not flag assert Enum.all? in a non-test file" do
    source = """
    defmodule MyModule do
      def validate(list) do
        assert Enum.all?(list, &is_integer/1)
      end
    end
    """

    assert run(source, "lib/my_module.ex") == []
  end

  test "does not flag other assert calls" do
    source = """
    defmodule MyTest do
      use ExUnit.Case

      test "simple assertion" do
        assert 1 + 1 == 2
        assert is_binary("hello")
      end
    end
    """

    assert run(source) == []
  end
end
