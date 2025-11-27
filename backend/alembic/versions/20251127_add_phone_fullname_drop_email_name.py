"""
Add phone and full_name fields to users and drop legacy name/email columns
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '20251127_add_phone_fullname'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # Add new fields as nullable to avoid errors on existing rows
    op.add_column('users', sa.Column('phone', sa.String(length=20), nullable=True))
    op.create_unique_constraint('uq_users_phone', 'users', ['phone'])
    op.add_column('users', sa.Column('full_name', sa.String(length=255), nullable=True))

    # Optionally we could backfill 'full_name' from 'name' if it exists
    conn = op.get_bind()
    try:
        conn.execute(sa.text('UPDATE users SET full_name = name WHERE full_name IS NULL AND name IS NOT NULL'))
    except Exception:
        pass

    # Drop legacy columns if present
    with op.batch_alter_table('users') as batch_op:
        # If column exists, drop. Using try/except to avoid failures on DBs already migrated
        try:
            batch_op.drop_column('email')
        except Exception:
            pass
        try:
            batch_op.drop_column('name')
        except Exception:
            pass

    # If desired, set not-null constraints - but be careful on existing data
    # For now, keep phone and full_name nullable to avoid forcing default values across DB


def downgrade():
    # Recreate legacy columns (nullable)
    op.add_column('users', sa.Column('name', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('email', sa.String(length=255), nullable=True))

    # Copy data back if possible
    conn = op.get_bind()
    try:
        conn.execute(sa.text('UPDATE users SET name = full_name WHERE name IS NULL AND full_name IS NOT NULL'))
    except Exception:
        pass

    # Drop new columns
    with op.batch_alter_table('users') as batch_op:
        try:
            batch_op.drop_constraint('uq_users_phone', type_='unique')
        except Exception:
            pass
        try:
            batch_op.drop_column('phone')
        except Exception:
            pass
        try:
            batch_op.drop_column('full_name')
        except Exception:
            pass
