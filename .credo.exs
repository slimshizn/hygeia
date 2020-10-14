%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: [
          "{mix,.formatter,.credo}.exs",
          "config/*.exs",
          "apps/*/{mix,.formatter,.credo}.exs",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/",
          "apps/*/priv/repo/"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: [
        {Credo.Check.Design.TagTODO, exit_status: 0},
        {Credo.Check.Design.TagFIXME, exit_status: 0},
        {Credo.Check.Readability.StrictModuleLayout, []},
        {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
        {Credo.Check.Consistency.UnusedVariableNames, []},
        {Credo.Check.Design.DuplicatedCode, []},
        {Credo.Check.Readability.AliasAs, false},
        {Credo.Check.Readability.MultiAlias, []},
        {Credo.Check.Readability.Specs, []},
        {Credo.Check.Readability.SinglePipe, []},
        {Credo.Check.Readability.WithCustomTaggedTuple, []},
        {Credo.Check.Refactor.ABCSize, []},
        {Credo.Check.Refactor.AppendSingleItem, []},
        {Credo.Check.Refactor.DoubleBooleanNegation, []},
        {Credo.Check.Refactor.ModuleDependencies, false},
        {Credo.Check.Refactor.NegatedIsNil, []},
        {Credo.Check.Refactor.PipeChainStart, []},
        {Credo.Check.Refactor.VariableRebinding, false},
        {Credo.Check.Warning.LeakyEnvironment, []},
        {Credo.Check.Warning.MapGetUnsafePass, []},
        {Credo.Check.Warning.UnsafeToAtom, []}
      ]
    }
  ]
}
