---
title: 新しい実行モジュール
description: GraphQL-Rubyの新しい実行アプローチの背景
sidebar:
  order: 1
published: false
---
GraphQL-Ruby には新しい実行モジュール [`GraphQL::Execution::Batching`](https://graphql-ruby.org/api-doc/GraphQL::Execution::Batching) が開発中です。まだ本番環境での利用は推奨されませんが、以下の手順に従って開発環境で試すことができます。

既存の実行モジュールに比べてはるかに高速でメモリ消費も少ないですが、既存モジュールがサポートするすべての機能を網羅しているわけではありません。

この機能は活発に開発中です。もし試してみて問題に遭遇した場合は、ぜひ GitHub に issue をあげてください。

## 背景

幅優先の GraphQL 実行（または「実行バッチ処理」）は、Shopify が大きなリストやネストされた集合を解決する際のスケーリング問題に対処するために開発したアルゴリズム的パラダイムです。各オブジェクトのすべての field ごとにフィールドレベルのオーバーヘッド（resolver 呼び出し、計測、lazy promise など）を支払うのではなく、このパターンではフィールド選択ごとに一度だけそのコストをかけ、対応するオブジェクト群を追加オーバーヘッドなしでまとめて処理します。

Shopify のコアアルゴリズムの最初の概念実証とホワイトペーパーのメモは [graphql-breadth-exec](https://github.com/gmac/graphql-breadth-exec) にあります。そのプロトタイプは成熟して Shopify の独自実行エンジン _GraphQL Cardinal_ になり、現在ではコアトラフィックの多くを処理しています。

GraphQL-Ruby は、幅優先の設計原則をオープンソースコミュニティに持ち込み、GraphQL を実装するためのいくつかの新しい技術を提供します:

- Fields は暗黙的にバッチ化された resolver を使って幅優先に解決されます（DataLoader を必要としません）。これにより実行オーバーヘッドなしでアプリケーションロジックがより長く、より熱く（効率的に）動作します。
- バッチ化された resolver は、promise の膨張を劇的に減らすために、全ロードセットを単一の lazy promise に束ねることがあります。
- エラー処理は、実際にエラーが発生した場合にのみ実行される第二のパスに最適化されます。
- スタックプロファイリングは、サブツリーの繰り返しで field が分断される代わりに、線形のフローと集計された field スパンにより、より整理されたものになります。
- エンジンは再帰ではなくエンキューイング（enqueue）により駆動されるため、スタックトレースが小さくなりメモリ使用量が減少します。

幅優先パターンは繰り返しの多いレスポンスで劇的な効果を出すことがあります: 幅優先バッチ処理が従来の GraphQL Ruby 実行よりも 15x 速く、メモリを 75% 少なく使うことは珍しくありません。ただし、効果は相対的です。リストがない平坦なツリーでは差がほとんど出ません。各要素が1つの field を解決する長さ 2 のリストなら小さな改善、各要素が10個の field を解決する長さ 100 のリストなら劇的な改善が期待できます。

欠点は、GraphQL Specification に記載された振る舞いを超える多くの GraphQL-Ruby の「便利機能」が、このパラダイムでは実装が不可能であったり、戻すと非自明なレイテンシを追加してしまったりする点です。したがって、今後の課題は、互換性をできるだけ維持しつつパフォーマンスの「天井」を高め、この新しいランタイムエンジンへの段階的な移行をサポートすることです。

## バッチ実行の有効化

バッチ実行は次の2ステップで有効になります:

- コードを require する（デフォルトでは読み込まれていません）: `require "graphql/execution/batching"`
- `MySchema.execute(...)` の代わりに `MySchema.execute_batching(...)` を呼び出します。引数は同じです。

クエリを正しく動かすための互換性に関する注意点は下記をご覧ください。

## 「ネイティブバッチ」構成

新しいランタイムエンジンは、互換性のための shim なしでいくつかの resolver 構成を標準でサポートします:

- ネイティブなメソッド呼び出し: `object.#{field_name}` を呼ぶ fields。これがデフォルトで、メソッド名は `method: ...` で上書きできます:

    ```ruby
    field :title, String # calls object.title
    field :title, String, method: :get_title_somehow # calls object.get_title_somehow
    ```
- ハッシュキー: `object[hash_key]` を呼ぶ fields。`hash_key: ...` で設定します。

    ```ruby
    field :title, String, hash_key: :title # calls object[:title]
    field :title, String, hash_key: "title" # calls object["title"]
    ```

    （注意: バッチ実行はハッシュキーのルックアップに「フォールバック」したり、Symbol 指定時に文字列を試したりしません。既存のランタイムはそれを行います...）

- バッチ resolver: 親オブジェクトの集合を field 結果へマップするために _クラスメソッド_ を使う fields。`resolve_batch:` で設定します:

    ```ruby
    field :title, String, resolve_batch: :titles do
      argument :language, Types::Language, required: false, default_value: "EN"
    end

    def self.titles(objects, context, language:)
      # This is equivalent to plain `field :title, ...`, but for example:
      objects.map { |obj| obj.title(language:) }
    end
    ```

    これは Dataloader のバッチ処理と組み合わせると特に有用です:

    ```ruby
    class Types::Comment < BaseObject
      field :post, Types::Post, resolve_batch: :posts

      # Use `.load_all(ids)` to fetch all in a single round-trip
      def self.posts(objects, context)
        # TODO: add a shorthand for this in GraphQL-Ruby
        context.dataloader
          .with(GraphQL::Dataloader::ActiveRecordSource)
          .load_all(objects.map(&:post_id))
      end
    end
    ```

- Each resolver: 親オブジェクトごとに結果を生成するための _クラスメソッド_ を使う fields。`resolve_each:` で設定します。`resolve_batch:` に似ていますが、`objects` 全体は受け取りません:

    ```ruby
    field :title, String, resolve_each: :title do
      argument :language, Types::Language, required: false, default_value: "EN"
    end

    def self.title(object, context, language:)
      object.title(language:)
    end
    ```

    （内部的には GraphQL-Ruby は `objects.map { ... }` を呼び、このクラスメソッドを呼び出します。）

- Static resolver: すべてのオブジェクトで共有される単一の結果を生成する _クラスメソッド_ を使う fields。`resolve_static:` で設定します。メソッドは `object` を受け取らず、`context` のみを受け取ります:

    ```ruby
    field :posts_count, Integer, resolve_static: :count_all_posts do
      argument :include_unpublished, Boolean, required: false, default_value: false
    end

    def self.count_all_posts(context, include_unpublished:)
      posts = Post.all
      if !include_unpublished
        posts = posts.published
      end
      posts.count
    end
    ```

    （内部的には GraphQL-Ruby は `Array.new(objects.size, static_result)` を呼びます）


### `true` ショートハンド

`resolve_...:` 構成のいずれかが `true`（例: `resolve_batch: true`、`resolve_each: true`、`resolve_static: true`）として渡された場合、そのフィールド名の Symbol がクラスメソッド名として使われます。例えば:

```ruby
field :posts_count, Integer, resolve_static: true

def self.posts_count(context)
  Post.all.count
end
```

## 移行経路

バッチ実行への移行は簡単ではありませんが、パフォーマンス向上のために価値があります。

1 つのスキーマでレガシー実行とバッチ実行の両方を動かすことができます。これにより段階的な導入が可能です:

1. スキーマを更新して、両方の実行モードをサポートするようにします。
    - すべての GraphQL に対してバッチ実行を使う CI ランを追加し、通常の CI と並行して実行します。
    - 上で述べた「ネイティブバッチ」構成を追加して CI が通るようにします。
    - 実装メソッド同士はお互いに呼び出すことができます。例えば:

    ```ruby
    field :unpublished_posts, [Types::Post], resolve_each: true

    # Support batching:
    def self.unpublished_posts(object, context)
      object.posts.where(published: false).order("created_at DESC")
    end

    # Support legacy in a DRY way by calling the class method:
    def unpublished_posts
      self.class.unpublished_posts(object, context)
    end
    ```

2. ベンチマーク

   このタイミングでお気に入りのベンチマークツールを使って効果を確認するのがよいです。GraphQL-Ruby の [`Tracing::DetailedTrace`](https://graphql-ruby.org/api-doc/Tracing::DetailedTrace) を使えば、GraphQL-Ruby のオーバーヘッドがスパン間の空白として把握できます。

3. バッチ実行とレガシー実行の出力を比較する

    2 つのランタイムは同一の結果を作るはずなので、CI・開発環境・本番でこれをテストできます。

    ```ruby
    result = MySchema.execute(...)

    # Use a dynamic flag, eg Flipper. This should always be true in development and test.
    if should_run_batching_experiment?
      if !query_string.include?("mutation") && !query_string.include?("subscription") # easy way of checking for queries, could possibly have false negatives
        batched_result = MySchema.execute_batching(...)
        if batched_result.to_h != result.to_h
          # Log this mismatch somehow here, avoiding potential PII/passwords:
          BugTracker.report <<~TXT
            A GraphQL query returned a non-identical response. Sanitized query string:

            #{result.query.sanitized_query_string}

            User: #{current_user.id}
            # Other context info here...
          TXT
        end
      end
    end
    ```

    動的な機能フラグを使うことで、本番トラフィックのごく一部（0% にもできます）にこの検査を適用できます。しばらくそのままにして挙動を観察してください。

    実験は必ず __queries のみ__ を対象にしてください — mutations や subscription に対して二重の副作用を発生させたくありません。

    - 機能フラグには [Flipper](https://github.com/flippercloud/flipper) を参照するか、自前で実装するか、サードパーティサービスを利用してください。
    - 本格的なプロダクション実験システムには [Scientist](https://github.com/github/scientist) を参照してください。

4. 実験を回した後、バッチ結果をレガシー結果の代わりに **返す** 新しいフラグを追加します:

    ```ruby
    if should_use_graphql_future? # again, use a dynamic feature flag
      result = MySchema.execute_batching(...)
    else
      result = MySchema.execute(...)
      if should_run_batching_experiment?
        # Optionally continue running the comparison experiment
      end
    end

    render json: result.to_h
    ```

    本番でこのフラグを上げていき、以下のいずれかになるまで運用します:

    - 新しいエラーが発生した場合: この場合はフラグを 0% に戻し、エラーを修正して再試行します。
    - 100% に到達するまでフラグを上げる: その状態でしばらく運用し、エラーが出ないことを確認します。

    必要に応じて `rescue StandardError` して古い `.execute` にフォールバックすることもできます。

5. しばらくバッチ実行を運用したら、古いコードを削除して常に `.execute_batching` を使うようにします。

    ```ruby
    result = MySchema.execute_batching(...)
    render json: result.to_h
    ```

    また、古いインスタンスメソッドや未使用の構成をスキーマから削除します。（TODO: これを削除する Rubocop ルールを作る予定です。）

## 互換性について

バッチ実行のパフォーマンス向上は、デフォルトで多くの「便利機能」を削る代償を伴います。以下ではそれらの互換性について述べます。

### Query Analyzers（複雑度を含む）✅

サポートは同等です。実行前にまったく同じコードで解析が行われます。

TODO: アナライザ内でロード済みの引数にアクセスする場合は挙動が若干異なる可能性がありますが、レガシーコードを呼びます。

### 認可、スコーピング ✅

完全互換です。`def (self.)authorized?` と `def self.scope_items` は必要に応じて実行中に呼ばれます。

### Visibility（Changesets を含む）✅

Visibility は従来通り動作します。両方のランタイムがスキーマから type 情報を取得する同じメソッドを呼びます。

### Dataloader ✅

Dataloader は新しい実行でも動作しますが、バッチ処理...

TODO: これらのケースを文書化し、将来の互換性をよりよくすることを検討します。

### Tracing ✅

完全にサポートされますが、いくつかのレガシーフックは呼ばれません。代わりに新しいフックを実装してください（既存のランタイムはすでにこれらの新しいフックを呼んでいます）。呼ばれないのは次のものです:

- `execute_field`, `execute_field_lazy`: 代わりに `begin_execute_field`, `end_execute_field` を使ってください。（Dataloader が一時停止したり GraphQL-Batch の promise が返されたりする場合、これらは複数回呼ばれることがあります）
- `execute_query`, `execute_query_lazy`: トップレベルのフックには `execute_multiplex` を使ってください。（単一クエリは常にサイズ = 1 の multiplex として実行されます）
- `resolve_type`, `authorized`: 代わりに `{begin,end}_resolve_type` と `{begin,end}_authorized` を使ってください。（Dataloader 等の影響で複数回呼ばれることがあります）

### Lazy 解決（GraphQL-Batch）🌕

動作しますが、ケースによっては異なります。TODO: それらのケースを文書化し、オプトイン方法を示します。

現時点では `resolve_type` からの lazy 結果は認可互換 shim に縛られています。

### `current_path` ❌

新ランタイムは実際に `current_path` を生成しないため、サポートされていません。

理論的にはサポートすることは可能ですが、大量の作業を要します。もしコアランタイム機能のためにこれを使っている場合は、GitHub issue でユースケースを共有してください。将来の対応を検討します。

### `@defer` と `@stream` ❌

これらは `current_path` に依存するため、まだサポートされていません。

### ObjectCache ❌

おそらく動作すると思われますが、まだ十分にテストしていません。

### 引数 `as:` ✅

`as:` は適用されます: 引数は GraphQL 名ではなく `as:` 名で Ruby メソッドに渡されます。

### 引数 `loads:` ❌

TODO: ある程度のオプトインコードでサポート可能です。レガシーサポートも実装されていますが文書化されていません。

### 引数 `prepare:` ❌

可能ではありますが、まだ実装されていません。レガシーサポートは実装済みと思われます。

### 引数 `validates:` ❌

部分的なサポートが可能で、`obj` が `validates:` に渡されなくなる可能性があります。

### Field Extensions ✅

Field extensions は呼ばれますが、新しいメソッドを使用します:

- `def resolve_batching(objects:, arguments:, context:, &block)` は `object:` の代わりに `objects:` を受け取り、実行を継続するために与えられたブロックにそれらを yield するべきです。
- `def after_resolve_batching(objects:, arguments:, context:, values:, memo:)` は `object:, value:, ...` の代わりに `objects:, values:, ...` を受け取り、単一の結果値ではなく結果の Array を返すべきです。

ランタイムと密接に統合されているため、`ConnectionExtension` と `ScopeExtension` は実際には `after_resolve_batching` を使っていません。代わりにランタイム内にハードコーディングされたサポートがあります。これはフィールド拡張をサポートする価値が低いことを示しているかもしれません。

### Resolver クラス（Mutations と Subscriptions を含む） ❌

何らかの形でサポートされるべきですが、現状ではレガシー互換が存在します。

### Field `extras:`（`lookahead` を含む）✅

`:ast_node` と `:lookahead` はすでに実装されています。他の extras も可能です — 必要であれば issue をあげてください。`extras: [:current_path]` は不可能です。

### `raw_value` ❌

サポートはありますが、スキーマレベルで手動のオプトインが必要です。TODO: オプトインコードを整理してここに文書化します。

### エラーと `rescue_from` ❌

TODO: サポートは可能ですがテストされていません

- `rescue_from` ハンドラ
- `GraphQL::ExecutionError` の発生
- Schema クラスのエラーハンドリングフック

### Connection fields ✅

Connection 引数は自動的に処理され、配列や Relation に接続ラッパーオブジェクトが自動的に適用されます。

### カスタムインスペクション ✅

動作しますが、カスタムの認可や lazy 値を使いたい場合は互換性の注意点を参照してください。