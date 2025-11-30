<!-- ac3d9475-6a02-4c3d-9745-0ccf4f4d5479 1a8a8649-afbf-402e-8ed9-3bad5261b3bf -->
# Trustbound to Dream Feature Gap Analysis & Implementation Plan

## Current State Analysis

**TrustBound Application** is a full-featured web application with:

- Multi-tenant SaaS architecture with organization/team management
- AWS Cognito authentication with JWT validation
- HTML templating using Matcha (via Cigogne)
- Static file serving (CSS, JS, images)
- Cookie-based session management
- Role-based authorization (Public, Authenticated, OrganizationOwner, OrganizationMember, Admin)
- Database migrations with PostgreSQL
- External service integrations (Cognito, SES, Stripe)
- Telemetry and structured logging
- HTMX-powered interactive UI

**Dream Framework** currently provides:

- Basic routing with path parameters
- Middleware system
- PostgreSQL support via Pog/Squirrel
- JSON validation
- HTTP client with streaming
- Simple response builders

## Critical Missing Features

### 1. HTML Templating System (CRITICAL)

**Gap**: Dream has no HTML templating. TrustBound uses Matcha templates (.matcha files) compiled via Cigogne.

**Files to reference**:

- `/Users/dcrockwell/Documents/Code/FileStory/trustbound/client/src/layouts/main_layout.matcha`
- `/Users/dcrockwell/Documents/Code/FileStory/trustbound/client/src/pages/dashboard.matcha`

**Implementation needed**:

- Add Cigogne as dependency to dream
- Create `dream/services/templates` module for template rendering
- Support passing data to templates
- Template helper functions for common patterns
- Flash message system (success/error/info)

### 2. Static File Serving (CRITICAL)

**Gap**: No static file serving utilities.

**Reference**: `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/src/utilities/http/http_static_file_handler.gleam`

**Implementation needed**:

- Add `dream/utilities/http/static.gleam` module
- Support content-type detection by extension
- Cache-Control headers
- 404 handling for missing files
- Security: prevent directory traversal

### 3. Cookie Management (CRITICAL)

**Gap**: No cookie utilities.

**Reference**: `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/src/utilities/http/http_cookie_manager.gleam`

**Implementation needed**:

- Add `dream/utilities/http/cookies.gleam` module
- Set cookies with all attributes (HttpOnly, Secure, SameSite, Domain, Max-Age, Path)
- Read cookies from request headers
- Clear cookies
- Support multiple Set-Cookie headers

### 4. Authentication & Authorization System (CRITICAL)

**Gap**: No auth system. TrustBound has sophisticated JWT + role-based auth.

**Reference**: `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/src/utilities/http/http_router.gleam` (lines 60-141)

**Implementation needed**:

- Add `dream/utilities/auth` module with:
  - JWT validation (using existing Gleam JWT libraries)
  - JWKS caching
  - Authorization levels/roles
  - Extract auth from headers and cookies
  - Permission checking
- Integrate with router for route-level auth requirements
- Add auth context to request handling

### 5. Configuration Management (HIGH PRIORITY)

**Gap**: No config loading utilities.

**Reference**: `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/src/config.gleam`

**Implementation needed**:

- Add `dream/utilities/config.gleam` module
- Environment variable extraction with defaults
- Required vs optional configs
- Type conversions (string to int, bool)
- Validation (e.g., cookie domain format)

### 6. Enhanced Request/Response Utilities (HIGH PRIORITY)

**Gaps**:

- No form data parsing (TrustBound has URL-encoded form parsing)
- No request details extraction pattern (to prevent body re-reading)
- Limited response builders (no HTML, no streaming SSE)

**References**:

- `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/src/types/http_types.gleam` (RequestDetails type)
- `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/src/utilities/http/http_response_builder.gleam`

**Implementation needed**:

- Add `dream/utilities/http/forms.gleam` for form parsing
- Add RequestDetails pattern to extract request once
- Enhance response builders:
  - HTML responses with status codes
  - SSE streaming responses
  - Error response templates (401, 403, 404, 500)
  - HTMX-specific headers (HX-Redirect, HX-Retarget, HX-Reswap)

### 7. Enhanced Router Features (MEDIUM PRIORITY)

**Gaps**:

- No built-in way to handle multiple HTTP methods per path
- Path params returned as list, not dict
- No auth requirement per route

**Reference**: `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/src/router.gleam`

**Implementation needed**:

- Return path params as `Dict(String, String)` instead of list
- Add `route_multi` function for multiple methods on same path
- Integrate auth requirements into route definitions
- Route groups with shared middleware/auth

### 8. Migration System (MEDIUM PRIORITY)

**Gap**: No migration runner.

**Reference**: `/Users/dcrockwell/Documents/Code/FileStory/trustbound/server/priv/migrations/`

**Implementation needed**:

- Add `dream/utilities/database/migrations.gleam`
- Migration file format (timestamp-based naming)
- Up/down migration support
- Migration tracking table
- CLI helper or Makefile targets

### 9. Logging/Telemetry (OPTIONAL - Can be external)

**Gap**: No structured logging. TrustBound has extensive telemetry.

**Note**: This could remain application-specific rather than framework feature.

### 10. Error Page Templates (LOW PRIORITY)

**Gap**: No default error pages.

**Implementation needed**:

- Add default HTML templates for common errors
- Allow customization via templates
- Flash message system for user feedback

## Dependencies to Add

```toml
# Add to dream/gleam.toml
cigogne = ">= 5.0.0 and < 6.0.0"  # For Matcha templates
simplifile = ">= 2.2.1 and < 3.0.0"  # For static files
envoy = ">= 1.0.2 and < 2.0.0"  # For environment variables
gleam_crypto = ">= 1.5.0 and < 2.0.0"  # For JWT/auth
birl = ">= 1.8.0 and < 2.0.0"  # For timestamps
```

## Recommended Implementation Priority

**Phase 1 (Blocking - Cannot port without these)**:

1. HTML templating integration (Cigogne/Matcha)
2. Static file serving
3. Cookie management
4. Form data parsing

**Phase 2 (High Value - Needed for auth)**:

5. JWT validation utilities
6. Authorization system
7. Configuration management
8. Enhanced response builders

**Phase 3 (Polish - Can work around temporarily)**:

9. Router enhancements (dict params, route groups)
10. Migration system
11. Default error pages
12. Telemetry helpers

## Alternative Approaches

**Option 1**: Keep trustbound-specific code in trustbound

- Only add truly generic/reusable features to dream
- External services (Cognito, Stripe, SES) stay in trustbound/adapters
- Organization/team logic stays in trustbound
- Dream focuses on HTTP/templating/cookies/auth primitives

**Option 2**: Full framework approach

- Move more batteries into dream
- Create dream/services/auth with Cognito adapter
- Create dream/services/email
- Risk: dream becomes opinionated/bloated

**Recommendation**: Option 1. Keep dream lightweight and composable. Add primitives (cookies, templates, JWT validation) but not integrations (Cognito client, Stripe client).

## Files That Can Stay in Trustbound

These are application-specific and should NOT move to dream:

- All `/adapters/` (Cognito, SES, Stripe, OpenAI, BAML)
- All `/orchestrators/` (business logic)
- All `/processors/` (domain logic)
- All `/types/*_types.gleam` except generic HTTP types
- All `/queries/sql/` (database queries)
- Client templates in `/client/src/pages/` (app-specific pages)

## Success Criteria

Dream successfully supports trustbound when:

1. Can serve HTML pages using Matcha templates
2. Can serve static CSS/JS/images
3. Can set/read/clear cookies with all security attributes
4. Can validate JWTs and enforce route-level authorization
5. Can parse form data from POST requests
6. Can load configuration from environment variables
7. Can handle multiple HTTP methods per path elegantly

## Next Steps

1. Clarify with user: Should dream be minimal (just add primitives) or more complete (include service adapters)?
2. Confirm priority order above aligns with porting needs
3. Start with Phase 1 implementation
4. Create example showing trustbound-style auth in dream
5. Document migration path from trustbound patterns to dream patterns

### To-dos

- [ ] Integrate Cigogne/Matcha templating system into dream with render utilities and flash message support
- [ ] Add static file serving module with content-type detection and security
- [ ] Create cookie utilities for setting/reading/clearing with all security attributes
- [ ] Add URL-encoded form data parsing utility
- [ ] Add JWT validation and JWKS caching utilities
- [ ] Create authorization system with role-based access control
- [ ] Add configuration loading from environment with validation
- [ ] Enhance response builders with HTML, SSE streaming, and HTMX headers
- [ ] Update router to use Dict for params, support route groups, and integrate auth requirements
- [ ] Create database migration system with timestamp-based files
- [ ] Add default error page templates (401, 403, 404, 500)