# =====================================================================================
# USER SYSTEM BACKEND SPECIFICATION
# =====================================================================================
#
# Comprehensive design for: Guild Members, User Profiles, Awards, Friends, User Stats
#
# This document provides:
# 1. Database Models (SQLAlchemy)
# 2. Pydantic Schemas (DTOs)
# 3. API Endpoints
# 4. Alembic Migration SQL
# 5. iOS DTO Mappings
#
# Follows existing patterns from guilds.py, guild.py, users.py
#
# =====================================================================================


# =====================================================================================
# PART 1: DATABASE MODELS
# =====================================================================================
# File: shared/models/user.py (additions to existing file)
# =====================================================================================

USER_MODEL_ADDITIONS = '''
# =============================================================================
# ADD TO EXISTING User CLASS RELATIONSHIPS:
# =============================================================================

    # Extended profile (one-to-one)
    profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    
    # Statistics (one-to-one)
    statistics = relationship("UserStatistics", back_populates="user", uselist=False, cascade="all, delete-orphan")
    
    # Awards earned
    awards = relationship("UserAward", back_populates="user", cascade="all, delete-orphan")
    
    # Friendships
    friendships_initiated = relationship(
        "Friendship",
        foreign_keys="Friendship.requester_id",
        back_populates="requester",
        cascade="all, delete-orphan"
    )
    friendships_received = relationship(
        "Friendship",
        foreign_keys="Friendship.addressee_id",
        back_populates="addressee",
        cascade="all, delete-orphan"
    )
    
    # Blocks
    blocked_users = relationship(
        "UserBlock",
        foreign_keys="UserBlock.blocker_id",
        back_populates="blocker",
        cascade="all, delete-orphan"
    )
    blocked_by_users = relationship(
        "UserBlock",
        foreign_keys="UserBlock.blocked_id",
        back_populates="blocked",
        cascade="all, delete-orphan"
    )
'''


# =============================================================================
# NEW MODEL: UserProfile (Extended Profile)
# =============================================================================

USER_PROFILE_MODEL = '''
class UserProfile(Base):
    """Extended user profile information"""
    __tablename__ = "user_profiles"
    __table_args__ = {"schema": "traders_guild"}
    
    user_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.users.id', ondelete='CASCADE'), primary_key=True)
    
    # Bio & Personal
    bio = Column(Text, nullable=True)                               # Max 500 chars
    location = Column(String(100), nullable=True)                   # "London, UK"
    timezone = Column(String(50), nullable=True)                    # "GMT+0", "EST"
    
    # Trading Info
    experience_level = Column(String(20), default="beginner")       # beginner, intermediate, advanced, expert, professional
    trading_style = Column(String(50), nullable=True)               # "Day Trader", "Swing Trader", "Scalper"
    preferred_pairs = Column(ARRAY(String), default=[], nullable=False)  # ["EUR/USD", "GBP/JPY"]
    
    # Social Links (stored as JSON array)
    # Format: [{"platform": "twitter", "username": "trader123", "url": "https://twitter.com/trader123"}]
    social_links = Column(JSONB, default=[], nullable=False)
    
    # Trading Interests (stored as JSON array)
    # Format: [{"name": "Forex", "icon": "dollarsign.circle.fill", "is_primary": true}]
    trading_interests = Column(JSONB, default=[], nullable=False)
    
    # Privacy
    is_profile_public = Column(Boolean, default=True, nullable=False)
    show_online_status = Column(Boolean, default=True, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="profile")
    
    def __repr__(self) -> str:
        return f"<UserProfile(user_id={self.user_id})>"
'''


# =============================================================================
# NEW MODEL: UserStatistics
# =============================================================================

USER_STATISTICS_MODEL = '''
class UserStatistics(Base):
    """User statistics and metrics"""
    __tablename__ = "user_statistics"
    __table_args__ = {"schema": "traders_guild"}
    
    user_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.users.id', ondelete='CASCADE'), primary_key=True)
    
    # Marker Stats
    total_markers_placed = Column(Integer, default=0, nullable=False)
    successful_markers = Column(Integer, default=0, nullable=False)
    accuracy_rate = Column(Numeric(5, 4), default=0.0000, nullable=False)  # 0.0000 to 1.0000
    
    # Engagement Stats
    total_likes_received = Column(Integer, default=0, nullable=False)
    total_comments_made = Column(Integer, default=0, nullable=False)
    
    # Streak Stats
    current_streak_days = Column(Integer, default=0, nullable=False)
    best_streak_days = Column(Integer, default=0, nullable=False)
    
    # Summary Stats
    total_guilds_joined = Column(Integer, default=0, nullable=False)
    total_awards_earned = Column(Integer, default=0, nullable=False)
    total_award_points = Column(Integer, default=0, nullable=False)
    
    # Top Symbols (stored as JSON array of strings)
    top_symbols = Column(JSONB, default=[], nullable=False)  # ["EUR/USD", "GBP/JPY", "BTC/USD"]
    
    # Markers by type (stored as JSON object)
    markers_by_type = Column(JSONB, default={}, nullable=False)  # {"buy": 10, "sell": 5, "neutral": 3}
    
    # Calculation timestamp
    last_calculated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    
    # Relationship
    user = relationship("User", back_populates="statistics")
    
    def __repr__(self) -> str:
        return f"<UserStatistics(user_id={self.user_id}, accuracy={self.accuracy_rate})>"
'''


# =============================================================================
# NEW MODEL: AwardType (Award Definitions)
# =============================================================================

AWARD_TYPE_MODEL = '''
class AwardType(Base):
    """Award type definitions - the available awards in the system"""
    __tablename__ = "award_types"
    __table_args__ = {"schema": "traders_guild"}
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    
    name = Column(String(100), unique=True, nullable=False)         # "First Trade", "Century Trader"
    description = Column(Text, nullable=False)                       # How to earn this award
    icon = Column(String(100), nullable=False)                       # SF Symbol name
    category = Column(String(30), nullable=False)                    # trading, community, milestones, special
    rarity = Column(String(20), nullable=False)                      # common, uncommon, rare, epic, legendary
    points_value = Column(Integer, default=10, nullable=False)       # Points awarded
    
    # For progress-based awards
    required_value = Column(Integer, nullable=True)                  # e.g., 100 for "Place 100 markers"
    
    # Status
    is_active = Column(Boolean, default=True, nullable=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    
    # Relationship
    user_awards = relationship("UserAward", back_populates="award_type")
    
    def __repr__(self) -> str:
        return f"<AwardType(name={self.name}, rarity={self.rarity})>"
'''


# =============================================================================
# NEW MODEL: UserAward (Earned Awards)
# =============================================================================

