<!-- 9cff2a91-19a4-4c13-a366-40ee66dbe439 285fe9bf-95fd-47b4-9422-f4242881800f -->
# Complete Websocket Implementation Plan

## Phase 1: Core Websocket Types

### 1.1 Create `src/dream/websocket.gleam`

Create the server-agnostic websocket abstraction module with complete documentation for hex docs.

**Module documentation:**

- Overview of websocket support in Dream
- When to use websockets vs HTTP streaming vs SSE
- Quick start example
- Explanation of Event messages for pub/sub

**Types to implement:**

- `Message(event)` - Incoming messages (Text, Binary, Ping, Pong, Close, Event)
- `Frame` - Outgoing frames (SendText, SendBinary, SendPing, SendPong, SendClose)
- `HandlerResult(state, event)` - Continue or Close with state and frames to send
- `Handler(state, services, event)` - Message handler function type
- `MessageMiddleware(state, services, event)` - Message middleware function type

**Functions to implement:**

- `continue(state)` - Continue with state, no messages
- `continue_with_text(state, text)` - Continue and send text
- `continue_with_binary(state, data)` - Continue and send binary
- `continue_with_frames(state, frames)` - Continue and send multiple frames
- `continue_with_selector(state, selector)` - Continue with new selector
- `continue_with_pong(state, data)` - Continue and respond to ping
- `close()` - Close connection with normal closure code
- `close_with_reason(code, reason)` - Close with specific code and reason

**Constants to define:**

- Standard websocket close codes (normal_closure, going_away, protocol_error, etc.)

**Documentation requirements:**

- Every type has comprehensive doc comments with examples
- Every function has doc comments with parameters, return values, and examples
- Examples show realistic chat room, pub/sub, and game scenarios
- Explain Event messages with concrete pub/sub example

### 1.2 Update `src/dream/router.gleam`

Add websocket route support to the router.

**New types:**

- `WebsocketInit(state, event)` - Initial state and selector for websocket connection

**Update Route type:**

- Add `WebsocketRoute` variant with all fields:
  - path
  - on_init function
  - handler function
  - on_close function
  - middleware (HTTP upgrade middleware)
  - message_middleware (per-message middleware)

**New function:**

- `websocket_route(router, path, on_init, handler, on_close, middleware, message_middleware)` 
- Full documentation explaining:
  - HTTP middleware runs once on upgrade (can reject)
  - Message middleware runs on each message
  - on_init can validate and authenticate
  - State is the websocket's context (not Dream context)

**Update find_route function:**

- Handle WebsocketRoute variant in pattern matching
- Extract path parameters for websocket routes

## Phase 2: Mist Adapter Implementation

### 2.1 Create `src/dream/servers/mist/websocket.gleam`

Internal adapter module that translates Dream websocket types to Mist's implementation.

**Functions to implement:**

`translate_incoming_message_from_mist(mist_message) -> dream_message`

- Convert mist.Text to websocket.Text
- Convert mist.Binary to websocket.Binary
- Convert mist.Ping to websocket.Ping
- Convert mist.Pong to websocket.Pong
- Convert mist.Closed to websocket.Close
- Convert mist.Custom to websocket.Event
- No nested cases - use helper functions for each conversion

`execute_outgoing_frames(frames, mist_connection) -> Result`

- Iterate over frames list
- Call appropriate mist send function for each frame
- SendText -> mist.send_text_frame
- SendBinary -> mist.send_binary_frame
- SendPing -> mist.send_ping_frame (if Mist supports)
- SendPong -> mist.send_pong_frame (if Mist supports)
- SendClose -> handled by mist.stop()
- No nested cases - use helper function per frame type

`build_message_middleware_chain(message_middleware_list, final_handler) -> wrapped_handler`

- Build middleware chain from list
- Each middleware wraps the next
- Final handler at the end
- Return single wrapped handler function

`upgrade_to_websocket(mist_request, dream_request, context, services, on_init, handler, on_close, http_middleware, message_middleware) -> mist_response`

