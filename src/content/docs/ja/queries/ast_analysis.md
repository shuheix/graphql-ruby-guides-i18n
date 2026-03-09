---
title: 事前AST解析
description: 受信した query 文字列を検査し、チェックに合格しないものは拒否します
sidebar:
  order: 1
redirect_from:
- "/queries/analysis/"
---
事前に query に対する解析を行うことができます。

解析のプリミティブは [`GraphQL::Analysis::Analyzer`](https://graphql-ruby.org/api-doc/GraphQL::Analysis::Analyzer) です。Analyzer はこの基底クラスを継承し、解析に必要なメソッドを実装する必要があります。

## アナライザーの使い方

Query アナライザーは `query_analyzer` を使って schema に追加します。例:

```ruby
class MySchema < GraphQL::Schema
  query_analyzer MyQueryAnalyzer
end
```

アナライザーの「クラス」を渡してください（インスタンスではなく）。解析エンジンがクエリに対してアナライザーをインスタンス化します。

## アナライザー API

アナライザーは AST ビジターに似た名前のメソッドに応答します。メソッド名は `on_enter_#{ast_node}` や `on_leave_#{ast_node}` のようになります。メソッドは次の三つの引数で呼ばれます:

- `node`: 現在の AST ノード（入るときまたは出るとき）
- `parent`: ツリー内でこのノードに先行する AST ノード
- `visitor`: この解析実行を管理している [`GraphQL::Analysis::Visitor`](https://graphql-ruby.org/api-doc/GraphQL::Analysis::Visitor)

例えば:

```ruby
class BasicCounterAnalyzer < GraphQL::Analysis::Analyzer
  def initialize(query_or_multiplex)
    super
    @fields = Set.new
    @arguments = Set.new
  end

  # Visitors are all defined on the Analyzer base class
  # We override them for custom analyzers.
  def on_leave_field(node, _parent, _visitor)
    @fields.add(node.name)
  end

  def result
    # Do something with the gathered result.
    Analytics.log(@fields)
  end
end
```

この例では、フラグメント定義内であってもディレクティブによってスキップされていても、すべての field をカウントしています。そうしたコンテキストを検出したい場合は、ヘルパーメソッドを使うことができます:

```ruby
class BasicFieldAnalyzer < GraphQL::Analysis::Analyzer
  def initialize(query_or_multiplex)
    super
    @fields = Set.new
  end

  # Visitors are all defined on the Analyzer base class
  # We override them for custom analyzers.
  def on_leave_field(node, _parent, visitor)
    if visitor.skipping? || visitor.visiting_fragment_definition?
      # We don't want to count skipped fields or fields
      # inside fragment definitions
    else
      @fields.add(node.name)
    end
  end

  def result
    Analytics.log(@fields)
  end
end
```

`visitor` オブジェクトの詳細については [`GraphQL::Analysis::Visitor`](https://graphql-ruby.org/api-doc/GraphQL::Analysis::Visitor) を参照してください。

### Field の引数

通常、アナライザーは `on_enter_field` と `on_leave_field` を使ってクエリを処理します。解析中に field の引数を取得するには、`visitor.query.arguments_for(node, visitor.field_definition)` を使用してください（[`GraphQL::Query#arguments_for`](https://graphql-ruby.org/api-doc/GraphQL::Query#arguments_for)）。このメソッドはコーアされた引数の値を返し、引数リテラルと変数の値を正規化します。

### エラー

アナライザーからエラーを返すことも可能です。クエリを拒否して実行を停止するには、`result` メソッド内で [`GraphQL::AnalysisError`](https://graphql-ruby.org/api-doc/GraphQL::AnalysisError) を返してください:

```ruby
class NoFieldsCalledHello < GraphQL::Analysis::Analyzer
  def on_leave_field(node, _parent, visitor)
    if node.name == "hello"
      @field_called_hello = true
    end
  end

  def result
    GraphQL::AnalysisError.new("A field called `hello` was found.") if @field_called_hello
  end
end
```

### 条件付き解析

あるアナライザーは特定のコンテキストでのみ意味をなす場合や、毎回のクエリで実行するにはコストが高すぎる場合があります。そうしたシナリオに対応するために、アナライザーは `analyze?` メソッドで有効/無効を返すことができます:

```ruby
class BasicFieldAnalyzer < GraphQL::Analysis::Analyzer
  # Use the analyze? method to enable or disable a certain analyzer
  # at query time.
  def analyze?
    !!subject.context[:should_analyze]
  end

  def on_leave_field(node, _parent, visitor)
    # ...
  end

  def result
    # ...
  end
end
```

## Multiplex の解析

アナライザーは解析の単位（subject）で初期化され、これを `subject` として利用できます。

アナライザーが multiplex にフックされている場合、`query` は `nil` ですが `multiplex` が解析対象の subject を返します。visit メソッド内では `visitor.query` を使って現在の AST ノードを所有する query を参照できます。

組み込みの一部アナライザー（例: `AST::MaxQueryDepth`）は名前に `Query` が入っていても multiplex をサポートしている点に注意してください。