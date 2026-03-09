---
title: 実装
description: Subscription の実行と配信
sidebar:
  order: 3
---
[`GraphQL::Subscriptions`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions) プラグインは、subscription を実装するための基底クラスです。

各メソッドは subscription ライフサイクルの各段階に対応します。メソッドごとの説明は API ドキュメントを参照してください: [`GraphQL::Subscriptions`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions)。

また、実装例として [Pusher 実装ガイド](subscriptions/pusher_implementation)、[Ably 実装ガイド](subscriptions/ably_implementation)、[ActionCable 実装ガイド](subscriptions/action_cable_implementation)、もしくは [`GraphQL::Subscriptions::ActionCableSubscriptions`](https://graphql-ruby.org/api-doc/GraphQL::Subscriptions::ActionCableSubscriptions) のドキュメントを参照してください。

## 考慮事項

Ruby アプリケーションはそれぞれ異なるため、subscription を実装する際は以下の点を検討してください:

- アプリケーションは単一プロセスですか、それともマルチプロセスですか？単一プロセスのアプリケーションならメモリに状態を保持できますが、マルチプロセスのアプリケーションでは全プロセスを最新の状態に保つためにメッセージブローカーが必要になります。
- 永続化やメッセージ伝達にアプリケーションのどのコンポーネントを使えますか？
- 購読中のクライアントへプッシュ更新をどのように配信しますか？（例: WebSocket、ActionCable、Pusher、webhook、その他）
- [thundering herd（同時アクセス集中）](https://en.wikipedia.org/wiki/Thundering_herd_problem) をどのように扱いますか？イベントがトリガーされたときに、システムを圧倒せずにクライアントを更新するためのデータベースアクセスをどのように管理しますか？

## ブロードキャスト

_ブロードキャスト_ による複数の購読者への更新配信は GraphQL-Ruby でサポートされていますが、実装固有の作業が必要です。詳細は [ブロードキャストガイド](subscriptions/broadcast) を参照してください。