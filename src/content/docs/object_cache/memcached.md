---
title: Dalli Configuration
description: Setting up the Memcached backend
sidebar:
  order: 3
enterprise: true
---

`GraphQL::Enterprise::ObjectCache` can also run with a Memcached backend via the [Dalli](https://github.com/petergoldstein/dalli) client gem.

Set it up by passing a `Dalli::Client` instance as `dalli: ...`, for example:

```ruby
use GraphQL::Enterprise::OperationStore, dalli: Dalli::Client.new(...)
```