USER_AWARD_MODEL = '''
class UserAward(Base):
    """Awards earned by users"""
    __tablename__ = "user_awards"
    __table_args__ = (
        UniqueConstraint('user_id', 'award_type_id', name='unq_user_awards_user_award'),
        {"schema": "traders_guild"}
    )
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.users.id', ondelete='CASCADE'), nullable=False)
    award_type_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.award_types.id', ondelete='CASCADE'), nullable=False)
    
    # Progress (null if complete, 0.0-1.0 if in progress)
    progress = Column(Numeric(5, 4), nullable=True)
    current_value = Column(Integer, nullable=True)                   # Current progress value (e.g., 50 of 100 markers)
    
    # State
    is_new = Column(Boolean, default=True, nullable=False)           # Show "New" badge
    
    # Timestamps
    earned_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    
    # Relationships
    user = relationship("User", back_populates="awards")
    award_type = relationship("AwardType", back_populates="user_awards")
    
    def __repr__(self) -> str:
        return f"<UserAward(user_id={self.user_id}, award_type_id={self.award_type_id})>"
'''


# =============================================================================
# NEW MODEL: Friendship
# =============================================================================

FRIENDSHIP_MODEL = '''
class Friendship(Base):
    """Friend relationships between users"""
    __tablename__ = "friendships"
    __table_args__ = (
        UniqueConstraint('requester_id', 'addressee_id', name='unq_friendships_requester_addressee'),
        CheckConstraint('requester_id != addressee_id', name='chk_friendships_not_self'),
        {"schema": "traders_guild"}
    )
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    requester_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.users.id', ondelete='CASCADE'), nullable=False)
    addressee_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.users.id', ondelete='CASCADE'), nullable=False)
    
    # Status: pending, accepted, declined
    status = Column(String(20), default="pending", nullable=False)
    
    # Optional message with request
    message = Column(String(500), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    
    # Relationships
    requester = relationship("User", foreign_keys=[requester_id], back_populates="friendships_initiated")
    addressee = relationship("User", foreign_keys=[addressee_id], back_populates="friendships_received")
    
    def __repr__(self) -> str:
        return f"<Friendship(requester={self.requester_id}, addressee={self.addressee_id}, status={self.status})>"
'''


# =============================================================================
# NEW MODEL: UserBlock
# =============================================================================

USER_BLOCK_MODEL = '''
class UserBlock(Base):
    """User block relationships"""
    __tablename__ = "user_blocks"
    __table_args__ = (
        UniqueConstraint('blocker_id', 'blocked_id', name='unq_user_blocks_blocker_blocked'),
        CheckConstraint('blocker_id != blocked_id', name='chk_user_blocks_not_self'),
        {"schema": "traders_guild"}
    )
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    blocker_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.users.id', ondelete='CASCADE'), nullable=False)
    blocked_id = Column(UUID(as_uuid=True), ForeignKey('traders_guild.users.id', ondelete='CASCADE'), nullable=False)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)
    
    # Relationships
    blocker = relationship("User", foreign_keys=[blocker_id], back_populates="blocked_users")
    blocked = relationship("User", foreign_keys=[blocked_id], back_populates="blocked_by_users")
    
    def __repr__(self) -> str:
        return f"<UserBlock(blocker={self.blocker_id}, blocked={self.blocked_id})>"
'''


# =====================================================================================
# PART 2: PYDANTIC SCHEMAS (DTOs)
# =====================================================================================
# File: shared/schemas/user.py (additions/replacements)
# =====================================================================================

