# Git Submodule Management

## 🎯 TL;DR - Just Tell Me What to Run

```bash
# Most common: Update everything
make submodule-refresh

# Check what's happening
make submodule-status

# First time setup
make submodule-init
```

---

## 📋 Available Commands

| Command | Use Case |
|---------|----------|
| `make submodule-refresh` | **Daily use** - Pull latest changes |
| `make submodule-status` | Check current state |
| `make frontend-submodule-update` | Update frontend only |
| `make submodule-init` | First-time initialization |
| `make submodule-update` | Update to latest from remote |
| `make submodule-pull` | Pull from main branch |
| `make submodule-clean` | Remove untracked files |
| `make submodule-reset` | Fix broken state |
| `make submodule-sync` | Sync URLs after changes |

---

## 🚀 Common Workflows

### First Time Setup
```bash
# Option 1: Clone with submodules
git clone --recurse-submodules <repo-url>

# Option 2: Already cloned? Initialize now
make submodule-init

# Or just run setup (does everything)
make setup
```

### Daily Development
```bash
# Pull latest from main repo
git pull origin main

# Update submodules
make submodule-refresh

# Start development
make up
```

### Update Frontend Only
```bash
make frontend-submodule-update
make up-build
```

### Check Status
```bash
make submodule-status
```

Output example:
```
Git submodule status:
+734ca32 frontend/ai-front (v0.2.0-1-g734ca32)

Frontend submodule details:
origin  https://github.com/nicolaslallier/AI_Front.git (fetch)
origin  https://github.com/nicolaslallier/AI_Front.git (push)

734ca32 feat: implement Keycloak OIDC authentication
```

### Fix Broken Submodule
```bash
make submodule-clean    # Clean untracked files
make submodule-reset    # Reset to clean state
make submodule-refresh  # Update to latest
```

---

## 🔍 Understanding Status Symbols

| Symbol | Meaning | Action |
|--------|---------|--------|
| (none) | ✅ Correct commit | None needed |
| `+` | ⚠️ Different commit | `make submodule-refresh` |
| `-` | ❌ Not initialized | `make submodule-init` |
| `U` | ❌ Merge conflicts | Manual resolution needed |

---

## 📚 Documentation

### Quick Reference
**File**: `SUBMODULE_QUICK_REFERENCE.md`
- One-page cheat sheet
- Decision tree
- Common commands

### Comprehensive Guide
**File**: `../AI/DOCS/AI_Infra/GIT_SUBMODULE_GUIDE.md`
- Complete documentation
- Detailed examples
- Troubleshooting
- Best practices
- Advanced usage

### Implementation Details
**File**: `GIT_SUBMODULE_IMPLEMENTATION.md`
- Technical implementation
- Design decisions
- Testing performed
- Validation checklist

---

## 🐛 Troubleshooting

### Problem: Empty submodule directory
```bash
make submodule-init
```

### Problem: Submodule shows as "modified"
```bash
make submodule-refresh
```

### Problem: Can't pull changes
```bash
cd frontend/ai-front
git status              # Check for uncommitted changes
git stash              # Stash if needed
cd ../..
make submodule-refresh
```

### Problem: Completely broken
```bash
make submodule-reset
make submodule-refresh
```

---

## ⚡ Quick Command Reference

```bash
# See all commands
make help | grep submodule

# Initialize (first time)
make submodule-init

# Update (most common)
make submodule-refresh

# Check status
make submodule-status

# Update frontend only
make frontend-submodule-update

# Clean up
make submodule-clean

# Full reset
make submodule-reset

# Sync URLs
make submodule-sync

# Pull from main
make submodule-pull
```

---

## 🔗 Integration

### Makefile Setup Target
The `make setup` command automatically initializes submodules:
```bash
make setup  # Includes submodule initialization
```

### CI/CD Integration
In CI/CD pipelines:
```yaml
steps:
  - name: Checkout with submodules
    run: git clone --recurse-submodules <repo>
    
  # OR
  
  - name: Initialize submodules
    run: make submodule-init
```

---

## 💡 Best Practices

### ✅ DO
- Run `make submodule-refresh` regularly
- Check status before committing
- Commit submodule updates separately
- Use descriptive commit messages

### ❌ DON'T
- Don't ignore submodule updates
- Don't make changes directly in submodule (without proper workflow)
- Don't delete submodule directories manually
- Don't commit dirty submodules

---

## 🎯 When to Use Which Command

```
┌─ What do you need to do?
│
├─ First time?
│  └─► make submodule-init
│
├─ Regular update?
│  └─► make submodule-refresh
│
├─ Only frontend?
│  └─► make frontend-submodule-update
│
├─ Check status?
│  └─► make submodule-status
│
├─ Something broken?
│  └─► make submodule-reset
│
└─ URL changed?
   └─► make submodule-sync
```

---

## 📞 Need Help?

1. **Quick help**: `make help | grep submodule`
2. **Quick reference**: See `SUBMODULE_QUICK_REFERENCE.md`
3. **Full guide**: See `../AI/DOCS/AI_Infra/GIT_SUBMODULE_GUIDE.md`
4. **This file**: Basic overview and quick reference

---

## 🔄 Commit Workflow

When you update a submodule:

```bash
# Update the submodule
make frontend-submodule-update

# Check what changed
git status
# Shows: modified:   frontend/ai-front (new commits)

# Stage and commit the reference
git add frontend/ai-front
git commit -m "chore: update frontend submodule to latest version"

# Or with more detail
git commit -m "chore: update frontend submodule

- Updated to commit 734ca32
- Includes Keycloak OIDC authentication
- Includes new dashboard components"

# Push
git push origin main
```

---

## 📊 Summary

| What | Command |
|------|---------|
| **Most common** | `make submodule-refresh` |
| **Check status** | `make submodule-status` |
| **First time** | `make submodule-init` |
| **Frontend only** | `make frontend-submodule-update` |
| **Fix issues** | `make submodule-reset` |

---

**Remember**: When in doubt, run `make submodule-refresh` - it's safe and updates everything!

---

## 📝 Related Commands

```bash
# Frontend management
make frontend-build       # Build frontend Docker image
make frontend-dev         # Run frontend in dev mode
make frontend-logs        # Show frontend logs
make frontend-test        # Run frontend tests
make frontend-validate    # Validate frontend code

# Infrastructure
make setup               # Initial setup (includes submodule init)
make up                  # Start all services
make ps                  # Check service status
make logs                # View logs
```

---

**Status**: ✅ Ready to use

**Created**: December 6, 2025

**Last Updated**: December 6, 2025

