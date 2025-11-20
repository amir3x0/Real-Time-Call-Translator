# Git Instructions - Real-Time Call Translator

## 📋 Table of Contents
- [Initial Setup](#initial-setup)
- [Daily Workflow](#daily-workflow)
- [Branch Strategy](#branch-strategy)
- [Commit Guidelines](#commit-guidelines)
- [Common Operations](#common-operations)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Initial Setup

### First Time Setup

```bash
# 1. Configure Git with your details
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 2. Clone the repository
git clone https://github.com/amir3x0/Real-Time-Call-Translator.git
cd Real-Time-Call-Translator

# 3. Verify remote
git remote -v
# Should show:
# origin  https://github.com/amir3x0/Real-Time-Call-Translator.git (fetch)
# origin  https://github.com/amir3x0/Real-Time-Call-Translator.git (push)

# 4. Check current branch
git branch
# Should show: * develop (or main)

# 5. Fetch all branches
git fetch --all

# 6. Set up upstream if working on a fork
git remote add upstream https://github.com/amir3x0/Real-Time-Call-Translator.git
```

### Configure Git Ignore

The repository already includes comprehensive `.gitignore` files:
- **Root**: `/.gitignore` - Global patterns
- **Backend**: `/backend/.gitignore` - Python/Backend specific

**Important files that are ignored:**
- `.env` files (secrets)
- `google-credentials.json` (API keys)
- `__pycache__/` directories
- Virtual environments
- Database files
- Docker override files

---

## 🔄 Daily Workflow

### Starting Your Day

```bash
# 1. Switch to develop branch
git checkout develop

# 2. Get latest changes
git pull origin develop

# 3. Check status
git status

# 4. View recent changes
git log --oneline -10
```

### Working on a New Feature

```bash
# 1. Create and switch to a new feature branch
git checkout -b feature/your-feature-name

# Example:
git checkout -b feature/voice-cloning
git checkout -b feature/translation-engine
git checkout -b bugfix/redis-connection
```

### Making Changes

```bash
# 1. Check what files changed
git status

# 2. View changes in detail
git diff

# 3. Stage specific files
git add backend/app/services/translation.py
git add backend/app/models/voice.py

# Or stage all changes
git add .

# 4. Commit with a meaningful message
git commit -m "feat: implement voice cloning service"

# 5. Push to remote
git push origin feature/your-feature-name
```

---

## 🌳 Branch Strategy

### Branch Types

```
main (production-ready code)
  └── develop (integration branch)
       ├── feature/voice-cloning
       ├── feature/translation-api
       ├── feature/mobile-ui
       ├── bugfix/redis-timeout
       └── hotfix/critical-security-fix
```

### Branch Naming Convention

| Type | Prefix | Example |
|------|--------|---------|
| New Feature | `feature/` | `feature/google-stt-integration` |
| Bug Fix | `bugfix/` | `bugfix/database-connection` |
| Hotfix | `hotfix/` | `hotfix/security-patch` |
| Enhancement | `enhancement/` | `enhancement/improve-performance` |
| Documentation | `docs/` | `docs/api-documentation` |
| Testing | `test/` | `test/integration-tests` |
| Refactor | `refactor/` | `refactor/service-architecture` |

### Branch Management

```bash
# Create new branch
git checkout -b feature/new-feature

# Switch between branches
git checkout develop
git checkout feature/voice-cloning

# List all branches
git branch -a

# Delete local branch
git branch -d feature/completed-feature

# Delete remote branch
git push origin --delete feature/old-feature

# Rename current branch
git branch -m new-branch-name
```

---

## 💬 Commit Guidelines

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, semicolons, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks (dependencies, configs)
- `perf`: Performance improvements
- `ci`: CI/CD changes
- `build`: Build system changes

### Examples

```bash
# Feature
git commit -m "feat(backend): add Google Speech-to-Text integration"

# Bug fix
git commit -m "fix(redis): resolve connection timeout issue"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Refactoring
git commit -m "refactor(services): restructure translation pipeline"

# Multiple changes
git commit -m "feat(backend): implement voice cloning

- Add voice sample upload endpoint
- Integrate Google Cloud TTS API
- Create voice model training pipeline
- Add quality scoring system

Closes #123"
```

### Commit Best Practices

✅ **DO:**
- Write clear, descriptive commit messages
- Keep commits atomic (one logical change)
- Reference issue numbers (e.g., "Fixes #42")
- Use present tense ("add feature" not "added feature")

❌ **DON'T:**
- Commit sensitive data (.env files, credentials)
- Make huge commits with many unrelated changes
- Use vague messages ("fix stuff", "update code")
- Commit commented-out code

---

## 🛠 Common Operations

### Checking Status

```bash
# View modified files
git status

# View changes in files
git diff

# View staged changes
git diff --cached

# View commit history
git log

# Pretty log
git log --oneline --graph --decorate --all

# View changes in specific file
git log -p backend/app/main.py
```

### Staging Changes

```bash
# Stage specific file
git add backend/app/services/translation.py

# Stage multiple files
git add backend/app/*.py

# Stage all changes
git add .

# Unstage file
git reset backend/app/config/settings.py

# Unstage all
git reset
```

### Committing

```bash
# Commit staged changes
git commit -m "feat: add translation service"

# Commit with detailed message
git commit -m "feat(backend): implement real-time translation

- Add Google Translate API integration
- Create translation service class
- Add language detection
- Implement caching for frequent translations"

# Amend last commit (before push)
git commit --amend -m "feat: corrected commit message"

# Add files to last commit
git add forgotten-file.py
git commit --amend --no-edit
```

### Pushing and Pulling

```bash
# Push to remote
git push origin feature/your-branch

# Force push (use with caution!)
git push origin feature/your-branch --force

# Pull latest changes
git pull origin develop

# Fetch without merging
git fetch origin

# Pull with rebase
git pull --rebase origin develop
```

### Merging

```bash
# Switch to target branch
git checkout develop

# Merge feature branch
git merge feature/voice-cloning

# Merge with no fast-forward (creates merge commit)
git merge --no-ff feature/translation-api

# Abort merge if conflicts
git merge --abort
```

### Resolving Conflicts

```bash
# 1. Pull latest changes
git pull origin develop

# If conflicts occur:
# 2. View conflicted files
git status

# 3. Open conflicted files and resolve manually
# Look for markers: <<<<<<<, =======, >>>>>>>

# 4. Stage resolved files
git add backend/app/services/translation.py

# 5. Complete the merge
git commit -m "merge: resolve conflicts in translation service"

# 6. Push changes
git push origin develop
```

### Stashing Changes

```bash
# Save current changes temporarily
git stash

# List stashes
git stash list

# Apply last stash
git stash apply

# Apply and remove last stash
git stash pop

# Apply specific stash
git stash apply stash@{1}

# Create named stash
git stash save "work in progress on voice cloning"

# Delete stash
git stash drop stash@{0}

# Clear all stashes
git stash clear
```

### Reverting Changes

```bash
# Discard changes in file (not staged)
git checkout -- backend/app/main.py

# Discard all unstaged changes
git checkout -- .

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Undo last commit (discard changes)
git reset --hard HEAD~1

# Revert a specific commit (creates new commit)
git revert <commit-hash>
```

### Viewing History

```bash
# Show commit log
git log

# Compact log
git log --oneline

# Show last 5 commits
git log -5

# Show commits with file changes
git log --stat

# Show commits by author
git log --author="Amir"

# Show commits in date range
git log --since="2024-01-01" --until="2024-12-31"

# Search commits by message
git log --grep="translation"

# Show file history
git log -- backend/app/services/translation.py
```

### Tags

```bash
# List tags
git tag

# Create lightweight tag
git tag v1.0.0

# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Tag specific commit
git tag -a v0.9.0 <commit-hash> -m "Beta release"

# Push tag to remote
git push origin v1.0.0

# Push all tags
git push origin --tags

# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push origin --delete v1.0.0
```

---

## 📚 Best Practices

### Before Committing

```bash
# 1. Review changes
git status
git diff

# 2. Test your code
cd backend
docker-compose up -d
docker exec -it translator_api pytest

# 3. Check for sensitive data
git diff | grep -i "password\|secret\|key\|token"

# 4. Ensure .gitignore is working
git status --ignored
```

### Working with .env Files

```bash
# ❌ NEVER commit .env files
# .env is in .gitignore

# ✅ Use .env.example as template
cp backend/.env.example backend/.env
# Edit .env with your local values

# ✅ Document required variables in .env.example
```

### Pull Request Workflow

```bash
# 1. Create feature branch
git checkout -b feature/new-feature develop

# 2. Make changes and commit
git add .
git commit -m "feat: implement new feature"

# 3. Push to remote
git push origin feature/new-feature

# 4. Create Pull Request on GitHub
# - Navigate to repository
# - Click "Compare & pull request"
# - Fill in description
# - Request reviewers

# 5. After PR is approved, merge to develop
# 6. Delete feature branch
git branch -d feature/new-feature
git push origin --delete feature/new-feature
```

### Keeping Your Branch Updated

```bash
# Option 1: Merge (creates merge commits)
git checkout feature/your-feature
git merge develop

# Option 2: Rebase (cleaner history)
git checkout feature/your-feature
git rebase develop

# If conflicts during rebase:
# 1. Resolve conflicts
git add .
git rebase --continue

# Or abort rebase
git rebase --abort
```

---

## 🐛 Troubleshooting

### Accidentally Committed Secrets

```bash
# 1. Remove file from Git (keep local copy)
git rm --cached backend/.env

# 2. Add to .gitignore
echo "backend/.env" >> .gitignore

# 3. Commit removal
git commit -m "chore: remove .env from version control"

# 4. Change compromised credentials immediately!
```

### Undo Pushed Commit

```bash
# ⚠️ Only if you haven't shared the commit

# 1. Reset to previous commit
git reset --hard HEAD~1

# 2. Force push
git push origin feature/your-branch --force
```

### Recover Deleted Branch

```bash
# 1. Find commit hash
git reflog

# 2. Recreate branch
git checkout -b recovered-branch <commit-hash>
```

### Large Files Accidentally Committed

```bash
# 1. Remove from Git history (use BFG Repo Cleaner)
# Download from: https://rtyley.github.io/bfg-repo-cleaner/

# 2. Or use git filter-branch (slower)
git filter-branch --tree-filter 'rm -f path/to/large/file' HEAD

# 3. Force push
git push origin --force --all
```

### Merge Conflicts Help

```bash
# View conflicted files
git status

# Use merge tool
git mergetool

# Accept their version
git checkout --theirs backend/app/main.py

# Accept our version
git checkout --ours backend/app/main.py
```

---

## 🎯 Project-Specific Workflows

### Backend Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/backend-improvement develop

# 2. Make changes to backend
cd backend
# Edit files...

# 3. Test locally
docker-compose up --build -d
docker exec -it translator_api pytest

# 4. Stage and commit
git add backend/
git commit -m "feat(backend): improve translation accuracy"

# 5. Push and create PR
git push origin feature/backend-improvement
```

### Mobile Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/mobile-ui develop

# 2. Make changes
cd mobile
# Edit Flutter files...

# 3. Test on device
flutter run

# 4. Commit changes
git add mobile/
git commit -m "feat(mobile): implement call screen UI"

# 5. Push
git push origin feature/mobile-ui
```

### Release Workflow

```bash
# 1. Create release branch from develop
git checkout -b release/v1.0.0 develop

# 2. Update version numbers
# Edit version files...

# 3. Commit version changes
git commit -m "chore: bump version to 1.0.0"

# 4. Merge to main
git checkout main
git merge --no-ff release/v1.0.0

# 5. Tag release
git tag -a v1.0.0 -m "Release version 1.0.0"

# 6. Merge back to develop
git checkout develop
git merge --no-ff release/v1.0.0

# 7. Push everything
git push origin main develop v1.0.0

# 8. Delete release branch
git branch -d release/v1.0.0
```

---

## 📖 Quick Reference

### Essential Commands

```bash
# Status & Info
git status                    # Check working directory status
git log --oneline            # View commit history
git diff                     # View unstaged changes

# Branching
git checkout -b <branch>     # Create and switch to branch
git branch                   # List branches
git branch -d <branch>       # Delete branch

# Staging & Committing
git add <file>               # Stage file
git add .                    # Stage all changes
git commit -m "message"      # Commit staged changes

# Remote Operations
git pull origin <branch>     # Pull from remote
git push origin <branch>     # Push to remote
git fetch --all              # Fetch all remotes

# Undo Operations
git reset HEAD <file>        # Unstage file
git checkout -- <file>       # Discard changes
git revert <commit>          # Revert commit
```

---

## 📞 Getting Help

```bash
# General help
git help

# Command-specific help
git help commit
git help merge
git help rebase

# Quick reference
git <command> --help
```

---

**Happy Coding! 🚀**

*For questions or issues, contact the repository maintainer or create an issue on GitHub.*
