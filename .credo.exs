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
          {LexCredo.Check.Warning.NoPipeIntoCase, []},
          {LexCredo.Check.Readability.DocExamplesSection, []},
          {LexCredo.Check.Warning.NoTaggedWithClauses, []},
          {LexCredo.Check.Warning.NoProcessSleepInTests, []},
          {LexCredo.Check.Warning.NoEnumAllAssert, []},
          {LexCredo.Check.Warning.PreferBooleanOperators, []},
        ],
        disabled: []
      }
    }
  ]
}
