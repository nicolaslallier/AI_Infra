# Multi-stage Dockerfile for Node.js Service
# Optimized for both development and production

# ============================================
# Base stage - Common setup
# ============================================
FROM node:20-alpine as base

# Set working directory
WORKDIR /app

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
# Note: Alpine might have default groups, so we create group first then add user
RUN addgroup -S appuser && \
    adduser -S -G appuser appuser

# ============================================
# Dependencies stage - Install packages
# ============================================
FROM base as dependencies

# Copy package files
COPY package*.json ./

# Install production dependencies
# Use npm install instead of npm ci since package-lock.json may not exist yet
RUN npm install --only=production && \
    npm cache clean --force

# ============================================
# Development dependencies stage
# ============================================
FROM base as dev-dependencies

# Copy package files
COPY package*.json ./

# Install all dependencies (including dev)
# Use npm install instead of npm ci since package-lock.json may not exist yet
RUN npm install && \
    npm cache clean --force

# ============================================
# Development stage
# ============================================
FROM base as development

# Install additional tools for development
RUN apk add --no-cache curl

# Copy all dependencies
COPY --from=dev-dependencies /app/node_modules /app/node_modules

# Copy package files
COPY package*.json ./

# Copy application code
COPY . .

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Development command with hot-reload
CMD ["npm", "run", "dev"]

# ============================================
# Build stage - TypeScript compilation
# ============================================
FROM dev-dependencies as build

# Copy application code
COPY . .

# Build TypeScript
RUN npm run build

# ============================================
# Production stage
# ============================================
FROM base as production

# Install curl for health checks
RUN apk add --no-cache curl

# Copy production dependencies
COPY --from=dependencies /app/node_modules /app/node_modules

# Copy package files
COPY package*.json ./

# Copy built application from build stage
COPY --from=build /app/dist /app/dist

# Set ownership
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Production command
CMD ["node", "dist/main.js"]

