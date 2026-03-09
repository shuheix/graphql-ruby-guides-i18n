---
title: プロファイリング
description: GraphQL-Ruby のパフォーマンスのプロファイリング
sidebar:
  order: 4
---
もし、GraphQL-Ruby の内部も含めて GraphQL クエリの実行時間がどこで使われているかを詳しく知りたい場合は、Ruby のプロファイリングツールを使って詳しく調べることができます。

GraphQL-Ruby のパフォーマンスを一緒に調査してほしい場合は、以下に示すようにランタイムプロファイルとメモリプロファイルを準備し、それらのファイルを含めて GitHub で {% open_an_issue "Performance investigation" %} を作成してください。

## StackProf を使う

[StackProf](https://github.com/tmm1/stackprof) は、処理の時間がどこに使われているかを把握するための Ruby ライブラリです。プロファイルを取得するには、ブロックを `StackProf.run { ... }` で囲みます。

```ruby
require "stackprof"

# Prepare any GraphQL-related data or context:
query_string = "{ someGraphQL ... }"
context = { ... }

# This will dump a profile in `tmp/graphql-prof.dump`
StackProf.run(mode: :wall, interval: 10, out: "tmp/graphql-prof.dump") do
  # Execute the query inside the block:
  MySchema.execute(query_string, context: context)
end
```

`out:` オプションは指定した場所にプロファイルの "dump" を作成するよう StackProf に指示します。そうして作成されたファイルを持っている人は、`stackprof` コマンドでプロファイルを調べられます。例えば:

```
$ stackprof tmp/graphql-prof.dump
==================================
  Mode: wall(1)
  Samples: 2492 (58.06% miss rate)
  GC: 0 (0.00%)
==================================
     TOTAL    (pct)     SAMPLES    (pct)     FRAME
       902  (36.2%)          94   (3.8%)     GraphQL::Execution::Interpreter::Runtime#evaluate_selection_with_resolved_keyword_args
      1283  (51.5%)          87   (3.5%)     GraphQL::Execution::Interpreter::Runtime#continue_field
       274  (11.0%)          78   (3.1%)     GraphQL::Schema::Field#resolve
      1068  (42.9%)          73   (2.9%)     GraphQL::Execution::Interpreter::Runtime#evaluate_selection
      # ...
```

また、`stackprof` は特定のメソッドのパフォーマンスや使用状況の詳細を表示する `--method` 引数を受け付けます。例えば:

```
$ stackprof tmp/small.dump --method #gather_selections
GraphQL::Execution::Interpreter::Runtime#gather_selections (/Users/rmosolgo/code/graphql-ruby/lib/graphql/execution/interpreter/runtime.rb:305)
  samples:    17 self (0.7%)  /     17 total (0.7%)
  callers:
      16  (   94.1%)  GraphQL::Execution::Interpreter::Runtime#continue_field
       6  (   35.3%)  Array#each
       1  (    5.9%)  GraphQL::Execution::Interpreter::Runtime#run_eager
  callees (0 total):
       6  (    Inf%)  Array#each
  code:
    1    (0.0%) /     1   (0.0%)  |   305  |                 when :lookahead
    6    (0.2%) /     6   (0.2%)  |   306  |                   if !field_ast_nodes
    3    (0.1%) /     3   (0.1%)  |   307  |                     field_ast_nodes = [ast_node]
                                  |   308  |                   end
```

`.dump` ファイルを持っている人なら誰でもこの解析を行えます — とても有用なファイルです。GraphQL-Ruby のパフォーマンスを一緒に調査してほしい場合は、ランタイムプロファイルを共有してください。

## MemoryProfiler を使う

[MemoryProfiler](https://github.com/SamSaffron/memory_profiler) は、ある処理がシステムメモリや Ruby のヒープとどのように関係しているかを明らかにします。メモリ使用量の問題はコードの実行を遅くする原因になるため、これを修正すると処理が高速になることがあります。

レポートを作成するには、ブロックを `MemoryProfiler.report { ... }` でラップし、結果に対して `.pretty_print` を呼びます。例えば、GraphQL クエリのレポートを作成する場合は次のようになります:

```ruby
require 'memory_profiler'

# Prepare any GraphQL-related data or context:
query_string = "{ someGraphQL ... }"
context = { ... }

report = MemoryProfiler.report do
  # Execute the query inside the block:
  MySchema.execute(query_string, context: context)
end

# Write the result to a file
report.pretty_print(to_file: "tmp/graphql-memory.txt")
```

レポートには次のような興味深いセクションが含まれます:

- 割り当てられた総メモリとオブジェクト数
- 場所別・クラス別に割り当てられたオブジェクト
- 同じ値の文字列が何回割り当てられたかを含む文字列割り当て

これらはコード内の「ホットスポット」を示し、メモリ使用を減らすためのリファクタリングの指針になります。結果として Ruby の GC に費やされる時間が減り、処理が速くなります。

GraphQL-Ruby のパフォーマンスを一緒に調査してほしい場合は、メモリプロファイルを共有してください。