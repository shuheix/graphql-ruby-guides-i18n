---
title: ActiveRecord バックエンド
description: ActiveRecord を使った永続化クエリの保存
sidebar:
  order: 2
pro: true
---
GraphQL-Pro の `OperationStore` は ActiveRecord を使って永続化クエリを保存できます。データベースをセットアップすると、必要に応じてそれらのテーブルを使用して読み書きします。

## データベースのセットアップ

ActiveRecord を使うには、`GraphQL::Pro::OperationStore` がいくつかのデータベーステーブルを必要とします。

### Rails ジェネレータ

Rails を使っている場合、必要なマイグレーションを生成してから実行できます:

```bash
$ rails generate graphql:operation_store:create
$ rails db:migrate
```

（ステージングや本番サーバーでもそのマイグレーションを実行する必要があります。）

これで、`OperationStore` は ActiveRecord を使ってクエリを保存するための準備が整いました！

### 手動でのセットアップ

空のマイグレーションを生成して、手動で必要なマイグレーションを作成することもできます:

```bash
$ rails generate migration SetupOperationStore
```

その後、マイグレーションファイルを開いて次を追加します:

```ruby
# ...
# implement the change method with:
def change
  create_table :graphql_clients, primary_key: :id do |t|
    t.column :name, :string, null: false
    t.column :secret, :string, null: false
    t.timestamps
  end
  add_index :graphql_clients, :name, unique: true
  add_index :graphql_clients, :secret, unique: true

  create_table :graphql_operations, primary_key: :id do |t|
    t.column :digest, :string, null: false
    t.column :body, :text, null: false
    t.column :name, :string, null: false
    t.timestamps
  end
  add_index :graphql_operations, :digest, unique: true

  create_table :graphql_client_operations, primary_key: :id do |t|
    t.references :graphql_client, null: false
    t.references :graphql_operation, null: false
    t.column :alias, :string, null: false
    t.column :last_used_at, :datetime
    t.column :is_archived, :boolean, default: false
    t.timestamps
  end
  add_index :graphql_client_operations, [:graphql_client_id, :alias], unique: true, name: "graphql_client_operations_pairs"
  add_index :graphql_client_operations, :is_archived

  create_table :graphql_index_entries, primary_key: :id do |t|
    t.column :name, :string, null: false
  end
  add_index :graphql_index_entries, :name, unique: true

  create_table :graphql_index_references, primary_key: :id do |t|
    t.references :graphql_index_entry, null: false
    t.references :graphql_operation, null: false
  end
  add_index :graphql_index_references, [:graphql_index_entry_id, :graphql_operation_id], unique: true, name: "graphql_index_reference_pairs"
end
```

その後、マイグレーションを実行します:

```
$ bundle exec rake db:migrate
```

（ステージングや本番サーバーでもそのマイグレーションを実行する必要があります。）

これで、`OperationStore` は ActiveRecord を使ってクエリを保存するための準備が整いました！

## データベースの更新

GraphQL-Pro 1.15.0 で OperationStore の新機能が追加されました。これらを有効にするには、データベースにいくつかのカラムを追加してください:

```ruby
add_column :graphql_client_operations, :is_archived, :boolean, default: false
add_column :graphql_client_operations, :last_used_at, :datetime
```

## `last_used_at` の更新

デフォルトでは、GraphQL-Pro はバックグラウンドスレッドで `last_used_at` の値を 5 秒ごとに更新します。`OperationStore` をインストールする際に `update_last_used_at_every:` に秒数を渡してカスタマイズできます:

```ruby
use GraphQL::Pro::OperationStore, update_last_used_at_every: 1 # seconds
```

`0` を渡すと、操作がアクセスされるたびにそのカラムをインラインで更新します。

注意: テスト環境ではこれを `0` に設定することを推奨します。別スレッドでの遅延更新が原因で間欠的なテストのハングや失敗が発生する可能性があるためです。例えば:

```ruby
# Update immediately in Test, wait 5 seconds in other environments:
use GraphQL::Pro::OperationStore, update_last_used_at_every: Rails.env.test? ? 0 : 5
```