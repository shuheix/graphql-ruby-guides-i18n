---
title: よくある質問
description: よくある操作の方法
---
ルートの URL を返す
====================
GraphQL を使うと他の REST リソースへのリソース URL を含める必要は少なくなりますが、時には Rails のルーティングを使って URL をフィールドの一つとして返したいことがあります。一般的なユースケースは、React UI 内でリンクをレンダリングするために HTML 形式の URL を組み立てる場合です。その場合、ヘルパーが受信ホスト、ポート、プロトコルに基づいて完全な URL を構築できるように、request を context に渡すことができます。

例
-------
```ruby
class Types::UserType < Types::BaseObject
  include ActionController::UrlFor
  include Rails.application.routes.url_helpers
  # Needed by ActionController::UrlFor to extract the host, port, protocol etc. from the current request
  def request
    context[:request]
  end
  # Needed by Rails.application.routes.url_helpers, it will then use the url_options defined by ActionController::UrlFor
  def default_url_options
    {}
  end
  
  field :profile_url, String, null: false
  def profile_url
    user_url(object)
  end
end

# In your GraphQL controller, add the request to `context`:
MySchema.execute(
  params[:query],
  variables: params[:variables],
  context: {
    request: request
  },
)
```

ActiveStorage の blob URL を返す
=================================
ActiveStorage を使用していて添付ファイルの blob への URL を返す必要がある場合、`Rails.application.routes.url_helpers.rails_blob_url` を単独で使うと例外が発生します。Rails はどのホスト、ポート、プロトコルを使うか分からないためです。
GraphQL コントローラに `ActiveStorage::SetCurrent` を include すると、この情報を resolver に渡すことができます。

例
=======

```ruby
class GraphqlController < ApplicationController
  include ActiveStorage::SetCurrent
  ...
end

class Types::UserType < Types::BaseObject
  field :picture_url, String, null: false
  def picture_url
    Rails.application.routes.url_helpers.rails_blob_url(
      object.picture,
      protocol: ActiveStorage::Current.url_options[:protocol],
      host: ActiveStorage::Current.url_options[:host],
      port: ActiveStorage::Current.url_options[:port]
    )
  end
end
```