USER_SCHEMAS = '''
"""
User Schemas (DTOs) - Extended for profiles, awards, friends
"""

from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field, ConfigDict
from uuid import UUID


# =============================================================================
# Enums as Literals (for validation)
# =============================================================================

EXPERIENCE_LEVELS = ["beginner", "intermediate", "advanced", "expert", "professional"]
AWARD_CATEGORIES = ["trading", "community", "milestones", "special"]
AWARD_RARITIES = ["common", "uncommon", "rare", "epic", "legendary"]
FRIENDSHIP_STATUSES = ["pending", "accepted", "declined"]
SOCIAL_PLATFORMS = ["twitter", "discord", "telegram", "tradingview", "youtube"]


# =============================================================================
# Social Link & Trading Interest (Embedded)
# =============================================================================

class SocialLinkItem(BaseModel):
    """Social link item for embedding in profile"""
    platform: str               # twitter, discord, telegram, tradingview, youtube
    username: str
    url: Optional[str] = None


class TradingInterestItem(BaseModel):
    """Trading interest item for embedding in profile"""
    name: str                   # Forex, Crypto, Stocks, etc.
    icon: str                   # SF Symbol name
    is_primary: bool = False


# =============================================================================
# User Extended Profile Schemas
# =============================================================================

class UserProfileResponse(BaseModel):
    """Extended user profile response"""
    user_id: UUID
    bio: Optional[str] = None
    location: Optional[str] = None
    timezone: Optional[str] = None
    experience_level: str = "beginner"
    trading_style: Optional[str] = None
    preferred_pairs: List[str] = []
    social_links: List[SocialLinkItem] = []
    trading_interests: List[TradingInterestItem] = []
    is_profile_public: bool = True
    show_online_status: bool = True
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class UserProfileUpdateRequest(BaseModel):
    """Update user profile request"""
    bio: Optional[str] = Field(None, max_length=500)
    location: Optional[str] = Field(None, max_length=100)
    timezone: Optional[str] = Field(None, max_length=50)
    experience_level: Optional[str] = None
    trading_style: Optional[str] = Field(None, max_length=50)
    preferred_pairs: Optional[List[str]] = None
    social_links: Optional[List[SocialLinkItem]] = None
    trading_interests: Optional[List[TradingInterestItem]] = None
    is_profile_public: Optional[bool] = None
    show_online_status: Optional[bool] = None


# =============================================================================
# User Statistics Schemas
# =============================================================================

class UserStatisticsResponse(BaseModel):
    """User statistics response"""
    user_id: UUID
    total_markers_placed: int
    successful_markers: int
    accuracy_rate: float                    # 0.0 to 1.0
    total_likes_received: int
    total_comments_made: int
    current_streak_days: int
    best_streak_days: int
    total_guilds_joined: int
    total_awards_earned: int
    total_award_points: int
    top_symbols: List[str]
    markers_by_type: Dict[str, int]
    last_calculated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


# =============================================================================
# Award Schemas
# =============================================================================

class AwardTypeResponse(BaseModel):
    """Award type/definition response"""
    id: UUID
    name: str
    description: str
    icon: str
    category: str
    rarity: str
    points_value: int
    required_value: Optional[int] = None
    
    model_config = ConfigDict(from_attributes=True)


class UserAwardResponse(BaseModel):
    """User's earned award response"""
    id: UUID
    award_id: UUID                          # award_type_id
    name: str                               # From award_type
    description: str                        # From award_type
    icon: str                               # From award_type
    category: str                           # From award_type
    rarity: str                             # From award_type
    points_value: int                       # From award_type
    progress: Optional[float] = None        # 0.0 to 1.0, None if complete
    current_value: Optional[int] = None     # Current progress value
    is_new: bool
    earned_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class AwardsSummaryResponse(BaseModel):
    """Awards summary for profile"""
    total_awards: int
    total_points: int
    rarity_breakdown: Dict[str, int]        # {"common": 5, "rare": 2, ...}
    recent_awards: List[UserAwardResponse]  # Last 3 earned
    
    model_config = ConfigDict(from_attributes=True)


class UserAwardsListResponse(BaseModel):
    """List of user awards"""
    awards: List[UserAwardResponse]
    
    model_config = ConfigDict(from_attributes=True)


# =============================================================================
# Friendship Schemas
# =============================================================================

class FriendRequestCreateRequest(BaseModel):
    """Send friend request"""
    to_user_id: UUID
    message: Optional[str] = Field(None, max_length=500)


class FriendshipResponse(BaseModel):
    """Friendship/friend request response"""
    id: UUID
    requester_id: UUID
    addressee_id: UUID
    status: str
    message: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class FriendResponse(BaseModel):
    """Friend with user details - for friends list"""
    friendship_id: UUID
    user_id: UUID
    username: str
    display_name: str
    avatar_url: Optional[str] = None
    is_online: bool
    global_reputation: int
    friends_since: datetime                 # When friendship was accepted
    
    model_config = ConfigDict(from_attributes=True)


class FriendRequestIncomingResponse(BaseModel):
    """Incoming friend request with sender details"""
    id: UUID
    from_user_id: UUID
    from_username: str
    from_display_name: str
    from_avatar_url: Optional[str] = None
    message: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class FriendRequestOutgoingResponse(BaseModel):
    """Outgoing friend request with recipient details"""
    id: UUID
    to_user_id: UUID
    to_username: str
    to_display_name: str
    to_avatar_url: Optional[str] = None
    message: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class FriendsListResponse(BaseModel):
    """List of friends"""
    friends: List[FriendResponse]
    total_count: int
    online_count: int
    
    model_config = ConfigDict(from_attributes=True)


class FriendRequestsListResponse(BaseModel):
    """List of friend requests"""
    incoming: List[FriendRequestIncomingResponse]
    outgoing: List[FriendRequestOutgoingResponse]
    
    model_config = ConfigDict(from_attributes=True)


# =============================================================================
# Block Schemas
# =============================================================================

class BlockedUserResponse(BaseModel):
    """Blocked user in list"""
    block_id: UUID
    user_id: UUID
    username: str
    display_name: str
    avatar_url: Optional[str] = None
    blocked_at: datetime
    
    model_config = ConfigDict(from_attributes=True)


class BlockedUsersListResponse(BaseModel):
    """List of blocked users"""
    blocked_users: List[BlockedUserResponse]
    total_count: int
    
    model_config = ConfigDict(from_attributes=True)


# =============================================================================
# Guild Member Schemas (with full user data)
# =============================================================================

class GuildMemberResponse(BaseModel):
    """
    Guild member with full user data embedded.
    
    This replaces the old GuildMembershipDTO for member lists.
    Combines membership data with user data in one response.
    """
    # Membership data
    membership_id: UUID
    role: str
    reputation: int
    contribution_score: int
    date_joined: datetime
    
    # User data (embedded - no lookup needed!)
    user_id: UUID
    username: str
    display_name: str
    avatar_url: Optional[str] = None
    is_online: bool
    global_reputation: int
    
    # Relationship to current user (personalized!)
    is_friend: bool = False
    friendship_status: Optional[str] = None     # none, pending_sent, pending_received, accepted
    is_blocked: bool = False
    is_blocked_by: bool = False                 # Whether they blocked current user
    
    model_config = ConfigDict(from_attributes=True)


class GuildMembersListResponse(BaseModel):
    """Guild members list response"""
    members: List[GuildMemberResponse]
    total_count: int
    online_count: int
    
    model_config = ConfigDict(from_attributes=True)


# =============================================================================
# Full User Profile Response (Combined)
# =============================================================================

class UserFullProfileResponse(BaseModel):
    """
    Complete user profile with all related data.
    
    Used for profile detail views (both current user and viewing others).
    """
    # Basic user info (from UserResponse)
    user_id: UUID
    username: str
    display_name: str
    avatar_url: Optional[str] = None
    global_reputation: int
    is_online: bool
    is_verified: bool
    created_at: datetime
    
    # Extended profile
    profile: Optional[UserProfileResponse] = None
    
    # Statistics
    statistics: Optional[UserStatisticsResponse] = None
    
    # Awards summary
    awards_summary: Optional[AwardsSummaryResponse] = None
    
    # Current user's relationship to this user (if viewing someone else)
    is_friend: bool = False
    friendship_status: Optional[str] = None     # none, pending_sent, pending_received, accepted
    is_blocked: bool = False
    is_blocked_by: bool = False
    
    # Guild context (if viewing within a guild)
    guild_membership: Optional[GuildMemberResponse] = None
    
    model_config = ConfigDict(from_attributes=True)
'''


# =====================================================================================
# PART 3: API ENDPOINTS
# =====================================================================================
# File: api/routes/users.py (additions to existing)
# =====================================================================================

