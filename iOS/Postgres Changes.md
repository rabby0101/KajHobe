---
title: "Postgres Changes"
source: "https://supabase.com/docs/guides/realtime/postgres-changes?queryGroups=language&language=swift"
author:
  - "[[Authorization]]"
published: 2025-07-21
created: 2025-07-21
description: "Listen to Postgres changes using Supabase Realtime."
tags:
  - "clippings"
---
## Usage

You can use the Supabase client libraries to subscribe to database changes.


### Listening to specific schemas

Subscribe to specific schema events using the `schema` parameter:
```swift
let myChannel = await supabase.channel("schema-db-changes")

let changes = await myChannel.postgresChange(AnyAction.self, schema: "public")

await myChannel.subscribe()

for await change in changes {
  switch change {
  case .insert(let action): print(action)
  case .update(let action): print(action)
  case .delete(let action): print(action)
  case .select(let action): print(action)
  }
}
```

The channel name can be any string except 'realtime'.

### Listening to INSERT events
```swift
let myChannel = await supabase.channel("schema-db-changes")

let changes = await myChannel.postgresChange(InsertAction.self, schema: "public")

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

The channel name can be any string except 'realtime'.

### Listening to UPDATE events
Use `UpdateAction.self` as type to listen only to database `UPDATE`s:
```swift
let myChannel = await supabase.channel("schema-db-changes")

let changes = await myChannel.postgresChange(UpdateAction.self, schema: "public")

await myChannel.subscribe()

for await change in changes {
  print(change.oldRecord, change.record)
}
```

The channel name can be any string except 'realtime'.

### Listening to DELETE events
```swift
let myChannel = await supabase.channel("schema-db-changes")

let changes = await myChannel.postgresChange(DeleteAction.self, schema: "public")

await myChannel.subscribe()

for await change in changes {
  print(change.oldRecord)
}
```

The channel name can be any string except 'realtime'.

### Listening to specific tables
Subscribe to specific table events using the `table` parameter:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(AnyAction.self, schema: "public", table: "todos")

await myChannel.subscribe()

for await change in changes {
  switch change {
  case .insert(let action): print(action)
  case .update(let action): print(action)
  case .delete(let action): print(action)
  case .select(let action): print(action)
  }
}
```

Subscribe to specific table events using the `table` parameter:

The channel name can be any string except 'realtime'.

### Listening to multiple changes

To listen to different events and schema/tables/filters combinations with the same channel:
```swift
let myChannel = await supabase.channel("db-changes")

let messageChanges = await myChannel.postgresChange(AnyAction.self, schema: "public", table: "messages")
let userChanges = await myChannel.postgresChange(InsertAction.self, schema: "public", table: "users")

await myChannel.subscribe()
```

### Filtering for specific changes

Use the `filter` parameter for granular changes:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  InsertAction.self,
  schema: "public",
  table: "todos",
  filter: .eq("id", value: 1)
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

## Available filters

Realtime offers filters so you can specify the data your client receives at a more granular level.

### Equal to (eq)

To listen to changes when a column's value in a table equals a client-specified value:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  UpdateAction.self,
  schema: "public",
  table: "messages",
  filter: .eq("body", value: "hey")
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

This filter uses Postgres's `=` filter.
### Not equal to (neq)

To listen to changes when a column's value in a table does not equal a client-specified value:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  UpdateAction.self,
  schema: "public",
  table: "messages",
  filter: .neq("body", value: "hey")
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

This filter uses Postgres's `!=` filter.

### Less than (lt)

To listen to changes when a column's value in a table is less than a client-specified value:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  InsertAction.self,
  schema: "public",
  table: "profiles",
  filter: .lt("age", value: 65)
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

This filter uses Postgres's `<` filter, so it works for non-numeric types. Make sure to check the expected behavior of the compared data's type.

### Less than or equal to (lte)

To listen to changes when a column's value in a table is less than or equal to a client-specified value:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  InsertAction.self,
  schema: "public",
  table: "profiles",
  filter: .lte("age", value: 65)
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

This filter uses Postgres' `<=` filter, so it works for non-numeric types. Make sure to check the expected behavior of the compared data's type.

### Greater than (gt)

To listen to changes when a column's value in a table is greater than a client-specified value:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  InsertAction.self,
  schema: "public",
  table: "products",
  filter: .gt("quantity", value: 10)
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