- Run HTTP middleware on dream_request first (can reject upgrade)
- Call on_init with dream_request, context, services
- If on_init returns Error(response), convert response and return
- If on_init returns Ok(WebsocketInit), proceed with upgrade
- Wrap handler with message middleware chain
- Create adapter state that holds user state
- Call mist.websocket with translated functions
- Translate Dream HandlerResult back to Mist Next
- Handle Continue (send frames, update state, set selector)
- Handle Close (send final frames, stop)
- No anonymous functions except where Mist requires them

**Documentation:**

- Mark module as internal
- Document translation approach
- Document adapter state pattern

### 2.2 Update `src/dream/servers/mist/handler.gleam`

Update handler to recognize and process websocket routes.

**Update `handle_routed_request` function:**

- Add case for WebsocketRoute
- Extract WebsocketRoute fields
- Build HTTP middleware chain
- Run HTTP middleware (can reject upgrade before websocket starts)
- Call websocket.upgrade_to_websocket with all parameters
- Keep HttpRoute case unchanged
- No nested cases

## Phase 3: Comprehensive Example Application

### 3.1 Create `examples/websocket_chat/`

Structure:

```
examples/websocket_chat/
  src/
    main.gleam
    router.gleam
    services.gleam
    controllers/
      websocket_controller.gleam
      http_controller.gleam
    middleware/
      auth_middleware.gleam
      logging_middleware.gleam
      rate_limit_middleware.gleam
    models/
      chat_room.gleam
    views/
      chat_view.gleam
  test/
    integration/
      features/
        websocket.feature
      step_definitions/
        websocket_steps.exs
      test_helper.exs
      cucumber_test.exs
  gleam.toml
  manifest.toml
  mix.exs
  mix.lock
  Makefile
  README.md
```

### 3.2 Implement Chat Room Application

**services.gleam:**

- Services type with database connection and chat_rooms Subject registry
- initialize_services() function
- Chat room registry using process Subjects for pub/sub

**models/chat_room.gleam:**

- ChatState type (room_id, user_id, username, room_subject, message_count)
- ChatEvent type (UserJoined, UserLeft, NewMessage, RoomClosed)
- get_or_create_room_subject(registry, room_id) function
- broadcast_to_room(room_subject, event) function

**controllers/websocket_controller.gleam:**

`chat_room_init(request, context, services) -> Result(WebsocketInit, Response)`

- Extract room_id from path parameters
- Validate room_id
- Get authenticated user from context
- If not authenticated, return 401 Response
- Get or create room Subject from registry
- Create selector for room Subject
- Broadcast UserJoined event
- Create ChatState with room_id, user_id, room_subject, message_count
- Return Ok(WebsocketInit(state, selector))
- No nested cases - use helper functions

`chat_room_handler(state, message, services) -> HandlerResult`

- Handle websocket.Text: save message, broadcast NewMessage event
- Handle websocket.Event(NewMessage): format and send to client
- Handle websocket.Event(UserJoined): send join notification
- Handle websocket.Event(UserLeft): send leave notification  
- Handle websocket.Ping: respond with Pong
- Handle websocket.Close: return close
- Handle websocket.Binary: ignore or log
- Handle websocket.Pong: ignore
- No nested cases - each message type has its own helper function

`chat_room_close(state, services) -> Nil`

- Broadcast UserLeft event to room
- Log disconnect with message_count
- Clean up any resources

**Helper functions (no nested cases):**

- `handle_client_text_message(state, text, services) -> HandlerResult`
- `handle_new_message_event(state, user, text) -> HandlerResult`
- `handle_user_joined_event(state, username) -> HandlerResult`
- `handle_user_left_event(state, username) -> HandlerResult`
- `format_chat_message_json(user, text) -> String`
- `format_user_event_json(event_type, username) -> String`

**controllers/http_controller.gleam:**

- index_controller: serve HTML page with websocket client
- rooms_list_controller: list active chat rooms

**middleware/logging_middleware.gleam:**

`log_websocket_message_middleware(state, message, services, next) -> HandlerResult`

- Log incoming message type and state
- Call next(state, message, services)
- Log outgoing frames from result
- Return result unchanged
- No nested cases

