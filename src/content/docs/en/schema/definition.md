---
title: Definition
description: Defining your schema
sidebar:
  order: 1
---


A GraphQL system is called a _schema_. The schema contains all the types and fields in the system. The schema executes queries and publishes an [introspection system](/schema/introspection).

Your GraphQL schema is a class that extends [`GraphQL::Schema`](https://graphql-ruby.org/api-doc/GraphQL::Schema), for example:

```ruby
class MyAppSchema < GraphQL::Schema
  max_complexity 400
  query Types::Query
  use GraphQL::Dataloader

  # Define hooks as class methods:
  def self.resolve_type(type, obj, ctx)
    # ...
  end

  def self.object_from_id(node_id, ctx)
    # ...
  end

  def self.id_from_object(object, type, ctx)
    # ...
  end
end
```

There are lots of schema configuration methods.

For defining GraphQL types, see the guides for those types: [object types](/type_definitions/objects), [interface types](/type_definitions/interfaces), [union types](/type_definitions/unions),  [input object types](/type_definitions/input_objects), [enum types](/type_definitions/enums), and [scalar types](/type_definitions/scalars).

## Types in the Schema

- [`Schema.query`](https://graphql-ruby.org/api-doc/Schema.query), [`Schema.mutation`](https://graphql-ruby.org/api-doc/Schema.mutation), and [`Schema.subscription`](https://graphql-ruby.org/api-doc/Schema.subscription) declare the [entry-point types](https://graphql.org/learn/schema/#the-query-mutation-and-subscription-types) of the schema.
- [`Schema.orphan_types`](https://graphql-ruby.org/api-doc/Schema.orphan_types) declares object types which implement [Interfaces](/type_definitions/interfaces) but aren't used as field return types in the schema. For more about this specific scenario, see [Orphan Types](/type_definitions/interfaces#orphan-types)

### Lazy-loading types

In development, GraphQL-Ruby can defer loading your type definitions until they're needed. This requires some configuration to opt in:

- Add `use GraphQL::Schema::Visibility` to your schema. ([`GraphQL::Schema::Visibility`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Visibility) supports lazy loading and will be the default in a future GraphQL-Ruby version. See [Migration Notes](/authorization/visibility#migration-notes) if you have an existing visibility implementation.)
- Move your entry-point type definitions into a block, for example:

  ```diff
  - query Types::Query
  + query { Types::Query }
  ```

- Optionally, move field types into blocks, too:

  ```diff
  - field :posts, [Types::Post] # Loads `types/post.rb` immediately
  + field :posts do
  +   type([Types::Post]) # Loads `types/post.rb` when this field is used in a query
  + end
  ```

To enforce these patterns, you can enable two Rubocop rules that ship with GraphQL-Ruby:

- `GraphQL/RootTypesInBlock` will make sure that `query`, `mutation`, and `subscription` are all defined in a block.
- `GraphQL/FieldTypeInBlock` will make sure that non-built-in field return types are defined in blocks.

## Object Identification

Some GraphQL features use unique IDs to load objects:

- the `node(id:)` field looks up objects by ID (See [Object Identification](/schema/object_identification) for more about Relay-style object identification.)
- any arguments with `loads:` configurations look up objects by ID
- the [ObjectCache](/object_cache/overview) uses IDs in its caching scheme

To use these features, you must provide some methods for generating UUIDs and fetching objects with them:

[`Schema.object_from_id`](https://graphql-ruby.org/api-doc/Schema.object_from_id) is called by GraphQL-Ruby to load objects directly from the database. It's usually used by the `node(id: ID!): Node` field (see [`GraphQL::Types::Relay::Node`](https://graphql-ruby.org/api-doc/GraphQL::Types::Relay::Node)), Argument [loads:](/mutations/mutation_classes#auto-loading-arguments), or the [ObjectCache](/object_cache/overview). It receives a unique ID and must return the object for that ID, or `nil` if the object isn't found (or if it should be hidden from the current user).

[`Schema.id_from_object`](https://graphql-ruby.org/api-doc/Schema.id_from_object) is used to implement `Node.id`. It should return a unique ID for the given object. This ID will later be sent to `object_from_id` to refetch the object.

Additionally, [`Schema.resolve_type`](https://graphql-ruby.org/api-doc/Schema.resolve_type) is called by GraphQL-Ruby to get the runtime Object type for fields that return return [interface](/type_definitions/interfaces) or [union](/type_definitions/unions) types.

## Error Handling

- [`Schema.type_error`](https://graphql-ruby.org/api-doc/Schema.type_error) handles type errors at runtime, read more in the [Type errors guide](/errors/type_errors).
- [`Schema.rescue_from`](https://graphql-ruby.org/api-doc/Schema.rescue_from) defines error handlers for application errors. See the [error handling guide](/errors/error_handling) for more.
- [`Schema.parse_error`](https://graphql-ruby.org/api-doc/Schema.parse_error) and [`Schema.query_stack_error`](https://graphql-ruby.org/api-doc/Schema.query_stack_error) provide hooks for reporting errors to your bug tracker.

## Default Limits

- [`Schema.max_depth`](https://graphql-ruby.org/api-doc/Schema.max_depth) and [`Schema.max_complexity`](https://graphql-ruby.org/api-doc/Schema.max_complexity) apply some limits to incoming queries. See [Complexity and Depth](/queries/complexity_and_depth) for more.
- [`Schema.default_max_page_size`](https://graphql-ruby.org/api-doc/Schema.default_max_page_size) applies limits to [connection fields](/pagination/overview).
- [`Schema.validate_timeout`](https://graphql-ruby.org/api-doc/Schema.validate_timeout), [`Schema.validate_max_errors`](https://graphql-ruby.org/api-doc/Schema.validate_max_errors) and [`Schema.max_query_string_tokens`](https://graphql-ruby.org/api-doc/Schema.max_query_string_tokens) all apply limits to query execution. See [Timeout](/queries/timeout) for more.

## Introspection

- [`Schema.extra_types`](https://graphql-ruby.org/api-doc/Schema.extra_types) declares types which should be printed in the SDL and returned in introspection queries, but aren't otherwise used in the schema.
- [`Schema.introspection`](https://graphql-ruby.org/api-doc/Schema.introspection) can attach a [custom introspection system](/schema/introspection) to the schema.

## Authorization

- [`Schema.unauthorized_object`](https://graphql-ruby.org/api-doc/Schema.unauthorized_object) and [`Schema.unauthorized_field`](https://graphql-ruby.org/api-doc/Schema.unauthorized_field) are called when [authorization hooks](/authorization/authorization) return `false` during query execution.

## Execution Configuration

- [`Schema.trace_with`](https://graphql-ruby.org/api-doc/Schema.trace_with) attaches tracer modules. See [Tracing](/queries/tracing) for more.
- [`Schema.query_analyzer`](https://graphql-ruby.org/api-doc/Schema.query_analyzer) and {{ "Schema.multiplex_analyzer" }} accept processors for ahead-of-time query analysis, see [Analysis](/queries/ast_analysis) for more.
- [`Schema.default_logger`](https://graphql-ruby.org/api-doc/Schema.default_logger) configures a logger for runtime. See [Logging](/queries/logging).
- [`Schema.context_class`](https://graphql-ruby.org/api-doc/Schema.context_class) and [`Schema.query_class`](https://graphql-ruby.org/api-doc/Schema.query_class) attach custom subclasses to your schema to use during execution.
- [`Schema.lazy_resolve`](https://graphql-ruby.org/api-doc/Schema.lazy_resolve) registers classes with [lazy execution](/schema/lazy_execution).

## Plugins

- [`Schema.use`](https://graphql-ruby.org/api-doc/Schema.use) adds plugins to your schema. For example, [`GraphQL::Dataloader`](https://graphql-ruby.org/api-doc/GraphQL::Dataloader) and [`GraphQL::Schema::Visibility`](https://graphql-ruby.org/api-doc/GraphQL::Schema::Visibility) are installed this way.

## Production Considerations

- __Parser caching__: if your application parses GraphQL _files_ (queries or schema definition), it may benefit from enabling [`GraphQL::Language::Cache`](https://graphql-ruby.org/api-doc/GraphQL::Language::Cache).
- __Eager loading the library__: by default, GraphQL-Ruby autoloads its constants as-needed. In production, they should be eager loaded instead, using `GraphQL.eager_load!`.

  - Rails: enabled automatically. (ActiveSupport calls `.eager_load!`.)
  - Sinatra: add `configure(:production) { GraphQL.eager_load! }` to your application file.
  - Hanami: add `environment(:production) { GraphQL.eager_load! }` to your application file.
  - Other frameworks: call `GraphQL.eager_load!` when your application is booting in production mode.

  See [`GraphQL::Autoload#eager_load!`](https://graphql-ruby.org/api-doc/GraphQL::Autoload#eager_load!) for more details.
