<!-- e29ee941-df4f-4d2d-9bee-7b7bde23590f cb856d0d-c9bd-46b7-93fd-023c05ab2a3d -->
# Make Dream Minimal - Clean MVC Architecture

## Goal

Transform Dream into minimal routing toolkit, extract all utilities to modules, validate clean MVC (no anonymous functions, no nested cases) with CMS example.

## Phase 1: Extract to Modules

### Dream Core Keeps

- `src/dream/router.gleam`
- `src/dream/http/transaction.gleam`
- `src/dream/http/method.gleam`
- `src/dream/context.gleam`
- `src/dream/servers/mist/`

### Dream Core Deletes

- `src/dream/http/statuses.gleam`
- `src/dream/core/singleton.gleam`
- `src/dream/validators/`
- `src/dream/services/`
- `src/dream/utilities/`

### Create 6 Modules

- `modules/helpers/` → dream_helpers (statuses, validators, response builders)
- `modules/singleton/` → dream_singleton (generic singleton)
- `modules/config/` → dream_config (dotenv loading)
- `modules/postgres/` → dream_postgres (query helpers, singleton)
- `modules/http_client/` → dream_http_client (HTTP client)
- `modules/opensearch/` → dream_opensearch (document store)

## Phase 2: Update 7 Existing Examples

All examples add `dream_helpers` and update imports.

Specific updates:

- database → add dream_postgres
- streaming → add dream_http_client
- singleton → add dream_singleton

## Phase 3: Create CMS Example

### File Structure

```
examples/cms/
├── docker-compose.yml
├── gleam.toml
├── Makefile
├── README.md
├── .env.example
├── priv/migrations/
├── src/
│   ├── main.gleam
│   ├── router.gleam
│   ├── context.gleam
│   ├── services.gleam
│   ├── config.gleam
│   ├── types/
│   │   ├── user.gleam
│   │   ├── post.gleam
│   │   ├── event.gleam
│   │   └── errors.gleam
│   ├── models/
│   │   ├── user/
│   │   │   ├── user.gleam
│   │   │   ├── sql.gleam
│   │   │   └── sql/*.sql
│   │   ├── post/
│   │   │   ├── post.gleam
│   │   │   ├── sql.gleam
│   │   │   └── sql/*.sql
│   │   └── event/
│   │       └── event.gleam
│   ├── views/
│   │   ├── user_view.gleam
│   │   ├── post_view.gleam
│   │   └── event_view.gleam
│   ├── controllers/
│   │   ├── users_controller.gleam
│   │   ├── posts_controller.gleam
│   │   └── events_controller.gleam
│   ├── operations/
│   │   ├── publish_post.gleam
│   │   ├── export_posts.gleam
│   │   └── enrich_events.gleam
│   └── middleware/
│       └── logging_middleware.gleam
```

### Makefile

```makefile
migrate-up:
	gleam run -m cigogne -- migrate up

migrate-down:
	gleam run -m cigogne -- migrate down
	psql postgresql://postgres:postgres@localhost:5435/cms_db -c "ALTER SEQUENCE cigogne_migrations_id_seq RESTART WITH 1;"

migrate-new:
	gleam run -m cigogne -- migrate create $(name)
```

### Clean Pattern Examples (No Anonymous Functions, No Nested Cases)

**operations/enrich_events.gleam:**

```gleam
pub fn execute(services: Services, limit: Int) -> Result(List(EnrichedEvent), DataError) {
  use events <- result.try(event.recent(services.opensearch, limit))
  Ok(enrich_all_events(events, services))
}

fn enrich_all_events(events: List(Event), services: Services) -> List(EnrichedEvent) {
  list.map(events, enrich_single_event(_, services))
}

fn enrich_single_event(evt: Event, services: Services) -> EnrichedEvent {
  EnrichedEvent(event: evt, user: load_user_if_present(evt, services))
}

fn load_user_if_present(evt: Event, services: Services) -> Option(User) {
  case evt.user_id {
    option.Some(id) -> user.get(services.db, id) |> result.to_option()
    option.None -> option.None
  }
}
```

**operations/export_posts.gleam:**

```gleam
pub fn execute(services: Services) -> Result(yielder.Yielder(BitArray), DataError) {
  use posts <- result.try(post.list(services.db))
  Ok(create_csv_stream(posts))
}

fn create_csv_stream(posts: List(Post)) -> yielder.Yielder(BitArray) {
  let header = "id,title,author_id,status\n"
  let rows = list.map(posts, post_to_csv)
  
  yielder.from_list([header, ..rows])
  |> yielder.map(string_to_bits)
}

fn post_to_csv(post: Post) -> String {
  int.to_string(post.id) <> "," <> post.title <> "," 
    <> int.to_string(post.author_id) <> "," 
    <> status_to_string(post.status) <> "\n"
}

fn string_to_bits(s: String) -> BitArray {
  <<s:utf8>>
}
```

**controllers/events_controller.gleam:**

```gleam
pub fn stream(_request: Request, _context: Context, services: Services) -> Response {
  let stream = create_event_stream(services)
  sse_response(ok_status(), stream, "text/event-stream")
}

fn create_event_stream(services: Services) -> yielder.Yielder(BitArray) {
  yielder.repeatedly(poll_events(_, services))
  |> yielder.flatten()
  |> yielder.map(string_to_bits)
}

fn poll_events(_: Nil, services: Services) -> List(String) {
  process.sleep(1000)
  fetch_and_format_events(services)
}

fn fetch_and_format_events(services: Services) -> List(String) {
  case event.recent(services.opensearch, 10) {
    Ok(events) -> format_all_events_as_sse(events)
    Error(_) -> []
  }
}

fn format_all_events_as_sse(events: List(Event)) -> List(String) {
  list.map(events, format_single_event_as_sse)
}

fn format_single_event_as_sse(evt: Event) -> String {
  "data: " <> event_view.to_json(evt) <> "\n\n"
}

fn string_to_bits(s: String) -> BitArray {
  <<s:utf8>>
}
```

**views/event_view.gleam:**

```gleam
pub fn to_json(event: Event) -> String {
  to_json_object(event)
  |> json.to_string()
}

pub fn list_to_json(events: List(Event)) -> String {
  events
  |> list.map(to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

fn to_json_object(event: Event) -> json.Json {
  json.object([
    #("id", json.string(event.id)),
    #("event_type", json.string(event_type_to_string(event.event_type))),
    #("method", json.string(event.method)),
    #("path", json.string(event.path)),
    #("status_code", json.int(event.status_code)),
  ])
}

fn identity(x) -> x {
  x
}
```

## Phase 4: Documentation

**docs/reference/architecture.md:**

Comprehensive MVC explanation with modules ecosystem.

**docs/guides/controllers-and-models.md:**

Updated patterns using dream_postgres, showing clean style.

## Success Criteria

1. Dream core minimal (no service code)
2. 6 modules as independent packages
3. All 8 examples work
4. CMS validates architecture with clean code (no anon functions, no nested cases)