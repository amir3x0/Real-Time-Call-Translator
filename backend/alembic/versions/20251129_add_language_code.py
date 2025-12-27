"""
Add language_code column to users table

Revision ID: add_language_code_field
Revises: 20251127_add_phone_fullname
Create Date: 2025-11-29
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = 'add_language_code_field'
down_revision = '20251127_add_phone_fullname'
branch_labels = None
depends_on = None


def upgrade():
    # Add language_code column to users table
    op.add_column('users', sa.Column('language_code', sa.String(length=10), nullable=True))
    
    # Backfill language_code with primary_language for existing users
    conn = op.get_bind()
    conn.execute(sa.text('UPDATE users SET language_code = primary_language WHERE language_code IS NULL'))
    
    print("✅ Added 'language_code' column to users table")


def downgrade():
    # Remove language_code column
    op.drop_column('users', 'language_code')
    
    print("✅ Removed 'language_code' column from users table")