USER_ENDPOINTS = '''
# =============================================================================
# USER PROFILE ENDPOINTS
# =============================================================================

@router.get("/me/profile", response_model=UserFullProfileResponse)
async def get_current_user_full_profile(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's complete profile with extended info, stats, and awards.
    """
    # Build full profile response
    pass


@router.get("/me/profile/extended", response_model=UserProfileResponse)
async def get_current_user_extended_profile(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's extended profile only.
    Creates default profile if not exists.
    """
    pass


@router.put("/me/profile", response_model=UserProfileResponse)
async def update_current_user_profile(
    request: UserProfileUpdateRequest,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Update current user's extended profile.
    """
    pass


@router.get("/me/statistics", response_model=UserStatisticsResponse)
async def get_current_user_statistics(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current user's statistics.
    Creates default stats if not exists.
    """
    pass


# =============================================================================
# USER AWARDS ENDPOINTS
# =============================================================================

@router.get("/me/awards", response_model=UserAwardsListResponse)
async def get_current_user_awards(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get all awards earned by current user"""
    pass


@router.get("/me/awards/summary", response_model=AwardsSummaryResponse)
async def get_current_user_awards_summary(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get awards summary for current user's profile"""
    pass


@router.post("/me/awards/{award_id}/mark-seen")
async def mark_award_as_seen(
    award_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Mark an award as seen (removes 'new' badge)"""
    pass


# =============================================================================
# FRIENDS ENDPOINTS
# =============================================================================

@router.get("/me/friends", response_model=FriendsListResponse)
async def get_friends(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get current user's accepted friends list"""
    pass


@router.get("/me/friends/requests", response_model=FriendRequestsListResponse)
async def get_friend_requests(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get pending friend requests (both incoming and outgoing)"""
    pass


@router.post("/me/friends/request", response_model=FriendshipResponse)
async def send_friend_request(
    request: FriendRequestCreateRequest,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Send a friend request to another user.
    
    Checks:
    - Not already friends
    - Not already pending request
    - Not blocked/blocking
    """
    pass


@router.post("/me/friends/requests/{request_id}/accept", response_model=FriendshipResponse)
async def accept_friend_request(
    request_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Accept a pending friend request"""
    pass


@router.post("/me/friends/requests/{request_id}/decline")
async def decline_friend_request(
    request_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Decline a pending friend request"""
    pass


@router.delete("/me/friends/{user_id}")
async def remove_friend(
    user_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Remove a friend / cancel pending request"""
    pass


# =============================================================================
# BLOCK ENDPOINTS
# =============================================================================

@router.get("/me/blocked", response_model=BlockedUsersListResponse)
async def get_blocked_users(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get list of users blocked by current user"""
    pass


@router.post("/me/blocked/{user_id}")
async def block_user(
    user_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Block a user.
    
    Also:
    - Removes any existing friendship
    - Cancels any pending friend requests
    """
    pass


@router.delete("/me/blocked/{user_id}")
async def unblock_user(
    user_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Unblock a user"""
    pass


# =============================================================================
# OTHER USER PROFILE ENDPOINTS
# =============================================================================

@router.get("/{user_id}/profile", response_model=UserFullProfileResponse)
async def get_user_profile(
    user_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get another user's full profile.
    
    Respects:
    - Privacy settings
    - Block status
    """
    pass


@router.get("/{user_id}/awards", response_model=UserAwardsListResponse)
async def get_user_awards(
    user_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get another user's awards"""
    pass
'''


# =====================================================================================
# GUILD MEMBER ENDPOINTS (add to guilds.py)
# =====================================================================================

GUILD_MEMBER_ENDPOINTS = '''
# =============================================================================
# GUILD MEMBERS ENDPOINTS (add to guilds.py)
# =============================================================================

@router.get("/{guild_id}/members", response_model=GuildMembersListResponse)
async def get_guild_members(
    guild_id: UUID,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get guild members with full user data.
    
    Features:
    - Personalized: includes is_friend, is_blocked for each member
    - Search by username or display_name
    - Pagination support
    """
    # Verify user is member of guild
    guild_id_uuid = UUID(str(guild_id)) if isinstance(guild_id, str) else guild_id
    
    membership_result = await db.execute(
        select(GuildMembership).where(
            and_(
                GuildMembership.user_id == user.id,
                GuildMembership.guild_id == guild_id_uuid,
                GuildMembership.status == "active"
            )
        )
    )
    current_membership = membership_result.scalar_one_or_none()
    if not current_membership:
        raise HTTPException(status_code=403, detail="Not a member of this guild")
    
    # Get current user's friends and blocks for personalization
    friends_result = await db.execute(
        select(Friendship.requester_id, Friendship.addressee_id, Friendship.status)
        .where(
            and_(
                or_(
                    Friendship.requester_id == user.id,
                    Friendship.addressee_id == user.id
                ),
                Friendship.status.in_(["pending", "accepted"])
            )
        )
    )
    friends_data = friends_result.all()
    
    # Build friend lookup
    friend_status_map = {}
    for req_id, addr_id, status in friends_data:
        other_id = addr_id if req_id == user.id else req_id
        if status == "accepted":
            friend_status_map[other_id] = "accepted"
        elif status == "pending":
            if req_id == user.id:
                friend_status_map[other_id] = "pending_sent"
            else:
                friend_status_map[other_id] = "pending_received"
    
    # Get blocks
    blocks_result = await db.execute(
        select(UserBlock.blocked_id).where(UserBlock.blocker_id == user.id)
    )
    blocked_ids = {row[0] for row in blocks_result.all()}
    
    blocked_by_result = await db.execute(
        select(UserBlock.blocker_id).where(UserBlock.blocked_id == user.id)
    )
    blocked_by_ids = {row[0] for row in blocked_by_result.all()}
    
    # Build members query
    query = (
        select(GuildMembership, User)
        .join(User, User.id == GuildMembership.user_id)
        .where(
            and_(
                GuildMembership.guild_id == guild_id_uuid,
                GuildMembership.status == "active"
            )
        )
    )
    
    # Add search filter
    if search:
        search_pattern = f"%{search}%"
        query = query.where(
            or_(
                User.username.ilike(search_pattern),
                User.display_name.ilike(search_pattern)
            )
        )
    
    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total_count = total_result.scalar() or 0
    
    # Get online count
    online_query = query.where(User.is_online == True)
    online_count_query = select(func.count()).select_from(online_query.subquery())
    online_result = await db.execute(online_count_query)
    online_count = online_result.scalar() or 0
    
    # Execute with pagination
    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    members = result.all()
    
    # Build response
    member_responses = []
    for membership, member_user in members:
        friend_status = friend_status_map.get(member_user.id)
        is_friend = friend_status == "accepted"
        
        member_responses.append(GuildMemberResponse(
            membership_id=membership.id,
            role=membership.role,
            reputation=membership.reputation,
            contribution_score=membership.contribution_score,
            date_joined=membership.joined_at,
            user_id=member_user.id,
            username=member_user.username,
            display_name=member_user.display_name,
            avatar_url=member_user.avatar_url,
            is_online=member_user.is_online,
            global_reputation=member_user.global_reputation,
            is_friend=is_friend,
            friendship_status=friend_status,
            is_blocked=member_user.id in blocked_ids,
            is_blocked_by=member_user.id in blocked_by_ids
        ))
    
    return GuildMembersListResponse(
        members=member_responses,
        total_count=total_count,
        online_count=online_count
    )


@router.get("/{guild_id}/members/{user_id}", response_model=GuildMemberResponse)
async def get_guild_member(
    guild_id: UUID,
    user_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific guild member's info"""
    # Similar implementation to above, for single member
    pass
'''


# =====================================================================================
# AWARDS ENDPOINTS (new file: api/routes/awards.py)
# =====================================================================================