**middleware/rate_limit_middleware.gleam:**

`rate_limit_middleware(state, message, services, next) -> HandlerResult`

- Check if message is Text or Binary (client messages)
- If not, call next immediately
- If yes, check state.message_count
- If over limit, return websocket.close_with_reason(policy_violation, "Rate limit exceeded")
- If under limit, call next
- No nested cases - use helper to check rate limit

**views/chat_view.gleam:**

- HTML page with websocket client JavaScript
- Connect to websocket
- Send messages
- Display incoming messages
- Show user join/leave events
- Handle ping/pong for keepalive
- Show connection status

**main.gleam:**

- Initialize services with chat room registry
- Create router with HTTP and websocket routes
- Start server on port 3000

**router.gleam:**

- GET "/" -> serve chat HTML page
- GET "/rooms" -> list active rooms
- websocket_route "/chat/:room_id" with:
  - on_init: chat_room_init
  - handler: chat_room_handler
  - on_close: chat_room_close
  - middleware: [auth_middleware, logging_middleware]
  - message_middleware: [rate_limit_middleware, logging_middleware]

**README.md:**

- Overview of chat application
- Features demonstrated (pub/sub, middleware, ping/pong, rate limiting)
- How to run
- How to test with multiple clients
- Code walkthrough

### 3.3 Example Makefile

```makefile
.PHONY: run test test-integration clean

run:
	@gleam run -m main

test:
	@gleam test

test-integration:
	# Start server, run cucumber tests, stop server
	# Similar to streaming example Makefile
```

## Phase 4: Unit Tests

### 4.1 Create `test/dream/websocket_test.gleam`

Test all helper functions and types:

- `continue_with_text_creates_correct_result_test()`
- `continue_with_binary_creates_correct_result_test()`
- `continue_with_frames_creates_correct_result_test()`
- `continue_with_pong_responds_to_ping_test()`
- `close_uses_normal_closure_code_test()`
- `close_with_reason_uses_custom_code_test()`
- All close code constants are correct values

### 4.2 Create `test/dream/router/websocket_test.gleam`

Test websocket routing:

- `websocket_route_adds_route_to_router_test()`
- `websocket_route_matches_correct_path_test()`
- `websocket_route_extracts_path_parameters_test()`
- `websocket_route_with_middleware_runs_middleware_test()`
- `websocket_route_with_message_middleware_stores_middleware_test()`
- `find_route_matches_websocket_route_test()`
- `find_route_returns_websocket_route_with_params_test()`

### 4.3 Create `test/dream/servers/mist/websocket_test.gleam`

Test Mist adapter:

- `translate_incoming_message_text_from_mist_test()`
- `translate_incoming_message_binary_from_mist_test()`
- `translate_incoming_message_ping_from_mist_test()`
- `translate_incoming_message_pong_from_mist_test()`
- `translate_incoming_message_close_from_mist_test()`
- `translate_incoming_message_event_from_mist_test()`
- `execute_outgoing_frames_sends_text_test()`
- `execute_outgoing_frames_sends_binary_test()`
- `execute_outgoing_frames_sends_multiple_frames_test()`
- `build_message_middleware_chain_wraps_handler_test()`
- `build_message_middleware_chain_executes_in_order_test()`

## Phase 5: Integration Tests

### 5.1 Create Cucumber Feature File

`examples/websocket_chat/test/integration/features/websocket.feature`

**Scenarios to test:**

Connection and Basic Protocol:

- Connect to websocket endpoint successfully
- Send text message and receive echo
- Send binary message and receive echo
- Send ping and receive pong
- Close connection gracefully
- Reject connection with invalid room ID
- Reject connection without authentication

Chat Room Features:

- Join chat room and receive welcome message
- Send message and receive it back
- Multiple clients in same room receive messages
- User join event sent to all clients in room
- User leave event sent when client disconnects
- Switch rooms and receive messages from new room

Middleware:

- HTTP middleware rejects unauthenticated websocket upgrade
- Message middleware logs all messages
- Rate limit middleware blocks after 100 messages
- Rate limit middleware allows messages under limit

