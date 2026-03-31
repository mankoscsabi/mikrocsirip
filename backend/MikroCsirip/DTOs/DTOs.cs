using System.ComponentModel.DataAnnotations;

namespace MikroCsirip.DTOs;

// Auth
public record RegisterRequest(
 [Required, MinLength(3), MaxLength(50)] string Username,
 [Required, EmailAddress] string Email,
 [Required, MinLength(6)] string Password
);

public record LoginRequest(
 [Required] string Email,
 [Required] string Password
);

public record AuthResponse(string Token, UserDto User);

// User
public record UserDto(
 int Id,
 string Username,
 string Email,
 string? Bio,
 string? AvatarUrl,
 DateTime CreatedAt,
 int PostCount,
 int FollowerCount,
 int FollowingCount
);

public record UpdateProfileRequest(
 [MaxLength(160)] string? Bio,
 string? AvatarUrl
);

// Post
public record CreatePostRequest(
 [Required, MaxLength(280)] string Content
);

public record PostDto(
 int Id,
 string Content,
 DateTime CreatedAt,
 UserDto Author,
 int LikeCount,
 bool IsLikedByMe
);

// Feed
public record FeedResponse(List<PostDto> Posts, int TotalCount, int Page, int PageSize);
