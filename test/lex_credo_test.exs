defmodule LexCredoTest do
  use ExUnit.Case
  doctest LexCredo

  test "version/0 returns the current version string" do
    assert LexCredo.version() == Mix.Project.config()[:version]
  end
end
