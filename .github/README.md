# .github Directory Structure

This directory contains all GitHub-related configuration, documentation, and automation files for the Real-Time Call Translator project.

## 📁 Directory Organization

```
.github/
├── README.md                    # This file - Directory structure guide
├── copilot-instructions.md      # GitHub Copilot configuration
├── CUSTOM_INSTRUCTIONS.md       # Detailed Copilot instructions
├── docs/                        # 📚 Project Documentation
│   ├── CODE_GUIDELINES.md       # Coding standards and best practices
│   ├── CONTRIBUTING.md          # Contribution guidelines
│   ├── GIT_INSTRUCTIONS.md      # Git workflow and commands
│   └── POSTGRESQL_GUIDE.md      # Database management guide
├── workflows/                   # 🔄 GitHub Actions (Future)
│   └── (CI/CD pipelines will be added here)
└── templates/                   # 📝 Issue/PR Templates (Future)
    └── (Templates will be added here)
```

## 📄 File Descriptions

### Root Level Files

#### `copilot-instructions.md`
Quick reference file for GitHub Copilot with:
- Project context and current status
- Code preferences (Python, Database, Imports)
- Language codes and Redis patterns
- Security and testing guidelines
- Links to detailed documentation

#### `CUSTOM_INSTRUCTIONS.md`
Comprehensive GitHub Copilot instructions including:
- Complete project overview and status
- Technology stack details
- Architecture principles
- Code style standards
- API endpoint conventions
- Error handling patterns
- Language codes and Redis patterns
- Security best practices
- Testing guidelines
- Database patterns
- Project timeline reference

### docs/ - Documentation Files

#### `CODE_GUIDELINES.md`
Comprehensive coding standards covering:
- Project structure and organization
- Python style guide (PEP 8 compliance)
- FastAPI conventions
- Database patterns with SQLAlchemy
- API design principles
- Redis usage patterns
- Error handling strategies
- Testing standards
- Documentation requirements
- Security practices
- Performance optimization

#### `CONTRIBUTING.md`
Guidelines for contributors including:
- Code of conduct
- Getting started guide
- Development setup instructions
- How to contribute (features, bugs, documentation)
- Pull request process
- Testing requirements
- Code review guidelines
- Project structure overview

#### `GIT_INSTRUCTIONS.md`
Git workflow documentation including:
- Initial setup instructions
- Daily workflow commands
- Branch strategy (main, develop, feature branches)
- Commit message conventions
- Common Git operations
- Best practices
- Troubleshooting guide

#### `POSTGRESQL_GUIDE.md`
Database management guide covering:
- Connection methods (pgAdmin, psql, Python)
- Database schema overview
- Common SQL queries
- Table relationships
- Backup and restore procedures
- Performance optimization
- Troubleshooting tips

### workflows/ - GitHub Actions

This directory contains CI/CD automation:
- **[backend-ci.yml](workflows/backend-ci.yml)** - CI pipeline for Python FastAPI backend (Tests, Linting)
- **[mobile-ci.yml](workflows/mobile-ci.yml)** - CI pipeline for Flutter mobile app (Analyze, Tests)

### templates/ - Issue & PR Templates

This directory contains templates for:
- **[issue_template.md](templates/issue_template.md)** - Bug report template
- **[pull_request_template.md](templates/pull_request_template.md)** - Pull request template

## 🎯 Current Project Status

**Week 1 - Day 4 Complete ✅**

**Completed:**
- ✅ All 6 database models (User, Call, CallParticipant, Contact, VoiceModel, Message)
- ✅ Docker Compose infrastructure
- ✅ FastAPI application with health endpoint
- ✅ WebSocket endpoint structure
- ✅ Complete documentation

**Next:**
- 📋 Day 4 (21.11): Flutter Project Setup
- 📋 Day 5 (22.11): Google Cloud Setup

## 📚 Documentation Navigation

**For Quick Reference:**
- Start with `copilot-instructions.md` for code style basics

**For Detailed Information:**
**Week 1 - Day 4 Complete ✅**
- Check `docs/CODE_GUIDELINES.md` for coding standards
- Review `docs/CONTRIBUTING.md` before contributing
- Use `docs/GIT_INSTRUCTIONS.md` for Git workflow
- Refer to `docs/POSTGRESQL_GUIDE.md` for database operations

## 🔗 Related Files

- **Root README**: `../README.md` - Main project documentation
- **Backend**: `../backend/` - Python/FastAPI backend
- **Docker**: `../backend/docker-compose.yml` - Service orchestration

 - ✅ Day 4 completed: Mobile project initialized with providers, API service, WebSocket utilities, audio service, screens and widgets
## 📝 Maintenance

This directory structure should be maintained as follows:
- Keep documentation up to date with code changes
- Add new guidelines as the project evolves
- Update status markers (✅/📋) as milestones are completed
- Archive outdated documentation in a separate `archive/` folder if needed

## 🤝 Contributing to Documentation

When updating documentation:
1. Follow the existing formatting style
2. Keep language clear and concise
3. Include code examples where helpful
4. Update this README if adding new files
5. Cross-reference related documentation

---

**Last Updated**: November 21, 2025 - Week 1, Day 4  
**Project**: Real-Time Call Translator (25-2-D-5)  
**Team**: Amir Mishayev, Daniel Fraimovich
