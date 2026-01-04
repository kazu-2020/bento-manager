# Project Structure

## Organization Philosophy

Follows **Rails conventions** with modern frontend tooling integrated. Backend uses standard Rails MVC structure, frontend organized by feature with Stimulus controllers and Vite entrypoints.

## Directory Patterns

### Backend (Rails Standard)
**Location**: `/app/`
**Purpose**: Core application logic following Rails MVC
**Structure**:
- `controllers/` - HTTP request handling
- `models/` - Domain logic and ActiveRecord
- `views/` - ERB templates
- `jobs/` - Background jobs (Solid Queue)
- `mailers/` - Email templates and logic
- `helpers/` - View helpers

### Frontend (Vite + Hotwire)
**Location**: `/app/frontend/`
**Purpose**: Modern frontend assets with Vite build system
**Structure**:
- `entrypoints/` - Vite entry files (application.js)
- `controllers/` - Stimulus controllers (snake_case_controller.js)
- `stylesheets/` - CSS/Tailwind styles
- `images/` - Image assets

Example:
```javascript
// app/frontend/controllers/hello_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Controller logic
  }
}
```

### Configuration
**Location**: `/config/`
**Purpose**: Application and environment configuration
**Key Files**:
- `routes.rb` - URL routing
- `database.yml` - Multi-database setup (primary, cache, queue, cable)
- `application.rb` - Rails configuration
- `environments/` - Environment-specific settings

### Database
**Location**: `/db/`
**Purpose**: Schema, migrations, seeds
**Multi-DB Structure**:
- `schema.rb` - Primary database schema
- `cache_schema.rb` - Solid Cache schema
- `queue_schema.rb` - Solid Queue schema
- `cable_schema.rb` - Solid Cable schema
- `migrate/` - Primary migrations
- `cache_migrate/`, `queue_migrate/`, `cable_migrate/` - Database-specific migrations

### Assets (Legacy)
**Location**: `/app/assets/`
**Purpose**: Rails asset pipeline (minimal, Vite preferred)

## Naming Conventions

- **Controllers**: PascalCase classes, snake_case files (`home_controller.rb`)
- **Models**: PascalCase classes, singular snake_case files (`bento_item.rb`)
- **Views**: snake_case directories/files matching controller (`home/index.html.erb`)
- **Stimulus Controllers**: snake_case with `_controller.js` suffix
- **Routes**: RESTful resources with snake_case names

## Import Organization

### JavaScript (ES Modules)
```javascript
// External packages
import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Relative imports
import '../controllers'
```

### Ruby
```ruby
# Gems (managed by Bundler)
require "rails"

# Relative requires
require_relative "boot"
```

## Code Organization Principles

### Backend (Rails)
- **Fat Models, Skinny Controllers**: Business logic in models, controllers handle HTTP only
- **Service オブジェクトは絶対作成しない**: モデルを跨ぐ複雑な処理は `app/models` に適切なディレクトリ階層を構築して、PORO なクラスを使用して対応する
- **Concerns**: Share behavior via `/app/models/concerns/` and `/app/controllers/concerns/`

### Frontend (Hotwire)
- **Stimulus Controllers per Feature**: One controller per interactive component
- **Turbo Frames for Isolation**: Scope updates to page sections
- **Server-Side Rendering**: Prefer Turbo Streams over client-side templating
- **Progressive Enhancement**: Start with working HTML, enhance with Stimulus

### Testing
- **Location**: `/test/` (minitest convention)
- **Structure**: Mirrors `/app/` (controllers, models, integration, etc.)

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_
