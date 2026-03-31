using System.ComponentModel.DataAnnotations;

namespace MikroCsirip.Models;

public class User
{
 public int Id { get; set; }

 [Required, MaxLength(50)]
 public string Username { get; set; } = string.Empty;

 [Required, MaxLength(100)]
 public string Email { get; set; } = string.Empty;

 [Required]
 public string PasswordHash { get; set; } = string.Empty;

 [MaxLength(160)]
 public string? Bio { get; set; }

 public string? AvatarUrl { get; set; }

 public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

 public ICollection<Post> Posts { get; set; } = new List<Post>();
 public ICollection<Follow> Followers { get; set; } = new List<Follow>();
 public ICollection<Follow> Following { get; set; } = new List<Follow>();
 public ICollection<Like> Likes { get; set; } = new List<Like>();
}

public class Post
{
 public int Id { get; set; }

 [Required, MaxLength(280)]
 public string Content { get; set; } = string.Empty;

 public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

 public int UserId { get; set; }
 public User User { get; set; } = null!;

 public ICollection<Like> Likes { get; set; } = new List<Like>();
}

public class Follow
{
 public int FollowerId { get; set; }
 public User Follower { get; set; } = null!;

 public int FollowingId { get; set; }
 public User Following { get; set; } = null!;

 public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class Like
{
 public int UserId { get; set; }
 public User User { get; set; } = null!;

 public int PostId { get; set; }
 public Post Post { get; set; } = null!;

 public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
