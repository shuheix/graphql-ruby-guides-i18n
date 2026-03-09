---
title: 実行時の考慮事項
description: クエリごとの設定と可観測性
sidebar:
  order: 4
enterprise: true
---
キャッシュが設定されている場合、クエリ実行中に注意すべき点がいくつかあります。

## キャッシュをスキップする

特定のクエリで `ObjectCache` を無効にするには、クエリの `context: { ... }` に `skip_object_cache: true` を設定します。

## キャッシュにオブジェクトを手動で追加する

デフォルトでは、`ObjectCache` は結果内の各 GraphQL オブジェクトの「背後にある」オブジェクトを収集し、それらのフィンガープリントをキャッシュキーとして使用します。クエリ実行中に別のオブジェクトを手動でキャッシュに登録するには、オブジェクトと `context` を渡して `Schema::Object.cacheable_object(...)` を呼び出します。例:

```ruby
field :team_member_count, Integer, null: true do
  argument :name, String, required: true
end

def team_member_count(name:)
  team = Team.find_by(name: name)
  if team
    # Register this object so that the cached result
    # will be invalidated when the team is updated:
    Types::Team.cacheable_object(team, context)
    team.members.count
  else
    nil
  end
end
```

（キャッシュが無効になっている場合、`cacheable_object(...)` は no-op になります。）

## キャッシュの測定

キャッシュ実行中は、いくつかのデータが Hash として `context[:object_cache]` にログされます。例えば:

```ruby
result = MySchema.execute(...)
pp result.context[:object_cache]
{
  key: "...",                 # the cache key used for this query
  write: true,                # if this query caused an update to the cache
  ttl: 15,                    # the smallest `ttl:` value encountered in this query (used for this query's result)
  hit: true,                  # if this query returned a cached result
  public: false,              # true or false, whether this query used a public cache key or a private one
  messages: ["...", "..."],   # status messages about the cache's behavior
  objects: Set(...),          # application objects encountered during the query
  uncacheable: true,          # if ObjectCache found a reason that this query couldn't be cached (see `messages: ...` for reason)
  reauthorized_cached_objects: true,
                              # if `.authorized?` was checked for cached objects, see "Disabling Reauthorization"
}
```

## キャッシュを手動でリフレッシュする

クエリのキャッシュを手動でクリアする必要がある場合は、`context: { refresh_object_cache: true, ... }` を渡します。これにより `ObjectCache` は既にキャッシュされている結果（存在する場合）を削除し、そのクエリのキャッシュ有効性を再評価して、新たに実行された結果を返します。

通常はこれを明示的に行う必要はありません。オブジェクトが [cache fingerprints](/object_cache/schema_setup.html#object-fingerprint) を正しく更新するようにしておけば、エントリは再実行が必要になったときに期限切れになります。キャッシュ内のすべての結果を期限切れにする方法については [Schema fingerprint](/object_cache/schema_setup.html#schema-fingerprint) も参照してください。