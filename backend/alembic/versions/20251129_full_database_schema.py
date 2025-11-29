"""
Full Database Schema - Create all tables matching database design

This migration creates:
1. contacts - Contact list management
2. voice_recordings - Voice sample storage for xTTS training
3. calls - Call session management
4. call_participants - Per-participant call metadata
5. call_transcripts - Call history and transcription

And updates:
- users - Add missing fields (email, phone_number, voice_model_id, etc.)

Revision ID: 20251129_full_database_schema
Revises: add_language_code_field
Create Date: 2025-11-29
"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '20251129_full_database_schema'
down_revision = 'add_language_code_field'
branch_labels = None
depends_on = None


def upgrade():
    # ============================================
    # UPDATE USERS TABLE
    # ============================================
    
    # Add missing columns to users table
    try:
        op.add_column('users', sa.Column('email', sa.String(length=255), nullable=True))
        op.create_index('idx_users_email', 'users', ['email'], unique=True)
    except Exception:
        pass
    
    try:
        op.add_column('users', sa.Column('phone_number', sa.String(length=20), nullable=True))
    except Exception:
        pass
    
    try:
        op.add_column('users', sa.Column('voice_model_id', sa.String(length=255), nullable=True))
    except Exception:
        pass
    
    # Create online index if not exists
    try:
        op.create_index('idx_users_is_online', 'users', ['is_online'])
    except Exception:
        pass
    
    # ============================================
    # CREATE CONTACTS TABLE
    # ============================================
    op.create_table(
        'contacts',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('user_id', sa.String(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('contact_user_id', sa.String(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('contact_name', sa.String(length=255), nullable=True),
        sa.Column('added_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('is_blocked', sa.Boolean(), default=False),
        sa.UniqueConstraint('user_id', 'contact_user_id', name='uq_user_contact'),
    )
    
    op.create_index('idx_contacts_user_id', 'contacts', ['user_id'])
    op.create_index('idx_contacts_contact_user_id', 'contacts', ['contact_user_id'])
    
    # ============================================
    # CREATE VOICE_RECORDINGS TABLE
    # ============================================
    op.create_table(
        'voice_recordings',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('user_id', sa.String(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('language', sa.String(length=10), nullable=False),
        sa.Column('text_content', sa.Text(), nullable=False),
        sa.Column('file_path', sa.String(length=500), nullable=False),
        sa.Column('file_size_bytes', sa.Integer(), nullable=True),
        sa.Column('duration_seconds', sa.Integer(), nullable=True),
        sa.Column('sample_rate', sa.Integer(), nullable=True),
        sa.Column('audio_format', sa.String(length=20), nullable=True),
        sa.Column('quality_score', sa.Integer(), nullable=True),
        sa.Column('is_processed', sa.Boolean(), default=False),
        sa.Column('processed_at', sa.DateTime(), nullable=True),
        sa.Column('processing_error', sa.Text(), nullable=True),
        sa.Column('used_for_training', sa.Boolean(), default=False),
        sa.Column('training_batch_id', sa.String(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=True, onupdate=sa.func.now()),
        sa.CheckConstraint("language IN ('he', 'en', 'ru')", name='ck_voice_recording_language'),
    )
    
    op.create_index('idx_voice_recordings_user_id', 'voice_recordings', ['user_id'])
    op.create_index('idx_voice_recordings_used_for_training', 'voice_recordings', ['used_for_training'])
    
    # ============================================
    # CREATE CALLS TABLE
    # ============================================
    op.create_table(
        'calls',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('session_id', sa.String(), nullable=False, unique=True),
        sa.Column('caller_user_id', sa.String(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('created_by', sa.String(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('call_language', sa.String(length=10), nullable=False),
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('status', sa.String(length=20), nullable=False, default='initiating'),
        sa.Column('started_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('ended_at', sa.DateTime(), nullable=True),
        sa.Column('duration_seconds', sa.Integer(), nullable=True),
        sa.Column('participant_count', sa.Integer(), default=1),
        sa.Column('current_participants', sa.Integer(), default=0),
        sa.Column('max_participants', sa.Integer(), default=4),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=True, onupdate=sa.func.now()),
        sa.CheckConstraint("call_language IN ('he', 'en', 'ru')", name='ck_call_language'),
        sa.CheckConstraint("status IN ('initiating', 'ringing', 'ongoing', 'ended', 'missed')", name='ck_call_status'),
    )
    
    op.create_index('idx_calls_caller_user_id', 'calls', ['caller_user_id'])
    op.create_index('idx_calls_is_active', 'calls', ['is_active'])
    op.create_index('idx_calls_status', 'calls', ['status'])
    op.create_index('idx_calls_session_id', 'calls', ['session_id'])
    
    # ============================================
    # CREATE CALL_PARTICIPANTS TABLE
    # ============================================
    op.create_table(
        'call_participants',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('call_id', sa.String(), sa.ForeignKey('calls.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id', sa.String(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('participant_language', sa.String(length=10), nullable=False),
        sa.Column('target_language', sa.String(length=10), nullable=False),
        sa.Column('speaking_language', sa.String(length=10), nullable=False),
        sa.Column('joined_at', sa.DateTime(), nullable=True),
        sa.Column('left_at', sa.DateTime(), nullable=True),
        sa.Column('is_muted', sa.Boolean(), default=False),
        sa.Column('dubbing_required', sa.Boolean(), default=False),
        sa.Column('use_voice_clone', sa.Boolean(), default=True),
        sa.Column('voice_clone_quality', sa.String(length=20), nullable=True),
        sa.Column('is_connected', sa.Boolean(), default=False),
        sa.Column('notes', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(), nullable=True, onupdate=sa.func.now()),
        sa.UniqueConstraint('call_id', 'user_id', name='uq_call_user'),
        sa.CheckConstraint("participant_language IN ('he', 'en', 'ru')", name='ck_participant_language'),
        sa.CheckConstraint("target_language IN ('he', 'en', 'ru')", name='ck_target_language'),
        sa.CheckConstraint("speaking_language IN ('he', 'en', 'ru')", name='ck_speaking_language'),
    )
    
    op.create_index('idx_call_participants_call_id', 'call_participants', ['call_id'])
    op.create_index('idx_call_participants_user_id', 'call_participants', ['user_id'])
    op.create_index('idx_call_participants_left_at', 'call_participants', ['left_at'])
    
    # ============================================
    # CREATE CALL_TRANSCRIPTS TABLE
    # ============================================
    op.create_table(
        'call_transcripts',
        sa.Column('id', sa.String(), primary_key=True),
        sa.Column('call_id', sa.String(), sa.ForeignKey('calls.id', ondelete='CASCADE'), nullable=False),
        sa.Column('speaker_user_id', sa.String(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('original_language', sa.String(length=10), nullable=False),
        sa.Column('original_text', sa.Text(), nullable=False),
        sa.Column('translated_text', sa.Text(), nullable=True),
        sa.Column('target_language', sa.String(length=10), nullable=True),
        sa.Column('timestamp_ms', sa.Integer(), nullable=True),
        sa.Column('audio_file_path', sa.String(length=500), nullable=True),
        sa.Column('original_audio_path', sa.String(length=500), nullable=True),
        sa.Column('translated_audio_path', sa.String(length=500), nullable=True),
        sa.Column('stt_confidence', sa.Integer(), nullable=True),
        sa.Column('translation_quality', sa.Integer(), nullable=True),
        sa.Column('tts_method', sa.String(length=50), nullable=True),
        sa.Column('processing_time_ms', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("original_language IN ('he', 'en', 'ru')", name='ck_transcript_original_language'),
    )
    
    op.create_index('idx_call_transcripts_call_id', 'call_transcripts', ['call_id'])
    op.create_index('idx_call_transcripts_speaker_user_id', 'call_transcripts', ['speaker_user_id'])
    
    print("✅ Full database schema created successfully")


def downgrade():
    # Drop tables in reverse order (due to foreign key dependencies)
    op.drop_table('call_transcripts')
    op.drop_table('call_participants')
    op.drop_table('calls')
    op.drop_table('voice_recordings')
    op.drop_table('contacts')
    
    # Remove added columns from users
    try:
        op.drop_index('idx_users_email', 'users')
        op.drop_column('users', 'email')
    except Exception:
        pass
    
    try:
        op.drop_column('users', 'phone_number')
    except Exception:
        pass
    
    try:
        op.drop_column('users', 'voice_model_id')
    except Exception:
        pass
    
    try:
        op.drop_index('idx_users_is_online', 'users')
    except Exception:
        pass
    
    print("✅ Full database schema downgraded")