AWARDS_ENDPOINTS = '''
"""
Award type endpoints - for listing available awards
"""

from typing import Optional, List
from uuid import UUID
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from shared.config.database import get_db
from shared.models.user import User, AwardType
from shared.schemas.user import AwardTypeResponse
from shared.utils.security import get_current_active_user

router = APIRouter()


@router.get("/types", response_model=List[AwardTypeResponse])
async def list_award_types(
    category: Optional[str] = None,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List all available award types.
    
    Optionally filter by category: trading, community, milestones, special
    """
    query = select(AwardType).where(AwardType.is_active == True)
    
    if category:
        query = query.where(AwardType.category == category)
    
    result = await db.execute(query)
    awards = result.scalars().all()
    
    return [
        AwardTypeResponse(
            id=award.id,
            name=award.name,
            description=award.description,
            icon=award.icon,
            category=award.category,
            rarity=award.rarity,
            points_value=award.points_value,
            required_value=award.required_value
        )
        for award in awards
    ]


@router.get("/types/{award_id}", response_model=AwardTypeResponse)
async def get_award_type(
    award_id: UUID,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific award type details"""
    result = await db.execute(
        select(AwardType).where(AwardType.id == award_id)
    )
    award = result.scalar_one_or_none()
    
    if not award:
        raise HTTPException(status_code=404, detail="Award type not found")
    
    return AwardTypeResponse(
        id=award.id,
        name=award.name,
        description=award.description,
        icon=award.icon,
        category=award.category,
        rarity=award.rarity,
        points_value=award.points_value,
        required_value=award.required_value
    )
'''


# =====================================================================================
# PART 4: ALEMBIC MIGRATION SQL
# =====================================================================================

MIGRATION_SQL = '''
-- =====================================================================================
-- USER SYSTEM MIGRATION
-- Run in order - all tables in traders_guild schema
-- =====================================================================================

-- =============================================================================
-- 1. User Profiles (Extended)
-- =============================================================================
CREATE TABLE traders_guild.user_profiles (
    user_id UUID PRIMARY KEY REFERENCES traders_guild.users(id) ON DELETE CASCADE,
    bio TEXT,
    location VARCHAR(100),
    timezone VARCHAR(50),
    experience_level VARCHAR(20) NOT NULL DEFAULT 'beginner',
    trading_style VARCHAR(50),
    preferred_pairs TEXT[] NOT NULL DEFAULT '{}',
    social_links JSONB NOT NULL DEFAULT '[]',
    trading_interests JSONB NOT NULL DEFAULT '[]',
    is_profile_public BOOLEAN NOT NULL DEFAULT TRUE,
    show_online_status BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE traders_guild.user_profiles IS 'Extended user profile information';


-- =============================================================================
-- 2. User Statistics
-- =============================================================================
CREATE TABLE traders_guild.user_statistics (
    user_id UUID PRIMARY KEY REFERENCES traders_guild.users(id) ON DELETE CASCADE,
    total_markers_placed INTEGER NOT NULL DEFAULT 0,
    successful_markers INTEGER NOT NULL DEFAULT 0,
    accuracy_rate NUMERIC(5,4) NOT NULL DEFAULT 0.0000,
    total_likes_received INTEGER NOT NULL DEFAULT 0,
    total_comments_made INTEGER NOT NULL DEFAULT 0,
    current_streak_days INTEGER NOT NULL DEFAULT 0,
    best_streak_days INTEGER NOT NULL DEFAULT 0,
    total_guilds_joined INTEGER NOT NULL DEFAULT 0,
    total_awards_earned INTEGER NOT NULL DEFAULT 0,
    total_award_points INTEGER NOT NULL DEFAULT 0,
    top_symbols JSONB NOT NULL DEFAULT '[]',
    markers_by_type JSONB NOT NULL DEFAULT '{}',
    last_calculated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE traders_guild.user_statistics IS 'User activity statistics and metrics';


-- =============================================================================
-- 3. Award Types (Definitions)
-- =============================================================================
CREATE TABLE traders_guild.award_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    icon VARCHAR(100) NOT NULL,
    category VARCHAR(30) NOT NULL,
    rarity VARCHAR(20) NOT NULL,
    points_value INTEGER NOT NULL DEFAULT 10,
    required_value INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE traders_guild.award_types IS 'Award definitions available in the system';

-- Indexes for award_types
CREATE INDEX idx_award_types_category ON traders_guild.award_types(category);
CREATE INDEX idx_award_types_rarity ON traders_guild.award_types(rarity);


-- =============================================================================
-- 4. User Awards (Earned)
-- =============================================================================
CREATE TABLE traders_guild.user_awards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES traders_guild.users(id) ON DELETE CASCADE,
    award_type_id UUID NOT NULL REFERENCES traders_guild.award_types(id) ON DELETE CASCADE,
    progress NUMERIC(5,4),
    current_value INTEGER,
    is_new BOOLEAN NOT NULL DEFAULT TRUE,
    earned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, award_type_id)
);

COMMENT ON TABLE traders_guild.user_awards IS 'Awards earned by users';

-- Indexes for user_awards
CREATE INDEX idx_user_awards_user_id ON traders_guild.user_awards(user_id);
CREATE INDEX idx_user_awards_earned_at ON traders_guild.user_awards(earned_at DESC);


-- =============================================================================
-- 5. Friendships
-- =============================================================================
CREATE TABLE traders_guild.friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES traders_guild.users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES traders_guild.users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    message VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(requester_id, addressee_id),
    CHECK(requester_id != addressee_id)
);

COMMENT ON TABLE traders_guild.friendships IS 'Friend relationships and requests';

-- Indexes for friendships
CREATE INDEX idx_friendships_requester_id ON traders_guild.friendships(requester_id);
CREATE INDEX idx_friendships_addressee_id ON traders_guild.friendships(addressee_id);
CREATE INDEX idx_friendships_status ON traders_guild.friendships(status);


-- =============================================================================
-- 6. User Blocks
-- =============================================================================
CREATE TABLE traders_guild.user_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES traders_guild.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES traders_guild.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(blocker_id, blocked_id),
    CHECK(blocker_id != blocked_id)
);

COMMENT ON TABLE traders_guild.user_blocks IS 'User block relationships';

-- Indexes for user_blocks
CREATE INDEX idx_user_blocks_blocker_id ON traders_guild.user_blocks(blocker_id);
CREATE INDEX idx_user_blocks_blocked_id ON traders_guild.user_blocks(blocked_id);


-- =============================================================================
-- 7. SEED DATA: Award Types
-- =============================================================================
INSERT INTO traders_guild.award_types (name, description, icon, category, rarity, points_value, required_value) VALUES
-- Trading Awards
('First Prediction', 'Place your first market prediction', 'chart.line.uptrend.xyaxis', 'trading', 'common', 10, NULL),
('Sharp Shooter', 'Get 5 correct predictions in a row', 'scope', 'trading', 'uncommon', 25, 5),
('Centurion', 'Place 100 predictions', 'target', 'trading', 'rare', 50, 100),
('Market Oracle', 'Achieve 75% accuracy over 100 predictions', 'eye', 'trading', 'epic', 100, NULL),
('Trading Legend', 'Place 1000 predictions with 70%+ accuracy', 'star.fill', 'trading', 'legendary', 250, 1000),
('Bull Run', 'Get 10 successful buy predictions in a row', 'arrow.up.circle.fill', 'trading', 'rare', 50, 10),
('Bear Hunter', 'Get 10 successful sell predictions in a row', 'arrow.down.circle.fill', 'trading', 'rare', 50, 10),

-- Community Awards
('First Friend', 'Add your first friend', 'person.badge.plus', 'community', 'common', 10, NULL),
('Social Butterfly', 'Have 10 friends', 'person.3.fill', 'community', 'uncommon', 25, 10),
('Popular Trader', 'Receive 100 likes on your predictions', 'hand.thumbsup.fill', 'community', 'rare', 50, 100),
('Guild Leader', 'Become a guild admin', 'shield.fill', 'community', 'epic', 100, NULL),
('Community Pillar', 'Be a moderator for 30 days', 'building.columns.fill', 'community', 'rare', 50, 30),
('Helpful Hand', 'Make 50 comments on others predictions', 'text.bubble.fill', 'community', 'uncommon', 25, 50),

-- Milestone Awards
('Welcome Aboard', 'Complete your profile setup', 'checkmark.seal.fill', 'milestones', 'common', 10, NULL),
('One Week Warrior', 'Active for 7 consecutive days', 'calendar.badge.clock', 'milestones', 'common', 10, 7),
('Monthly Member', 'Member for 30 days', 'moon.fill', 'milestones', 'uncommon', 25, 30),
('Quarterly Contributor', 'Member for 90 days', 'sun.max.fill', 'milestones', 'rare', 50, 90),
('Yearly Veteran', 'Member for 365 days', 'star.circle.fill', 'milestones', 'epic', 100, 365),
('Multi-Guild Master', 'Be a member of 3 guilds', 'shield.checkered', 'milestones', 'uncommon', 25, 3),

-- Special Awards
('Early Adopter', 'Joined during beta period', 'sparkle', 'special', 'epic', 100, NULL),
('Founding Member', 'Original guild founding member', 'crown.fill', 'special', 'legendary', 250, NULL),
('Bug Hunter', 'Report a significant bug', 'ant.fill', 'special', 'rare', 50, NULL),
('Feature Pioneer', 'First to use a new feature', 'lightbulb.fill', 'special', 'uncommon', 25, NULL);


-- =============================================================================
-- 8. Helper Function: Auto-create profile on user creation
-- =============================================================================
CREATE OR REPLACE FUNCTION traders_guild.create_user_profile_and_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Create user profile
    INSERT INTO traders_guild.user_profiles (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    
    -- Create user statistics
    INSERT INTO traders_guild.user_statistics (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_user_profile_and_stats
    AFTER INSERT ON traders_guild.users
    FOR EACH ROW
    EXECUTE FUNCTION traders_guild.create_user_profile_and_stats();


-- =============================================================================
-- 9. Create profiles/stats for existing users
-- =============================================================================
INSERT INTO traders_guild.user_profiles (user_id)
SELECT id FROM traders_guild.users
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO traders_guild.user_statistics (user_id)
SELECT id FROM traders_guild.users
ON CONFLICT (user_id) DO NOTHING;
'''


