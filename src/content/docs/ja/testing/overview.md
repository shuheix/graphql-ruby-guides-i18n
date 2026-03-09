---
title: 概要
description: GraphQL システムのテスト
sidebar:
  order: 0
redirect_from:
- "/schema/testing"
---
というわけで、GraphQL API のプロトタイプを作成し、今はそれを整備して適切なテストを追加する段階です。これらのガイドは、GraphQL システムの安定性と互換性を確保する方法を考える際に役立ちます。

- [構造テスト](/testing/schema_structure) は schema の変更が後方互換であることを検証します。こうすることで既存のクライアントを壊さないようにします。
- [統合テスト](/testing/integration_tests) は GraphQL システムのさまざまな挙動を検証し、適切なデータが適切なクライアントに返されることを確認します。
- [テスト用ヘルパー](/testing/helpers) は、完全な query を書かずに GraphQL field を実行するためのヘルパーです。