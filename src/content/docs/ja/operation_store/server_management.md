---
title: サーバー管理
description: OperationStore を用いた persisted queries の管理のヒント
sidebar:
  order: 5
pro: true
---
[入門](/operation_store/getting_started) を終えたら、いくつか注意すべき点があります。

## 任意のクエリを拒否する

persisted queries を使うと、任意の GraphQL 入力を受け付けないようにできます。これにより、悪意のあるユーザーがサーバー上で大きなクエリや不適切なクエリを実行するのを防げます。

要するに、`MySchema.execute` の最初の引数を _渡さない（スキップする）ことで、任意の GraphQL を無視できます:

```ruby
# app/controllers/graphql.rb

# Don't pass a query string; ignore `params[:query]`
MySchema.execute(
  context: context,
  variables: params[:variables],
  operation_name: params[:operationName],
)
```

ただし、次の点を考慮してください:

- 以前のクライアントが任意の GraphQL をまだ使っていないか？（例えば、古いバージョンのネイティブアプリや古いウェブページがまだ GraphQL を送っているかもしれません）
- 一部のユーザーには引き続きカスタム文字列の送信を許可するべきか？（例えば、スタッフが新機能を開発したりデバッグしたりするために GraphiQL を使っている場合など）

該当する場合は、`query_string` に対してロジックを適用できます:

```ruby
# Allow arbitrary GraphQL:
# - from staff users
# - in development
query_string = if current_user.staff? || Rails.env.development?
  params[:query]
else
  nil
end

MySchema.execute(
  query_string, # maybe nil, that's OK.
  context: context,
  variables: params[:variables],
  operation_name: params[:operationName],
)
```

## データのアーカイブと削除

クライアントはデータベースに対して _追加_ することしかできませんが、管理者としてデータベースからエントリをアーカイブまたは削除することもできます。（必ず [ダッシュボードへのアクセスを認可する](/pro/dashboard) を確認してください。）これは危険な操作です: 何かをアーカイブまたは削除すると、そのデータに依存しているクライアントはクラッシュする可能性があります。

データベースからアーカイブまたは削除する理由の例:

- データが誤ってプッシュされた。該当データは使われていない。
- クエリが無効または安全でない。保持するより削除した方が良い。

該当する場合は、"Archive" や "Delete" ボタンを使って本番環境から項目を削除できます。

operation がアーカイブされると、クライアントからは利用できなくなりますが、データベースには残ります。後でアンアーカイブできるため、完全削除よりリスクが低くなります。

## アプリケーションとの統合

OperationStore に Ruby API を追加してアプリケーションと統合できるようにすることがロードマップにあります。例えば次のようなことが可能になります:

- システム内のユーザーに対応するクライアントを作成する
- ダッシュボードを通じてクライアントシークレットを表示し、ユーザーに保存させる
- OperationStore のデータを使って独自の管理ダッシュボードをレンダリングする

興味がある場合は、ぜひ {% open_an_issue "OperationStore Ruby API" %} を開くか、`support@graphql.pro` にメールしてください。