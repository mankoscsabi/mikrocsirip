using Microsoft.EntityFrameworkCore;
using MikroCsirip.Data;
using MikroCsirip.DTOs;
using MikroCsirip.Models;

namespace MikroCsirip.Services;

public interface IPostService
{
 Task<PostDto> CreateAsync(int userId, CreatePostRequest request);
 Task<FeedResponse> GetFeedAsync(int userId, int page, int pageSize);
 Task<FeedResponse> GetUserPostsAsync(int profileUserId, int? currentUserId, int page, int pageSize);
 Task<bool> LikeAsync(int userId, int postId);
 Task<bool> DeleteAsync(int userId, int postId);
}

public class PostService : IPostService
{
 private readonly AppDbContext _db;

 public PostService(AppDbContext db) => _db = db;

 public async Task<PostDto> CreateAsync(int userId, CreatePostRequest request)
 {
 var post = new Post { Content = request.Content, UserId = userId };
 _db.Posts.Add(post);
 await _db.SaveChangesAsync();

 var full = await _db.Posts
 .Include(p => p.User)
 .Include(p => p.Likes)
 .FirstAsync(p => p.Id == post.Id);

 return MapPost(full, userId);
 }

 public async Task<FeedResponse> GetFeedAsync(int userId, int page, int pageSize)
 {
 var followingIds = await _db.Follows
 .Where(f => f.FollowerId == userId)
 .Select(f => f.FollowingId)
 .ToListAsync();

 followingIds.Add(userId);

 var query = _db.Posts
 .Include(p => p.User)
 .Include(p => p.Likes)
 .Where(p => followingIds.Contains(p.UserId))
 .OrderByDescending(p => p.CreatedAt);

 var total = await query.CountAsync();
 var posts = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

 return new FeedResponse(posts.Select(p => MapPost(p, userId)).ToList(), total, page, pageSize);
 }

 public async Task<FeedResponse> GetUserPostsAsync(int profileUserId, int? currentUserId, int page, int pageSize)
 {
 var query = _db.Posts
 .Include(p => p.User)
 .Include(p => p.Likes)
 .Where(p => p.UserId == profileUserId)
 .OrderByDescending(p => p.CreatedAt);

 var total = await query.CountAsync();
 var posts = await query.Skip((page - 1) * pageSize).Take(pageSize).ToListAsync();

 return new FeedResponse(posts.Select(p => MapPost(p, currentUserId)).ToList(), total, page, pageSize);
 }

 public async Task<bool> LikeAsync(int userId, int postId)
 {
 var existing = await _db.Likes.FindAsync(userId, postId);
 if (existing != null)
 {
 _db.Likes.Remove(existing);
 await _db.SaveChangesAsync();
 return false;
 }

 _db.Likes.Add(new Like { UserId = userId, PostId = postId });
 await _db.SaveChangesAsync();
 return true;
 }

 public async Task<bool> DeleteAsync(int userId, int postId)
 {
 var post = await _db.Posts.FindAsync(postId);
 if (post == null || post.UserId != userId) return false;

 _db.Posts.Remove(post);
 await _db.SaveChangesAsync();
 return true;
 }

 private static PostDto MapPost(Post p, int? currentUserId) =>
 new(
 p.Id, p.Content, p.CreatedAt,
 new UserDto(p.User.Id, p.User.Username, p.User.Email, p.User.Bio, p.User.AvatarUrl, p.User.CreatedAt, 0, 0, 0),
 p.Likes.Count,
 currentUserId.HasValue && p.Likes.Any(l => l.UserId == currentUserId.Value)
 );
}
