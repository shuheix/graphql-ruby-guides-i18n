---
title: バリデーション
description: Rails風の引数に対するバリデーション
sidebar:
  order: 3
---
Arguments は、組み込みまたはカスタムのバリデーションを使って実行時に検証できます。

バリデーションは field または input object 上の `argument(...)` 呼び出しで設定します:

```ruby
argument :home_phone, String,
  description: "A US phone number",
  validates: { format: { with: /\d{3}-\d{3}-\d{4}/ } }
```

あるいは、`field ... do ... end` ブロック内で `validates required: { ... }` と書くこともできます:

```ruby
field :comments, [Comment],
  description: "Find comments by author ID or author name" do
  argument :author_id, ID, required: false
  argument :author_name, String, required: false
  # Either `authorId` or `authorName` must be provided by the client, but not both:
  validates required: { one_of: [:author_id, :author_name] }
end
```

バリデーションはキーワード引数（`validates: { ... }`）で指定するか、設定ブロック内でメソッドとして（`validates ...`）指定できます。

## 組み込みのバリデーション

詳細は各 validator の API ドキュメントを参照してください:

- `length: { maximum: ..., minimum: ..., is: ..., within: ... }` [`Schema::Validator::LengthValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::LengthValidator)
- `format: { with: /.../, without: /.../ }` [`Schema::Validator::FormatValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::FormatValidator)
- `numericality: { greater_than:, greater_than_or_equal_to:, less_than:, less_than_or_equal_to:, other_than:, odd:, even: }` [`Schema::Validator::NumericalityValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::NumericalityValidator)
- `inclusion: { in: [...] }` [`Schema::Validator::InclusionValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::InclusionValidator)
- `exclusion: { in: [...] }` [`Schema::Validator::ExclusionValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::ExclusionValidator)
- `required: { one_of: [...] }` [`Schema::Validator::RequiredValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::RequiredValidator)
- `allow_blank: true|false` [`Schema::Validator::AllowBlankValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::AllowBlankValidator)
- `allow_null: true|false` [`Schema::Validator::AllowNullValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::AllowNullValidator)
- `all: { ... }` [`Schema::Validator::AllValidator`](https://graphql-ruby.org/api-doc/Schema::Validator::AllValidator)

いくつかのバリデータは特定のバリデーション失敗に対するカスタムメッセージを受け付けます。例は API ドキュメントを参照してください。

`allow_blank:` と `allow_null:` は他のバリデーションに影響する場合があります。例えば:

```ruby
validates: { format: { with: /\A\d{4}\Z/ }, allow_blank: true }
```

これにより、4桁の数字だけの String、あるいは Rails が読み込まれている場合は空文字列 (`""`) が許可されます。（GraphQL-Ruby は通常 Rails が定義する `.blank?` をチェックします。）

あるいは、単独で使うこともできます。例えば:

```ruby
argument :id, ID, required: false, validates: { allow_null: true }
```

`id: null` を渡すクエリを許可します。

## カスタムバリデータ

カスタムバリデータも作成できます。バリデータは `GraphQL::Schema::Validator` を継承したクラスで、次を実装するべきです:

- `def initialize(..., **default_options)` はバリデータ固有のオプションを受け取り、デフォルトを `super(**default_options)` に渡すようにします
- `def validate(object, context, value)` は実行時に `value` を検証するために呼ばれます。String のエラーメッセージまたは String の配列を返すことができます。GraphQL-Ruby はこれらのメッセージをランタイムのコンテキスト情報と共にトップレベルの "errors" 配列に追加します。

その後、カスタムバリデータは次のいずれかの方法で設定できます:

- 直接、`validates` に渡す（例: `validates: { MyCustomValidator => { some: :options }`）。
- キーワードとして、`GraphQL::Schema::Validator.install(:custom, MyCustomValidator)` でそのキーワードを登録した場合（この場合は `validates: { custom: { some: :options }}` をサポートします）。

Validator はスキーマが構築されるとき（アプリケーション起動時）に初期化され、`validate(...)` はクエリ実行中に呼ばれます。各 field、argument、または input object の各設定ごとに 1 つの `Validator` インスタンスが作成されます（`Validator` インスタンスは共有されません）。