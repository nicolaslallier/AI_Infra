# Frontend Integration

This directory contains the AI_Front Vue.js Single Page Application integrated as a Git submodule.

## Overview

The frontend is a production-ready Vue 3 application with TypeScript, featuring:

- **Framework**: Vue 3 with Composition API
- **Language**: TypeScript with strict mode
- **Styling**: Tailwind CSS utility-first framework
- **State Management**: Pinia stores
- **Routing**: Vue Router with SPA support
- **Build Tool**: Vite for fast development and optimized production builds
- **Testing**: Vitest (unit/component) + Playwright (E2E)
- **Code Quality**: ESLint, Prettier, Husky pre-commit hooks

## Repository Structure

The frontend is managed as a Git submodule:

```
frontend/
├── ai-front/              # Git submodule (AI_Front repository)
│   ├── src/              # Vue.js source code
│   ├── Dockerfile        # Multi-stage production build
│   ├── nginx.conf        # Nginx configuration for serving
│   └── package.json      # Dependencies and scripts
└── README.md             # This file
```

## Integration with Infrastructure

### Docker Service

The frontend runs as a Docker service defined in the main `docker-compose.yml`:

- **Service Name**: `frontend`
- **Build Context**: `./frontend/ai-front`
- **Internal Port**: 80
- **Networks**: `frontend-net`, `monitoring-net`
- **Health Check**: `http://localhost:80/health`

### Nginx Routing

The main nginx reverse proxy routes requests:

- **Root Path** (`/`): Frontend application
- **Monitoring** (`/monitoring/*`): Observability services (Grafana, Prometheus, Tempo, Loki)

### Access

Once the infrastructure is running:

- **Frontend**: http://localhost/
- **Monitoring Dashboard**: http://localhost/monitoring/grafana/

## Working with the Submodule

### Initial Setup

The submodule is automatically initialized when you clone the infrastructure repository. If needed, you can manually initialize:

```bash
git submodule update --init --recursive
```

### Updating Frontend Code

To pull the latest changes from the frontend repository:

```bash
# Using the helper script
./scripts/update-frontend.sh

# Or manually
cd frontend/ai-front
git pull origin main
cd ../..
git add frontend/ai-front
git commit -m "chore: update frontend submodule"
```

### Development Workflow

#### Option 1: Full Stack Development

Run the entire infrastructure including the frontend:

```bash
make up
# or
./scripts/start.sh
```

The frontend will be built and served through nginx at http://localhost/

#### Option 2: Frontend-Only Development

For faster iteration with hot-reload:

```bash
# Start frontend in development mode
make frontend-dev

# Or manually
cd frontend/ai-front
npm install
npm run dev
# Access at http://localhost:3000 (Vite dev server)
```

#### Option 3: Hybrid Development

Run backend services with infrastructure, but develop frontend locally:

```bash
# Terminal 1: Start infrastructure (without rebuilding frontend)
make up

# Terminal 2: Run frontend with hot-reload
cd frontend/ai-front
npm run dev
```

### Building Frontend

To rebuild the frontend Docker image:

```bash
# Using Makefile
make frontend-build

# Or manually
docker-compose build frontend
```

### Testing

Run frontend tests:

```bash
cd frontend/ai-front

# Unit tests
npm run test

# Unit tests with coverage
npm run test:coverage

# E2E tests
npm run test:e2e

# Linting and formatting
npm run validate
```

## Customization

### Environment Variables

Frontend-specific environment variables can be set in `.env`:

```bash
FRONTEND_PORT=80  # Internal container port
NGINX_PORT=80     # External access port
```

### Build-Time Configuration

To pass build-time configuration to the frontend:

1. Add variables to `frontend/ai-front/.env` or `.env.production`
2. Rebuild the frontend service: `make frontend-build`

### Nginx Configuration

The frontend's internal nginx configuration is in `frontend/ai-front/nginx.conf`. It handles:

- SPA routing (fallback to index.html)
- Static asset caching
- Security headers
- Health check endpoint

## Troubleshooting

### Submodule Not Initialized

```bash
git submodule update --init --recursive
```

### Frontend Not Building

```bash
# Check submodule status
git submodule status

# Pull latest changes
cd frontend/ai-front
git pull origin main

# Rebuild
cd ../..
docker-compose build frontend
```

### Port Conflicts

If port 80 is already in use:

```bash
# Change NGINX_PORT in .env
echo "NGINX_PORT=8080" >> .env

# Restart services
docker-compose restart nginx
```

### Frontend Not Loading

1. Check service health:
   ```bash
   docker-compose ps frontend
   docker-compose logs frontend
   ```

2. Verify nginx routing:
   ```bash
   docker-compose logs nginx
   ```

3. Test direct access to frontend container:
   ```bash
   docker-compose exec frontend wget -O- http://localhost/health
   ```

## Deployment

### Production Build

The production build is optimized with:

- **Multi-stage Docker build**: Minimized image size
- **Code splitting**: Lazy-loaded routes and components
- **Asset optimization**: Minified JS/CSS, compressed images
- **Caching**: Long-term caching for static assets (1 year)
- **Tree shaking**: Unused code elimination

### CI/CD

The frontend is built and deployed as part of the infrastructure pipeline:

```bash
# CI/CD pipeline includes:
make ci-test          # Run tests
make frontend-build   # Build production image
make ci-deploy-prod   # Deploy to production
```

## Documentation

For detailed frontend documentation, see:

- [Frontend README](ai-front/README.md) - Frontend project documentation
- [Getting Started](ai-front/GETTING_STARTED.md) - Development setup
- [Coding Standards](ai-front/docs/CODING_STANDARDS.md) - Code conventions
- [Testing Guide](ai-front/docs/TESTING.md) - Testing strategies
- [Architecture](ai-front/docs/ARCHITECTURE.md) - Frontend architecture

## Contributing

When making changes to the frontend:

1. Work in the `frontend/ai-front` directory
2. Follow the coding standards defined in `.cursorrules`
3. Write tests for new features (90%+ coverage required)
4. Run validation before committing: `npm run validate`
5. Update the submodule reference in the main infrastructure repo

## Support

For frontend-specific issues:

1. Check frontend logs: `docker-compose logs frontend`
2. Review frontend documentation: `frontend/ai-front/README.md`
3. Test locally: `cd frontend/ai-front && npm run dev`

For infrastructure integration issues:

1. Check nginx logs: `docker-compose logs nginx`
2. Verify service health: `docker-compose ps`
3. Review main infrastructure docs: `../README.md`