# =====================================================================================
# PART 5: CONVERSION HELPERS
# =====================================================================================
# Add to shared/utils/model_schema_conversion.py
# =====================================================================================

CONVERSION_HELPERS = '''
# =============================================================================
# User Profile Conversion
# =============================================================================

def user_profile_to_response(profile: UserProfile) -> UserProfileResponse:
    """Convert UserProfile model to response"""
    return UserProfileResponse(
        user_id=profile.user_id,
        bio=profile.bio,
        location=profile.location,
        timezone=profile.timezone,
        experience_level=profile.experience_level or "beginner",
        trading_style=profile.trading_style,
        preferred_pairs=profile.preferred_pairs or [],
        social_links=[SocialLinkItem(**link) for link in (profile.social_links or [])],
        trading_interests=[TradingInterestItem(**interest) for interest in (profile.trading_interests or [])],
        is_profile_public=profile.is_profile_public,
        show_online_status=profile.show_online_status,
        created_at=profile.created_at,
        updated_at=profile.updated_at
    )


def user_statistics_to_response(stats: UserStatistics) -> UserStatisticsResponse:
    """Convert UserStatistics model to response"""
    return UserStatisticsResponse(
        user_id=stats.user_id,
        total_markers_placed=stats.total_markers_placed,
        successful_markers=stats.successful_markers,
        accuracy_rate=float(stats.accuracy_rate or 0),
        total_likes_received=stats.total_likes_received,
        total_comments_made=stats.total_comments_made,
        current_streak_days=stats.current_streak_days,
        best_streak_days=stats.best_streak_days,
        total_guilds_joined=stats.total_guilds_joined,
        total_awards_earned=stats.total_awards_earned,
        total_award_points=stats.total_award_points,
        top_symbols=stats.top_symbols or [],
        markers_by_type=stats.markers_by_type or {},
        last_calculated_at=stats.last_calculated_at
    )


def user_award_to_response(user_award: UserAward) -> UserAwardResponse:
    """Convert UserAward model (with award_type joined) to response"""
    award_type = user_award.award_type
    return UserAwardResponse(
        id=user_award.id,
        award_id=award_type.id,
        name=award_type.name,
        description=award_type.description,
        icon=award_type.icon,
        category=award_type.category,
        rarity=award_type.rarity,
        points_value=award_type.points_value,
        progress=float(user_award.progress) if user_award.progress is not None else None,
        current_value=user_award.current_value,
        is_new=user_award.is_new,
        earned_at=user_award.earned_at
    )


def build_awards_summary(user_awards: List[UserAward]) -> AwardsSummaryResponse:
    """Build awards summary from list of user awards"""
    total_points = 0
    rarity_breakdown = {}
    
    for ua in user_awards:
        if ua.progress is None or float(ua.progress) >= 1.0:
            total_points += ua.award_type.points_value
            rarity = ua.award_type.rarity
            rarity_breakdown[rarity] = rarity_breakdown.get(rarity, 0) + 1
    
    # Get 3 most recent completed awards
    completed_awards = [ua for ua in user_awards if ua.progress is None or float(ua.progress) >= 1.0]
    recent = sorted(completed_awards, key=lambda x: x.earned_at, reverse=True)[:3]
    
    return AwardsSummaryResponse(
        total_awards=len(completed_awards),
        total_points=total_points,
        rarity_breakdown=rarity_breakdown,
        recent_awards=[user_award_to_response(ua) for ua in recent]
    )
'''


