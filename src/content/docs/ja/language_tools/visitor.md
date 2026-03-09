---
title: AST ビジター
description: 解析された GraphQL コードを分析および変更する
sidebar:
  order: 0
---
GraphQL のコードは通常文字列に含まれます。例えば:

```ruby
query_string = "query { user(id: \"1\") { userName } }"
```

GraphQL のコードに対してプログラム的な解析と変更を行うには、次の3ステップのプロセスを使います:

- __パース__：コードを抽象構文木に変換する
- __解析／変更__：visitor を使ってコードを調査・変更する
- __出力__：AST を文字列に戻す

## パース

[`GraphQL.parse`](https://graphql-ruby.org/api-doc/GraphQL.parse) は文字列を GraphQL ドキュメントに変換します:

```ruby
parsed_doc = GraphQL.parse("{ user(id: \"1\") { userName } }")
# => #<GraphQL::Language::Nodes::Document ...>
```

また、[`GraphQL.parse_file`](https://graphql-ruby.org/api-doc/GraphQL.parse_file) は指定したファイルの内容をパースし、パースしたドキュメントに `filename` を含めます。

#### AST Nodes

パースされたドキュメントはノードのツリーであり、これは _抽象構文木_（AST）と呼ばれます。このツリーは _不変_ です：一度ドキュメントがパースされると、それらの Ruby オブジェクトは変更できません。変更は既存の node を _コピー_ してコピーに対して変更を適用し、新しいツリーを作ってコピーした node を格納することで行います。可能であれば、未変更の node は新しいツリーにそのまま保持されます（これは _persistent_ なデータ構造です）。

コピーして変更するワークフローは、AST node 上のいくつかのメソッドでサポートされています:

- `.merge(new_attrs)` は new_attrs を適用した node のコピーを返します。この新しいコピーが元の node を置き換えることができます。
- `.add_{child}(new_child_attrs)` は new_child_attrs で新しい node を作成し、`{child}` で指定された配列に追加し、作成された node を含む `{children}` 配列を持つコピーを返します。

例えば、field の名前を変更してそこに argument を追加するには、次のようにします:

```ruby
modified_node = field_node
  # Apply a new name
  .merge(name: "newName")
  # Add an argument to this field's arguments
  .add_argument(name: "newArgument", value: "newValue")
```

上の例では、`field_node` は変更されず、`modified_node` が新しい名前と新しい argument を反映しています。

## 解析／変更

パースされたドキュメントを検査または変更するには、[`GraphQL::Language::Visitor`](https://graphql-ruby.org/api-doc/GraphQL::Language::Visitor) を拡張し、さまざまな hook を実装します。これは [ビジターパターン](https://en.wikipedia.org/wiki/Visitor_pattern) の実装です。簡単に言うと、ツリーの各 node はメソッドによって「訪問」され、これらのメソッドで情報を収集したり変更を行ったりできます。

visitor 内では、各 node クラスに対応するフックがあります。例えば:

- [`GraphQL::Language::Nodes::Field`](https://graphql-ruby.org/api-doc/GraphQL::Language::Nodes::Field)s は `#on_field` にルーティングされます
- [`GraphQL::Language::Nodes::Argument`](https://graphql-ruby.org/api-doc/GraphQL::Language::Nodes::Argument)s は `#on_argument` にルーティングされます

完全なメソッド一覧は [`GraphQL::Language::Visitor`](https://graphql-ruby.org/api-doc/GraphQL::Language::Visitor) の API ドキュメントを参照してください。

各メソッドは `(node, parent)` で呼び出されます。ここで:

- `node` は現在訪問中の AST node です
- `parent` はこの node のツリー上の親の AST node です

メソッドは AST を調査または変更するためにいくつかの選択肢を持ちます:

#### 継続／停止

訪問を続けるには、フック内で `super` を呼び出します。これにより、訪問は node の子へと継続されます。例えば:

```ruby
def on_field(_node, _parent)
  # Do nothing, this is the default behavior:
  super
end
```

訪問を _停止_ するには、メソッド内で `super` を呼ばないようにします。たとえば、visitor がエラーに遭遇した場合、処理を早期に戻して訪問を続けないようにすることがあります。

#### ノードの変更

Visitor のフックは、呼び出された `(node, parent)` を返すことが期待されます。もし異なる node を返した場合、その node が元の `node` を置き換えます。`super(node, parent)` を呼ぶと `node` が返されます。したがって、ノードを変更して訪問を続けるには:

- `node` の変更されたコピーを作成する
- 変更されたコピーを `super(new_node, parent)` に渡す

例えば、argument の名前を変更するには:

```ruby
def on_argument(node, parent)
  # make a copy of `node` with a new name
  modified_node = node.merge(name: "renamed")
  # continue visiting with the modified node and parent
  super(modified_node, parent)
end
```

#### ノードの削除

現在訪問中の `node` を削除するには、`node` を `super(...)` に渡さないでください。代わりに特殊定数 `DELETE_NODE` を node の代わりに渡します。

例えば、directive を削除するには:

```ruby
def on_directive(node, parent)
  # Don't pass `node` to `super`,
  # instead, pass `DELETE_NODE`
  super(DELETE_NODE, parent)
end
```

#### ノードの挿入

ノードの挿入はノードの変更に似ています。`node` に新しい child を挿入するには、その `.add_` ヘルパーのいずれかを呼び出します。これは新しい child が追加されたコピーされた node を返します。例えば、field の selection set に selection を追加するには:

```ruby
def on_field(node, parent)
  node_with_selection = node.add_selection(name: "emailAddress")
  super(node_with_selection, parent)
end
```

これにより、`node` の fields selection に `emailAddress` が追加されます。


(これらの `.add_*` ヘルパーは [`GraphQL::Language::Nodes::AbstractNode#merge`](https://graphql-ruby.org/api-doc/GraphQL::Language::Nodes::AbstractNode#merge) のラッパーです。)

## 出力

AST を再び GraphQL の文字列に変換する最も簡単な方法は [`GraphQL::Language::Nodes::AbstractNode#to_query_string`](https://graphql-ruby.org/api-doc/GraphQL::Language::Nodes::AbstractNode#to_query_string) です。例えば:

```ruby
parsed_doc.to_query_string
# => '{ user(id: "1") { userName } }'
```

ノードの出力方法をカスタマイズしたい場合は、[`GraphQL::Language::Printer`](https://graphql-ruby.org/api-doc/GraphQL::Language::Printer) をサブクラス化して実装することもできます。