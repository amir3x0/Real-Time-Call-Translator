"""Simplify user table - remove email, avatar_url, bio

Revision ID: simplify_user_table
Revises: full_database_schema
Create Date: 2024-11-29

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'simplify_user_table'
down_revision: Union[str, None] = 'full_database_schema'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Remove unnecessary columns from users table."""
    # Drop columns if they exist
    try:
        op.drop_column('users', 'email')
    except Exception:
        pass
    
    try:
        op.drop_column('users', 'avatar_url')
    except Exception:
        pass
    
    try:
        op.drop_column('users', 'bio')
    except Exception:
        pass
    
    # Make phone required (not nullable)
    op.alter_column('users', 'phone',
                    existing_type=sa.String(20),
                    nullable=False)


def downgrade() -> None:
    """Re-add columns if needed."""
    # Make phone nullable again
    op.alter_column('users', 'phone',
                    existing_type=sa.String(20),
                    nullable=True)
    
    # Re-add columns
    op.add_column('users', sa.Column('email', sa.String(255), nullable=True))
    op.add_column('users', sa.Column('avatar_url', sa.String(500), nullable=True))
    op.add_column('users', sa.Column('bio', sa.String(500), nullable=True))