# =====================================================================================
# PART 6: iOS DTO MAPPINGS (for CoreDTOS.swift)
# =====================================================================================

IOS_DTOS = '''
// =====================================================================================
// Add to CoreDTOS.swift - User System DTOs
// =====================================================================================


// =============================================================================
// MARK: - Guild Member DTO (For Member Lists)
// =============================================================================

/// Guild member with embedded user data - matches backend GuildMemberResponse
/// This replaces the old GuildMembershipDTO for member lists
struct RLGuildMemberDTO: Codable, Identifiable, Equatable {
    // Membership data
    let membershipId: UUID              // backend: membership_id
    let role: String
    let reputation: Int
    let contributionScore: Int          // backend: contribution_score
    let dateJoined: Date                // backend: date_joined
    
    // User data (embedded - no lookup!)
    let userId: UUID                    // backend: user_id
    let username: String
    let displayName: String             // backend: display_name
    let avatarUrl: String?              // backend: avatar_url
    let isOnline: Bool                  // backend: is_online
    let globalReputation: Int           // backend: global_reputation
    
    // Relationship to current user
    let isFriend: Bool                  // backend: is_friend
    let friendshipStatus: String?       // backend: friendship_status (none, pending_sent, pending_received, accepted)
    let isBlocked: Bool                 // backend: is_blocked
    let isBlockedBy: Bool               // backend: is_blocked_by
    
    var id: UUID { membershipId }
    
    // Computed
    var memberRole: RLMemberRole {
        RLMemberRole(from: role)
    }
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
    
    var daysInGuild: Int {
        Calendar.current.dateComponents([.day], from: dateJoined, to: Date()).day ?? 0
    }
    
    var memberSince: String {
        let days = daysInGuild
        if days < 7 { return "Member for \\(days) days" }
        else if days < 30 { return "Member for \\(days / 7) weeks" }
        else if days < 365 { return "Member for \\(days / 30) months" }
        else { return "Member for \\(days / 365) years" }
    }
}

/// Guild members list response
struct RLGuildMembersListDTO: Codable {
    let members: [RLGuildMemberDTO]
    let totalCount: Int                 // backend: total_count
    let onlineCount: Int                // backend: online_count
}


// =============================================================================
// MARK: - User Extended Profile DTOs
// =============================================================================

/// Social link item
struct RLSocialLinkItem: Codable, Equatable {
    let platform: String                // twitter, discord, telegram, tradingview, youtube
    let username: String
    let url: String?
    
    var icon: String {
        switch platform.lowercased() {
        case "twitter": return "bird"
        case "discord": return "bubble.left.and.bubble.right"
        case "telegram": return "paperplane.fill"
        case "tradingview": return "chart.xyaxis.line"
        case "youtube": return "play.rectangle.fill"
        default: return "link"
        }
    }
}

/// Trading interest item
struct RLTradingInterestItem: Codable, Equatable {
    let name: String
    let icon: String
    let isPrimary: Bool                 // backend: is_primary
}

/// User extended profile - matches backend UserProfileResponse
struct RLUserProfileDTO: Codable, Equatable {
    let userId: UUID                    // backend: user_id
    let bio: String?
    let location: String?
    let timezone: String?
    let experienceLevel: String         // backend: experience_level
    let tradingStyle: String?           // backend: trading_style
    let preferredPairs: [String]        // backend: preferred_pairs
    let socialLinks: [RLSocialLinkItem] // backend: social_links
    let tradingInterests: [RLTradingInterestItem] // backend: trading_interests
    let isProfilePublic: Bool           // backend: is_profile_public
    let showOnlineStatus: Bool          // backend: show_online_status
    let createdAt: Date                 // backend: created_at
    let updatedAt: Date                 // backend: updated_at
    
    var experienceLevelDisplay: String {
        experienceLevel.capitalized
    }
}


// =============================================================================
// MARK: - User Statistics DTO
// =============================================================================

/// User statistics - matches backend UserStatisticsResponse
struct RLUserStatisticsDTO: Codable, Equatable {
    let userId: UUID                    // backend: user_id
    let totalMarkersPlaced: Int         // backend: total_markers_placed
    let successfulMarkers: Int          // backend: successful_markers
    let accuracyRate: Double            // backend: accuracy_rate (0.0 to 1.0)
    let totalLikesReceived: Int         // backend: total_likes_received
    let totalCommentsMade: Int          // backend: total_comments_made
    let currentStreakDays: Int          // backend: current_streak_days
    let bestStreakDays: Int             // backend: best_streak_days
    let totalGuildsJoined: Int          // backend: total_guilds_joined
    let totalAwardsEarned: Int          // backend: total_awards_earned
    let totalAwardPoints: Int           // backend: total_award_points
    let topSymbols: [String]            // backend: top_symbols
    let markersByType: [String: Int]    // backend: markers_by_type
    let lastCalculatedAt: Date          // backend: last_calculated_at
    
    var accuracyFormatted: String {
        String(format: "%.1f%%", accuracyRate * 100)
    }
}


// =============================================================================
// MARK: - Award DTOs
// =============================================================================

/// Award category
enum RLAwardCategory: String, Codable, CaseIterable {
    case trading = "trading"
    case community = "community"
    case milestones = "milestones"
    case special = "special"
    
    var displayName: String { rawValue.capitalized }
    
    var color: Color {
        switch self {
        case .trading: return .green
        case .community: return .blue
        case .milestones: return .orange
        case .special: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .trading: return "chart.line.uptrend.xyaxis"
        case .community: return "person.3.fill"
        case .milestones: return "flag.fill"
        case .special: return "sparkles"
        }
    }
}

/// Award rarity
enum RLAwardRarity: String, Codable, CaseIterable {
    case common = "common"
    case uncommon = "uncommon"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var displayName: String { rawValue.capitalized }
    
    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
    
    var glowColor: Color {
        switch self {
        case .common: return .clear
        case .uncommon: return .green.opacity(0.3)
        case .rare: return .blue.opacity(0.4)
        case .epic: return .purple.opacity(0.5)
        case .legendary: return .orange.opacity(0.6)
        }
    }
}

/// User's earned award - matches backend UserAwardResponse
struct RLUserAwardDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let awardId: UUID                   // backend: award_id
    let name: String
    let description: String
    let icon: String
    let category: String
    let rarity: String
    let pointsValue: Int                // backend: points_value
    let progress: Double?               // 0.0-1.0, nil if complete
    let currentValue: Int?              // backend: current_value
    let isNew: Bool                     // backend: is_new
    let earnedAt: Date                  // backend: earned_at
    
    var categoryEnum: RLAwardCategory {
        RLAwardCategory(rawValue: category) ?? .special
    }
    
    var rarityEnum: RLAwardRarity {
        RLAwardRarity(rawValue: rarity) ?? .common
    }
    
    var isEarned: Bool {
        progress == nil || (progress ?? 0) >= 1.0
    }
    
    var progressPercentage: Int {
        guard let progress = progress else { return 100 }
        return Int(progress * 100)
    }
}

/// Awards summary - matches backend AwardsSummaryResponse
struct RLAwardsSummaryDTO: Codable, Equatable {
    let totalAwards: Int                // backend: total_awards
    let totalPoints: Int                // backend: total_points
    let rarityBreakdown: [String: Int]  // backend: rarity_breakdown
    let recentAwards: [RLUserAwardDTO]  // backend: recent_awards
    
    var pointsFormatted: String {
        if totalPoints >= 1000 {
            return String(format: "%.1fk", Double(totalPoints) / 1000)
        }
        return "\\(totalPoints)"
    }
}

/// User awards list
struct RLUserAwardsListDTO: Codable {
    let awards: [RLUserAwardDTO]
}


// =============================================================================
// MARK: - Friend DTOs
// =============================================================================

/// Friend in friends list - matches backend FriendResponse
struct RLFriendDTO: Codable, Identifiable, Equatable {
    let friendshipId: UUID              // backend: friendship_id
    let userId: UUID                    // backend: user_id
    let username: String
    let displayName: String             // backend: display_name
    let avatarUrl: String?              // backend: avatar_url
    let isOnline: Bool                  // backend: is_online
    let globalReputation: Int           // backend: global_reputation
    let friendsSince: Date              // backend: friends_since
    
    var id: UUID { friendshipId }
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

/// Incoming friend request - matches backend FriendRequestIncomingResponse
struct RLFriendRequestIncomingDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let fromUserId: UUID                // backend: from_user_id
    let fromUsername: String            // backend: from_username
    let fromDisplayName: String         // backend: from_display_name
    let fromAvatarUrl: String?          // backend: from_avatar_url
    let message: String?
    let createdAt: Date                 // backend: created_at
}

/// Outgoing friend request - matches backend FriendRequestOutgoingResponse
struct RLFriendRequestOutgoingDTO: Codable, Identifiable, Equatable {
    let id: UUID
    let toUserId: UUID                  // backend: to_user_id
    let toUsername: String              // backend: to_username
    let toDisplayName: String           // backend: to_display_name
    let toAvatarUrl: String?            // backend: to_avatar_url
    let message: String?
    let createdAt: Date                 // backend: created_at
}

/// Friends list response
struct RLFriendsListDTO: Codable {
    let friends: [RLFriendDTO]
    let totalCount: Int                 // backend: total_count
    let onlineCount: Int                // backend: online_count
}

/// Friend requests response
struct RLFriendRequestsListDTO: Codable {
    let incoming: [RLFriendRequestIncomingDTO]
    let outgoing: [RLFriendRequestOutgoingDTO]
}


// =============================================================================
// MARK: - Full Profile Response
// =============================================================================

/// Complete user profile - matches backend UserFullProfileResponse
struct RLUserFullProfileDTO: Codable, Equatable {
    let userId: UUID                    // backend: user_id
    let username: String
    let displayName: String             // backend: display_name
    let avatarUrl: String?              // backend: avatar_url
    let globalReputation: Int           // backend: global_reputation
    let isOnline: Bool                  // backend: is_online
    let isVerified: Bool                // backend: is_verified
    let createdAt: Date                 // backend: created_at
    
    let profile: RLUserProfileDTO?
    let statistics: RLUserStatisticsDTO?
    let awardsSummary: RLAwardsSummaryDTO?  // backend: awards_summary
    
    let isFriend: Bool                  // backend: is_friend
    let friendshipStatus: String?       // backend: friendship_status
    let isBlocked: Bool                 // backend: is_blocked
    let isBlockedBy: Bool               // backend: is_blocked_by
    
    let guildMembership: RLGuildMemberDTO?  // backend: guild_membership
}
'''