This filter uses Postgres's `>` filter, so it works for non-numeric types. Make sure to check the expected behavior of the compared data's type.

### Greater than or equal to (gte)

To listen to changes when a column's value in a table is greater than or equal to a client-specified value:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  InsertAction.self,
  schema: "public",
  table: "products",
  filter: .gte("quantity", value: 10)
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

This filter uses Postgres's `>=` filter, so it works for non-numeric types. Make sure to check the expected behavior of the compared data's type.

### Contained in list (in)

To listen to changes when a column's value in a table equals any client-specified values:
```swift
let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  InsertAction.self,
  schema: "public",
  table: "products",
  filter: .in("name", values: ["red", "blue", "yellow"])
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```
This filter uses Postgres's `= ANY`. Realtime allows a maximum of 100 values for this filter.

## Receiving old records

By default, only `new` record changes are sent but if you want to receive the `old` record (previous values) whenever you `UPDATE` or `DELETE` a record, you can set the `replica identity` of your table to `full`:
```
12alter table  messages replica identity full;
```

RLS policies are not applied to `DELETE` statements, because there is no way for Postgres to verify that a user has access to a deleted record. When RLS is enabled and `replica identity` is set to `full` on a table, the `old` record contains only the primary key(s).

## Private schemas

Postgres Changes works out of the box for tables in the `public` schema. You can listen to tables in your private schemas by granting table `SELECT` permissions to the database role found in your access token. You can run a query similar to the following:

```
1grant select on "non_private_schema"."some_table" to authenticated;
```

We strongly encourage you to enable RLS and create policies for tables in private schemas. Otherwise, any role you grant access to will have unfettered read access to the table.

## Custom tokens

You may choose to sign your own tokens to customize claims that can be checked in your RLS policies.

Your project JWT secret is found with your [Project API keys](https://app.supabase.com/project/_/settings/api) in your dashboard.

Do not expose the `service_role` token on the client because the role is authorized to bypass row-level security.

To use your own JWT with Realtime make sure to set the token after instantiating the Supabase client and before connecting to a Channel.
```swift
await supabase.realtime.setAuth("your-custom-jwt")

let myChannel = await supabase.channel("db-changes")

let changes = await myChannel.postgresChange(
  UpdateAction.self,
  schema: "public",
  table: "products",
  filter: "name=in.(red, blue, yellow)"
)

await myChannel.subscribe()

for await change in changes {
  print(change.record)
}
```

### Refreshed tokens

You will need to refresh tokens on your own, but once generated, you can pass them to Realtime.
```swift
await supabase.realtime.setAuth("fresh-token")
```

## Limitations

### Delete events are not filterable

You can't filter Delete events when tracking Postgres Changes. This limitation is due to the way changes are pulled from Postgres.

### Spaces in table names

Realtime currently does not work when table names contain spaces.

### Database instance and realtime performance

Realtime systems usually require forethought because of their scaling dynamics. For the `Postgres Changes` feature, every change event must be checked to see if the subscribed user has access. For instance, if you have 100 users subscribed to a table where you make a single insert, it will then trigger 100 "reads": one for each user.

There can be a database bottleneck which limits message throughput. If your database cannot authorize the changes rapidly enough, the changes will be delayed until you receive a timeout.

Database changes are processed on a single thread to maintain the change order. That means compute upgrades don't have a large effect on the performance of Postgres change subscriptions. You can estimate the expected maximum throughput for your database below.

If you are using Postgres Changes at scale, you should consider using separate "public" table without RLS and filters. Alternatively, you can use Realtime server-side only and then re-stream the changes to your clients using a Realtime Broadcast.

Enter your database settings to estimate the maximum throughput for your instance:

#### Set your expected parameters

#### Current maximum possible throughput

| Total DB changes /sec | Max messages per client /sec | Max total messages /sec | Latency p95 |
| --- | --- | --- | --- |
| 64 | 64 | 32,000 | 238ms |

View raw throughput table

Don't forget to run your own benchmarks to make sure that the performance is acceptable for your use case.

We are making many improvements to Realtime's Postgres Changes. If you are uncertain about the performance of your use case, reach out using [Support Form](https://supabase.com/dashboard/support/new) and we will be happy to help you. We have a team of engineers that can advise you on the best solution for your use-case.