%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      plugins: [],
      requires: [],
      strict: true,
      parse_timeout: 5000,
      color: true,
      checks: %{
        enabled: [
          # LexCredo checks — added as each is implemented
          {LexCredo.Check.Design.NoNestedModules, []},
          {LexCredo.Check.Warning.NoBareWildcardInCase, []},
          {LexCredo.Check.Warning.UsePositiveTypeGuards, []},
        ],
        disabled: []
      }
    }
  ]
}
