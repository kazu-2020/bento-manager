# Technology Stack

## Architecture

Full-stack Rails application with Hotwire for SPA-like interactivity without heavy JavaScript. Vite-powered frontend build system for modern asset management.

## Core Technologies

- **Language**: Ruby 3.x
- **Framework**: Rails 8.1.1
- **Runtime**: Ruby with Puma web server
- **Database**: SQLite3 (development), multi-database setup (primary, cache, queue, cable)
- **Frontend Build**: Vite 7.3.0 with vite-plugin-ruby

## Key Libraries

### Backend
- **Hotwire**: Turbo Rails (SPA navigation) + Stimulus (lightweight JS framework)
- **Solid Suite**: solid_cache, solid_queue, solid_cable (database-backed infrastructure)
- **Active Storage**: image_processing for media handling
- **Kamal**: Docker-based deployment
- **Thruster**: HTTP asset caching and compression

### Frontend
- **Stimulus**: @hotwired/stimulus 3.2.2 (JavaScript framework)
- **Turbo**: @hotwired/turbo-rails 8.0.20 (SPA acceleration)
- **Tailwind CSS**: 4.1.18 (utility-first styling)
- **Vite Plugins**: Full reload, Stimulus HMR for development experience

## Development Standards

### Code Quality
- **RuboCop**: Rails Omakase style guide
- **Security**: Brakeman (static analysis), bundler-audit (gem vulnerabilities)
- **Testing**: Rails test unit (minitest)

### Frontend Standards
- **ES Modules**: Modern JavaScript with Vite bundling
- **Stimulus Controllers**: Organize frontend behavior by feature
- **Turbo Frames/Streams**: Server-driven UI updates

## Development Environment

### Required Tools
- Ruby 3.x
- Node.js (for Vite and frontend dependencies)
- SQLite3

### Common Commands
```bash
# Dev server: Rails + Vite dev server with HMR
bin/dev

# Console
bin/rails console

# Database
bin/rails db:migrate
bin/rails db:seed

# Tests
bin/rails test

# Lint
bin/rubocop

# Security checks
bin/brakeman
bundle exec bundler-audit
```

## Key Technical Decisions

### Hotwire Over Heavy JavaScript Framework
Use Turbo + Stimulus instead of React/Vue for faster development and reduced complexity while maintaining modern UX.

### Vite for Asset Pipeline
Replace traditional Webpacker/Sprockets with Vite for faster builds, better DX (HMR), and modern JavaScript tooling.

### Solid Gems Strategy
Use database-backed Solid Cache/Queue/Cable instead of Redis/Sidekiq to simplify infrastructure and reduce operational complexity.

### Multi-Database SQLite Setup
Separate databases for primary, cache, queue, and cable to optimize performance and isolation while using SQLite.

### Tailwind CSS v4
Leverage Vite integration for utility-first styling with latest Tailwind features.

---
_Document standards and patterns, not every dependency_