Error Cases:

- Invalid message format handled gracefully
- Server shutdown closes connections cleanly
- Network disconnect handled correctly

### 5.2 Create Step Definitions

`examples/websocket_chat/test/integration/step_definitions/websocket_steps.exs`

Implement step definitions for:

- Starting websocket connections
- Sending websocket messages
- Receiving websocket messages
- Asserting on message content
- Managing multiple clients
- Checking connection state

Use Elixir websocket client library for testing.

### 5.3 Create Test Helper

`examples/websocket_chat/test/integration/test_helper.exs`

Helper functions:

- Start test server on port 3000
- Create websocket client
- Connect to websocket
- Send messages
- Receive messages with timeout
- Close connection
- Clean up after tests

## Phase 6: Documentation

### 6.1 Module Documentation

Each module needs:

- Overview paragraph (what it does)
- When to use it section
- Quick examples section
- Detailed usage section (for complex modules)

Modules to document:

- `dream/websocket.gleam` (core types and functions)
- `dream/router.gleam` (websocket_route function)
- All example application modules

### 6.2 Type Documentation

Every type needs:

- Purpose description
- Field explanations
- Usage examples
- Related types

Types to document:

- Message(event)
- Frame
- HandlerResult(state, event)
- Handler(state, services, event)
- MessageMiddleware(state, services, event)
- WebsocketInit(state, event)

### 6.3 Function Documentation

Every function needs:

- Purpose description
- Parameter descriptions
- Return value description
- At least one example
- Related functions

All public functions in websocket.gleam and router.gleam.

### 6.4 Example Documentation

Examples need:

- README.md with overview
- Inline code comments explaining key concepts
- Architecture documentation (how components interact)
- How to run and test

### 6.5 Guide Documentation

Create `docs/guides/websockets.md`:

- Introduction to websockets in Dream
- When to use websockets vs streaming vs SSE
- Basic websocket route setup
- Handling different message types
- Using Event messages for pub/sub
- Message middleware patterns
- Testing websockets
- Production considerations
- Common patterns and recipes

## Implementation Notes

**Code Style Requirements:**

- NO ABBREVIATIONS in variable names, function names, or types
- NO NESTED CASES - extract to helper functions
- NO ANONYMOUS FUNCTIONS except where Mist API requires them
- Use descriptive names (chat_room_handler not chat_handler)
- Use helper functions for each case branch
- Clear separation of concerns

**Testing Strategy:**

- Unit tests for pure functions
- Integration tests for full scenarios
- Test error cases
- Test middleware execution order
- Test multiple concurrent clients
- Test all protocol features (ping/pong, close codes)

**Documentation Standards:**

- Complete hex docs on all public APIs
- Examples in every function doc
- Real-world scenarios in module docs
- Architecture explanations in guides
- No assumed knowledge - explain everything

## File Creation Order

1. Core types: `src/dream/websocket.gleam`
2. Router updates: `src/dream/router.gleam`
3. Mist adapter: `src/dream/servers/mist/websocket.gleam`
4. Handler updates: `src/dream/servers/mist/handler.gleam`
5. Example services: `examples/websocket_chat/src/services.gleam`
6. Example models: `examples/websocket_chat/src/models/chat_room.gleam`
7. Example middleware: `examples/websocket_chat/src/middleware/*.gleam`
8. Example controller: `examples/websocket_chat/src/controllers/websocket_controller.gleam`
9. Example views: `examples/websocket_chat/src/views/chat_view.gleam`
10. Example router: `examples/websocket_chat/src/router.gleam`
11. Example main: `examples/websocket_chat/src/main.gleam`
12. Unit tests: `test/dream/websocket_test.gleam`
13. Router tests: `test/dream/router/websocket_test.gleam`
14. Adapter tests: `test/dream/servers/mist/websocket_test.gleam`
15. Integration tests: `examples/websocket_chat/test/integration/*`
16. Documentation: `docs/guides/websockets.md`
17. Example README: `examples/websocket_chat/README.md`