# =====================================================================================
# SUMMARY: IMPLEMENTATION ORDER
# =====================================================================================

IMPLEMENTATION_ORDER = '''
# =====================================================================================
# IMPLEMENTATION ORDER
# =====================================================================================

1. DATABASE (Alembic Migration)
   - Run the SQL migration to create all new tables
   - This includes the trigger for auto-creating profiles/stats

2. MODELS (shared/models/)
   - Add new models to user.py or create user_extended.py:
     - UserProfile
     - UserStatistics
     - AwardType
     - UserAward
     - Friendship
     - UserBlock
   - Update User model with new relationships

3. SCHEMAS (shared/schemas/user.py)
   - Add all new Pydantic schemas for DTOs

4. CONVERSION HELPERS (shared/utils/model_schema_conversion.py)
   - Add conversion functions for new models

5. ENDPOINTS (api/routes/)
   - Update users.py with profile, awards, friends, blocks endpoints
   - Add awards.py for award type endpoints
   - Update guilds.py with /members endpoint

6. REGISTER API ROUTES
   - Add new routers in main.py

# =====================================================================================
# API ENDPOINT SUMMARY
# =====================================================================================

Users:
  GET  /users/me/profile              - Current user full profile
  GET  /users/me/profile/extended     - Current user extended profile only
  PUT  /users/me/profile              - Update profile
  GET  /users/me/statistics           - Current user stats
  GET  /users/me/awards               - Current user awards list
  GET  /users/me/awards/summary       - Current user awards summary
  POST /users/me/awards/{id}/mark-seen - Mark award seen
  GET  /users/me/friends              - Friends list
  GET  /users/me/friends/requests     - Friend requests (in/out)
  POST /users/me/friends/request      - Send friend request
  POST /users/me/friends/requests/{id}/accept  - Accept request
  POST /users/me/friends/requests/{id}/decline - Decline request
  DELETE /users/me/friends/{user_id}  - Remove friend
  GET  /users/me/blocked              - Blocked users list
  POST /users/me/blocked/{user_id}    - Block user
  DELETE /users/me/blocked/{user_id}  - Unblock user
  GET  /users/{user_id}/profile       - Other user's profile
  GET  /users/{user_id}/awards        - Other user's awards

Guilds (addition):
  GET  /guilds/{guild_id}/members     - Guild members with full user data
  GET  /guilds/{guild_id}/members/{user_id} - Single member details

Awards:
  GET  /awards/types                  - List all award types
  GET  /awards/types/{award_id}       - Single award type
'''

print("User System Backend Specification Generated")
print("=" * 60)
print(IMPLEMENTATION_ORDER)
