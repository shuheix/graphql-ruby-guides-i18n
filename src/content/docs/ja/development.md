---
title: 開発
description: GraphQL Ruby のハッキング
---
では、GraphQL Ruby に手を入れたいということですね！ここでは始めるためのいくつかのヒントを紹介します。

- [セットアップ](#セットアップ) your development environment
- [テストの実行](#テストの実行) to verify your setup
- [pryでデバッグ](#pryでデバッグ) with pry
- [ベンチマークの実行](#ベンチマークの実行) to test performance in your environment
- [コーディングガイドライン](#コーディングガイドライン) for working on your contribution
- レキサーとパーサーをビルドするための特別なツール
- [GraphQL Ruby のウェブサイトを構築・公開する](#ウェブサイト)
- [バージョニング](#バージョニング) describes how changes are managed and released
- [リリース](#リリース) Gem versions

## セットアップ

自分のコピーを用意するには、まず [`rmosolgo/graphql-ruby` on GitHub](https://github.com/rmosolgo/graphql-ruby) をフォークしてクローンしてください。

その後、依存関係をインストールします:

- SQLite3 と MongoDB をインストールします（例: `brew install sqlite && brew tap mongodb/brew && brew install mongodb-community`）
- `bundle install`
- `rake compile # If you get warnings at this step, you can ignore them.`
- 任意: レキサーをビルドするには [Ragel](https://www.colm.net/open-source/ragel/) が必要です

## テストの実行

### ユニットテスト

テストは次のように実行できます:

```
bundle exec rake        # tests & Rubocop
bundle exec rake test   # tests only
```

特定のファイルだけを実行するには `TEST=` を使います:

```
bundle exec rake test TEST=spec/graphql/query_spec.rb
# run tests in `query_spec.rb` only
```

特定の例だけに集中するには `focus` を使います:

```ruby
focus
it "does something cool" do
  # ...
end
```

すると、`focus` が付いたテストだけが実行されます:

```
bundle exec rake test
# only the focused test will be run
```

（これは `minitest-focus` によって提供されています。）

### 統合テスト

統合テストを実行するには、`gemfiles/` の中から特定の gemfile を選ぶ必要があります。例えば:

```
BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle exec rake test TEST=spec/integration/rails/graphql/relay/array_connection_spec.rb
```

### GraphQL-CParser のテスト

`graphql_cparser` gem をテストするには、まずバイナリをビルドする必要があります:

```
bundle exec rake build_ext
```

その後、`GRAPHQL_CPARSER=1` を付けてテストスイートを実行します:

```
GRAPHQL_CPARSER=1 bundle exec rake test
```

（特定のファイルを選ぶには `TEST=` を追加してください。）

### その他のテスト

ActionCable の動作を確認する system テストは次のように実行します:

```
bundle exec rake test:system
```

および JavaScript のテスト:

```
bundle exec rake test:js
```

## Gemfiles, Gemfiles, Gemfiles

`graphql-ruby` にはさまざまな Rails バージョンをサポートするための複数の gemfile が用意されています。`BUNDLE_GEMFILE` で gemfile を指定できます。例:

```
BUNDLE_GEMFILE=gemfiles/rails_5.gemfile bundle exec rake test
```

## pryでデバッグ

デバッグの補助として、GraphQL-Ruby の開発セットアップには [`pry`](https://pry.github.io/) が含まれています。

Ruby コードの実行を一時停止したい場所に、次を追加してください:

```ruby
binding.pry
```

するとプログラムが一時停止し、ターミナルが Ruby の REPL になります。開発の過程で `pry` を自由に使ってください。

## ベンチマークの実行

このプロジェクトにはベンチマークを記録するためのいくつかの Rake タスクが含まれています:

```sh
$ bundle exec rake -T | grep bench:
rake bench:profile         # Generate a profile of the introspection query
rake bench:query           # Benchmark the introspection query
rake bench:validate        # Benchmark validation of several queries
```

結果をファイルに保存するには出力をファイルに送ります:

```sh
$ bundle exec rake bench:validate > before.txt
$ cat before.txt
# ...
# --> benchmark output here
```

パフォーマンスを確認したい場合は、変更前にこれらのタスクを実行してベースラインを作成してください。変更を加えたら再度タスクを実行して結果を比較します。

ベンチマークを使う際に留意する点:

- 結果はハードウェア依存です: ハードウェアが異なると結果も異なります。したがって、他のマシンの結果と比較しないでください。
- 結果は環境依存です: CPU やメモリの利用状況は他のプロセスに影響されます。できるだけ同じ環境で前後比較を行ってください。

## コーディングガイドライン

GraphQL-Ruby は堅牢なテストスイートを備え、日々の安定動作を確保しています。変更を行う際は、それを説明するテストを必ず追加してください。例えば:

- バグ修正を寄稿する場合は、壊れていた（そして修正された）コードに対するテストを含めてください
- 機能を追加する場合は、その機能の想定される全ての用途に対するテストを含めてください
- 既存の挙動を変更する場合は、そのコードに対する想定される全ての挙動をカバーするようテストを更新してください

コードスタイルや構成を過度に心配する必要はありません。CI 上で実行される最小限の RuboCop 設定が `.rubocop.yml` にあります。手動で実行するには `bundle exec rake rubocop` を使ってください。

## ウェブサイト

ウェブサイトを更新するには、`guides/` の `.md` ファイルを更新してください。

変更をプレビューするには、ローカルでサイトをサーブできます:

```
bundle exec rake site:serve
```

その後、`http://localhost:4000` にアクセスしてください。

GitHub Pages でサイトを公開するには、次の Rake タスクを実行します:

```
bundle exec rake site:publish
```

### 検索インデックス

GraphQL-Ruby の検索インデックスは Algolia によって提供されています。インデックスを更新するには、環境変数に API キーを設定する必要があります:

```
$ export ALGOLIA_API_KEY=...
```

このキーがないと、検索インデックスがサイトと同期しなくなります。キーのアクセスが必要な場合は @rmosolgo に連絡してください。

### API ドキュメント

GraphQL-Ruby のウェブサイトには、gem の API ドキュメントのレンダリング版があります。これらは特別なプロセスで GitHub Pages にプッシュされます。

まず、公開したいドキュメントのローカルコピーを生成します:

```
$ bundle exec rake apidocs:gen_version[1.8.0] # for example, generate docs that you want to publish
```

次に、ローカルで確認します:

```
$ bundle exec rake site:serve
# then visit http://localhost:4000/api-doc/1.8.0/
```

その後、サイト全体の一部として公開します:

```
$ bundle exec rake site:publish
```

最後に、ウェブサイト上のドキュメントを訪れて作業を確認してください。

## バージョニング

GraphQL-Ruby は、jashkenas の投稿 ["Why Semantic Versioning Isn't"](https://gist.github.com/jashkenas/cbd2b088e20279ae2c8e) で述べられている理由により、厳密な「セマンティックバージョニング」を追求していません。その代わりに、以下の方式をガイドラインとして使用しています:

- バージョン番号は `MAJOR.MINOR.PATCH` の三部構成です
- __`PATCH`__ はバグ修正や特定のユースケース向けの小さな機能を示します。理想的には、CHANGELOG を軽く読むだけで patch バージョンにアップグレードできます。
- __`MINOR`__ は重要な追加、内部リファクタ、または小さな破壊的変更を示します。minor バージョンにアップグレードする際は、システムに適用される新機能や破壊的変更がないか CHANGELOG を確認してください。CHANGELOG には破壊的変更に対する移行パスが必ず記載されます。minor バージョンには、将来の破壊的変更を警告する deprecation 警告が含まれることがあります。
- __`MAJOR`__ は大きな破壊的変更を示します。特に deprecation 警告を出していた場合でも、何らかの修正が必要になると考えてください。

この方針は [Ruby 2.1.0+ のバージョンポリシー](https://www.ruby-lang.org/en/news/2013/12/21/ruby-version-policy-changes-with-2-1-0/) に触発されています。

Pull request や issue には、どのリリースで出すかを示すために [GitHub milestone](https://github.com/rmosolgo/graphql-ruby/milestones) が付けられることがあります。

[CHANGELOG](https://github.com/rmosolgo/graphql-ruby/blob/master/CHANGELOG.md) には、ユーザーがアップグレードできるよう正確かつ詳細な情報を常に記載してください。もし CHANGELOG を参照してもアップグレードに問題がある場合は、GitHub に issue を開いてください。

## リリース

GraphQL-Ruby には厳格なリリーススケジュールはありません。もしスケジュールが必要だと思うなら、意見を共有するために issue を開いてください。

リリースを切るには:

- 新しいバージョンのために `CHANGELOG.md` を更新する:
  - 新しいバージョン用の見出しを追加し、4 つのカテゴリの変更点を新セクションに貼り付けます
  - 対応する GitHub milestone を開きます
  - 各プルリクエストを確認し、該当するカテゴリ（複数可）に分類します
    - 変更が GraphQL-Ruby のデフォルト動作に破壊的な影響を与える場合は `## Breaking Changes` に追加し、可能なら移行ノートを含めてください
    - 変更説明の横に PR 番号を付けて参照できるようにしてください
- `lib/graphql/version.rb` を新しいバージョン番号に更新します
- 変更を master にコミットします
- GitHub に変更をプッシュします: `git push origin master`。GitHub Actions がサイトを更新します。
- RubyGems にリリースします: `bundle exec rake release`。これによりタグが GitHub にプッシュされ、API ドキュメントを更新する GitHub Actions ジョブが走ります。
- お祝いしましょう 🎊 !